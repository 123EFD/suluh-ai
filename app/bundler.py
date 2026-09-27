import sqlite3
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Annotated, List, Dict, Optional
import os
from dotenv import load_dotenv
import psycopg
import time
import re
from app.video_link import search_youtube_live
from app.curriculum import (
    COURSE_MAPPING,
    PREREQUISITE_GRAPH,
    TOPIC_TAXONOMY,
    resolve_topic_metadata,
)

load_dotenv()

router = APIRouter(prefix="/bundler", tags=["Bundler"])

DB_PATH = "resources.db"

def get_db_connection():
    db_url = os.getenv("DATABASE_URL")
    if db_url is None:
        raise ValueError("DATABASE_URL environment variable is not set")
    return psycopg.connect(db_url)

class BundleRequest(BaseModel):
    minutes_available: Annotated[int, Field(gt=0, lt=241)]
    topic: Optional[str] = None

class ResourceItem(BaseModel):
    resource_id: str
    topic: str
    duration_min: int
    type: str
    content: str

def _open() -> sqlite3.Connection:
    return sqlite3.connect(DB_PATH)

def _is_academically_substantive(content: str, rtype: str) -> bool:
    """
    Enforces a strict Bloom's Taxonomy cognitive quality filter:
    Filters out trivial rote-memorization cards (e.g. acronym lookups, 1-word answers,
    trivia questions like 'What is square root of 256').
    """
    if rtype not in ("flashcard", "flashcards"):
        return True

    text = (content or "").strip()
    low = text.lower()

    # Reject known trivial trivia patterns
    trivial_triggers = [
        "square root of",
        "size of char",
        "example of a throughput device",
        "stands for",
        "in networking terminology utp means",
        "a t-switch is used to",
        "what frequency range is used",
    ]
    if any(t in low for t in trivial_triggers):
        return False

    # Enforce minimum answer length & substance (at least 35 characters of reasoning/explanation)
    if "**answer:**" in low:
        ans = low.split("**answer:**", 1)[1].strip()
        if len(ans) < 35:
            return False
    elif "**back:**" in low:
        ans = low.split("**back:**", 1)[1].strip()
        if len(ans) < 35:
            return False

def _is_topically_relevant(content: str, keywords: List[str], negative_keywords: Optional[List[str]] = None) -> bool:
    """
    Guarantees strict domain boundaries:
    1. Immediately rejects cards with prohibited cross-domain keywords (e.g. SOLID in Networks, SQL in OS).
    2. Requires at least one positive domain keyword match to eliminate mislabeled database entries.
    """
    low = (content or "").lower()
    if negative_keywords:
        for neg in negative_keywords:
            if neg.lower() in low:
                return False
    if not keywords:
        return True
    return any(kw.lower() in low for kw in keywords)

@router.post("/create", response_model=List[ResourceItem])
def create_bundle(req: BundleRequest):
    con = _open()
    sqlite_cur = con.cursor()

    raw_topic = req.topic.strip() if req.topic else None
    meta = resolve_topic_metadata(raw_topic)
    course_code = meta["course_code"]
    canonical_topic = meta["canonical_name"]
    allowed_topics = meta["allowed_sqlite_topics"]
    keywords = meta.get("keywords", [])
    negative_keywords = meta.get("negative_keywords", [])

    candidates = []

    # 1. Fetch verified institutional resources from Neon PostgreSQL
    if course_code or canonical_topic:
        try:
            with get_db_connection() as conn:
                with conn.cursor() as neon_cur:
                    neon_cur.execute(
                        """
                        SELECT title, subject_tag, url, resource_type
                        FROM learning_resources
                        WHERE course_code = %s OR subject_tag ILIKE %s OR title ILIKE %s
                        LIMIT 5;
                        """,
                        (course_code, f"%{canonical_topic}%", f"%{canonical_topic}%")
                    )
                    neon_results = neon_cur.fetchall()

            for rows in neon_results:
                raw_type = (rows[3] or "reading").strip().lower()
                if "video" in raw_type or "youtube" in raw_type:
                    norm_type = "video"
                elif any(t in raw_type for t in ("pdf", "book", "article")):
                    norm_type = "pdf"
                else:
                    norm_type = "reading"
                candidates.append((f"neon_{len(candidates)+1}", rows[0], 10, norm_type, rows[2]))
        except Exception as e:
            # Non-fatal log so offline development continues smoothly
            print(f"Warning: Neon DB lookup bypassed in bundler: {e}")

    # 2. Query SQLite micro_resources strictly within allowed subject boundaries (Zero Contamination)
    placeholders = ",".join("?" for _ in allowed_topics)
    sql = f"""
        SELECT CAST(id AS TEXT) AS resource_id, topic, CAST(duration_min AS INT) AS duration, type, content 
        FROM micro_resources 
        WHERE topic IN ({placeholders}) 
        ORDER BY RANDOM();
    """
    sqlite_cur.execute(sql, allowed_topics)
    sqlite_candidates = sqlite_cur.fetchall()

    # Apply both Bloom's depth filter and Semantic Relevance keyword guard
    for c in sqlite_candidates:
        if _is_academically_substantive(c[4], c[3]) and _is_topically_relevant(c[4], keywords, negative_keywords):
            candidates.append(c)

    # 3. Prerequisite DAG Fallback (Pedagogical Sourcing instead of General CS)
    # If candidate pool is too small to fulfill time budget, query foundational prerequisite courses
    if len(candidates) < 6 and course_code in PREREQUISITE_GRAPH:
        prereq_codes = PREREQUISITE_GRAPH[course_code]
        for p_code in prereq_codes:
            prereq_course_name = COURSE_MAPPING.get(p_code, p_code)
            prereq_meta = resolve_topic_metadata(prereq_course_name)
            p_allowed = prereq_meta["allowed_sqlite_topics"]
            p_keywords = prereq_meta.get("keywords", [])
            p_negatives = prereq_meta.get("negative_keywords", [])
            p_placeholders = ",".join("?" for _ in p_allowed)

            sql_prereq = f"""
                SELECT CAST(id AS TEXT) AS resource_id, topic, CAST(duration_min AS INT) AS duration, type, content
                FROM micro_resources
                WHERE topic IN ({p_placeholders})
                ORDER BY RANDOM()
                LIMIT 6;
            """
            sqlite_cur.execute(sql_prereq, p_allowed)
            prereq_items = sqlite_cur.fetchall()
            for p_item in prereq_items:
                if _is_academically_substantive(p_item[4], p_item[3]) and _is_topically_relevant(p_item[4], p_keywords, p_negatives):
                    # Tag clearly as a foundational prerequisite item
                    candidates.append((
                        p_item[0],
                        f"{canonical_topic} (Prerequisite: {prereq_course_name})",
                        p_item[2],
                        p_item[3],
                        p_item[4]
                    ))

    # 4. Partition candidates into categories to ensure curriculum diversity
    videos = [c for c in candidates if c[3] in ('video', 'video_chunk', 'youtube')]

    # Live YouTube Search Integration: dynamically fetch collegiate lecture if none exist
    if not videos and canonical_topic:
        try:
            live_vid = search_youtube_live(canonical_topic)
            if live_vid and "url" in live_vid:
                live_item = (
                    f"live_yt_{int(time.time())}",
                    canonical_topic,
                    15,
                    "video",
                    live_vid["url"]
                )
                videos.append(live_item)
                candidates.append(live_item)
        except Exception as yt_err:
            print(f"Error fetching live YouTube video for study bundle: {yt_err}")

    readings = [c for c in candidates if c[3] in ('pdf', 'book', 'article', 'reading', 'doc')]
    pyqs = [c for c in candidates if c[3] in ('pyq_solution', 'problem', 'quiz')]
    flashcards = [c for c in candidates if c[3] in ('flashcard', 'flashcards')]
    others = [c for c in candidates if c not in videos and c not in readings and c not in pyqs and c not in flashcards]

    def _normalize_content_key(text: str) -> str:
        clean = (text or "").lower().replace("<br>", " ").replace("\n", " ")
        if "**answer:**" in clean:
            clean = clean.split("**answer:**")[0]
        elif "**back:**" in clean:
            clean = clean.split("**back:**")[0]
        return "".join(c for c in clean if c.isalnum())

    bundle = []
    total = 0
    seen_ids = set()
    seen_keys = set()

    def _can_add(rid: str, content: str) -> bool:
        if rid in seen_ids:
            return False
        key = _normalize_content_key(content)
        if key and key in seen_keys:
            return False
        return True

    def _add_item(rid: str, topic_name: str, dur: int, rtype: str, content: str):
        nonlocal total
        bundle.append(ResourceItem(resource_id=rid, topic=topic_name, duration_min=dur, type=rtype, content=content))
        total += dur
        seen_ids.add(rid)
        key = _normalize_content_key(content)
        if key:
            seen_keys.add(key)

    # 1. Multi-modal diversity phase: try to include at least 1 item from each category
    pools = [videos, readings, pyqs, flashcards, others]
    for pool in pools:
        for c in pool:
            rid, topic_name, dur, rtype, content = c
            if total + dur <= req.minutes_available and _can_add(rid, content):
                _add_item(rid, topic_name, dur, rtype, content)
                break

    # 2. Greedy fill phase: fill remaining minutes strictly with verified candidates from this topic
    remaining_candidates = [c for c in candidates if _can_add(c[0], c[4])]
    remaining_candidates.sort(key=lambda x: x[2], reverse=True)
    for rid, topic_name, dur, rtype, content in remaining_candidates:
        if total + dur <= req.minutes_available and _can_add(rid, content):
            _add_item(rid, topic_name, dur, rtype, content)
        if total >= req.minutes_available:
            break

    con.close()

    if not bundle:
        raise HTTPException(status_code=404, detail=f"No high-yield resources found for '{canonical_topic}'.")

    return bundle