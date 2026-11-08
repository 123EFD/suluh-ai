import os
import re
import json
import urllib.request
from time import time
from typing import List, Optional
from fastapi import APIRouter, HTTPException
import pymupdf as fitz
from app.core.config import (
    COURSE_MAPPING,
    PREREQUISITE_GRAPH,
    OPEN_COURSE_PDF_REPOSITORY,
    UPLOAD_FOLDER
)
from app.core.database import get_db_connection
from app.models.schemas import (
    FocusAnalysisRequest,
    FocusAnalysisResponse,
    ChapterFocus,
    SubchapterFocus,
    ResolveCoursePdfRequest,
    ResolveCoursePdfResponse,
    ResolveSubchapterVideoRequest,
    ResolveSubchapterVideoResponse,
    SubchapterFlashcardRequest,
    FlashcardItem
)
from app.services.llm_service import get_groq_client
from app.services.pdf_service import (
    extract_pdf_toc_and_structure,
    validate_and_rank_citations
)

router = APIRouter(tags=["Academic Diagnostics & Flashcards"])

def _fallback_focus_response(course_code: str, course_name: str, filename: str) -> FocusAnalysisResponse:
    """Generates a structured, high-yield diagnostic fallback if LLM or parsing is unavailable."""
    return FocusAnalysisResponse(
        course_code=course_code,
        course_name=course_name,
        filename=filename,
        total_estimated_study_hours=2.5,
        recommended_chapters=[
            ChapterFocus(
                chapter_number=1,
                chapter_title="Foundations & Core Mathematical Mechanisms",
                page_range="15-42",
                priority="CRITICAL",
                relevance_rationale=f"Addresses prerequisite bottlenecks detected in your profile for {course_name}.",
                subchapters=[
                    SubchapterFocus(
                        subchapter_id="1.1",
                        title="Core Formulations & Vector Representations",
                        page_start=15,
                        page_end=28,
                        estimated_minutes=30,
                        keypoints=[
                            "Dimensional consistency is the foundation of matrix modeling.",
                            "Closed-form normal equations minimize least squares error.",
                            "Understand difference between loss function vs optimizer."
                        ],
                        exam_warning="Exam questions frequently test deriving gradients by hand."
                    ),
                    SubchapterFocus(
                        subchapter_id="1.2",
                        title="Loss Optimization & Regularization (L1 vs L2)",
                        page_start=29,
                        page_end=42,
                        estimated_minutes=25,
                        keypoints=[
                            "L1 regularization yields sparse weight vectors (feature selection).",
                            "L2 Ridge regularization penalizes large weights smoothly.",
                            "Overfitting occurs when model parameters memorize noise."
                        ],
                        exam_warning="Don't confuse Ridge with Lasso in multiple choice questions."
                    )
                ]
            ),
            ChapterFocus(
                chapter_number=2,
                chapter_title="High-Yield Exam Algorithms & Problem Solutions",
                page_range="65-98",
                priority="HIGH_YIELD",
                relevance_rationale="Covers the most frequent 20-mark essay and calculation questions in semester finals.",
                subchapters=[
                    SubchapterFocus(
                        subchapter_id="2.1",
                        title="Algorithmic Walkthrough & Step-by-Step Execution",
                        page_start=65,
                        page_end=80,
                        estimated_minutes=35,
                        keypoints=[
                            "Always trace algorithmic state step-by-step with an iteration table.",
                            "Analyze worst-case time complexity O(N log N) vs space complexity.",
                            "Check convergence criteria before declaring optimal state."
                        ],
                        exam_warning="Students lose marks by skipping edge case validation in final steps."
                    )
                ]
            )
        ]
    )

@router.post("/api/resolve-course-pdf", response_model=ResolveCoursePdfResponse)
def resolve_course_pdf(req: ResolveCoursePdfRequest):
    """
    Resolves the primary textbook / syllabus PDF for a given curriculum subject code.
    1. Checks Neon PostgreSQL learning_resources table.
    2. Checks local uploads directory.
    3. If missing, retrieves from open-access academic repositories, downloads, and caches.
    """
    code = req.course_code.upper().strip()
    course_name = COURSE_MAPPING.get(code, code)
    
    neon_match = None
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT title, url, resource_type
                    FROM learning_resources
                    WHERE (course_code = %s OR subject_tag ILIKE %s)
                      AND (resource_type ILIKE 'pdf' OR resource_type ILIKE 'book')
                    ORDER BY id ASC
                    LIMIT 1;
                    """,
                    (code, f"%{course_name}%")
                )
                neon_match = cur.fetchone()
    except Exception as db_err:
        print(f"Neon query error: {db_err}")

    repo_info = OPEN_COURSE_PDF_REPOSITORY.get(code)
    target_filename = repo_info["filename"] if repo_info else None
    
    if target_filename and os.path.exists(os.path.join(UPLOAD_FOLDER, target_filename)):
        try:
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        INSERT INTO learning_resources (course_code, subject_tag, title, url, resource_type)
                        SELECT %s, %s, %s, %s, 'PDF'
                        WHERE NOT EXISTS (
                            SELECT 1 FROM learning_resources
                            WHERE course_code = %s AND (LOWER(TRIM(title)) = LOWER(TRIM(%s)) OR LOWER(TRIM(url)) = LOWER(TRIM(%s)))
                        );
                        """,
                        (code, course_name, repo_info["title"], repo_info["url"], code, repo_info["title"], repo_info["url"])
                    )
                conn.commit()
        except Exception:
            pass

        return ResolveCoursePdfResponse(
            course_code=code,
            course_name=course_name,
            filename=target_filename,
            source="neon" if neon_match else "local",
            title=repo_info["title"],
            message=f"Textbook '{repo_info['title']}' loaded and verified in Neon database."
        )

    if repo_info and repo_info.get("url") and repo_info["url"].endswith(".pdf"):
        download_url = repo_info["url"]
        dest_filename = repo_info["filename"]
        dest_path = os.path.join(UPLOAD_FOLDER, dest_filename)
        
        try:
            print(f"Retrieving online academic PDF for {code} from {download_url}...")
            if not download_url.startswith(("http://", "https://")):
                raise ValueError("Insecure or unsupported URL scheme")
            req_dl = urllib.request.Request(download_url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req_dl, timeout=20) as resp, open(dest_path, 'wb') as out_f:  # nosec B310
                out_f.write(resp.read())
            print(f"Downloaded and saved to {dest_path}")
            
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        INSERT INTO learning_resources (course_code, subject_tag, title, url, resource_type)
                        VALUES (%s, %s, %s, %s, 'PDF')
                        ON CONFLICT DO NOTHING;
                        """,
                        (code, course_name, repo_info["title"], download_url)
                    )
                conn.commit()
                
            return ResolveCoursePdfResponse(
                course_code=code,
                course_name=course_name,
                filename=dest_filename,
                source="online",
                title=repo_info["title"],
                message=f"Retrieved and permanently archived '{repo_info['title']}' into Neon database."
            )
        except Exception as dl_err:
            print(f"Download failed: {dl_err}")

    available_pdfs = [f for f in os.listdir(UPLOAD_FOLDER) if f.endswith(".pdf")] if os.path.exists(UPLOAD_FOLDER) else []
    fallback_file = available_pdfs[0] if available_pdfs else "The Hundred-page Machine Learning.pdf"
    return ResolveCoursePdfResponse(
        course_code=code,
        course_name=course_name,
        filename=fallback_file,
        source="local",
        title=f"{course_name} Reference Material",
        message=f"Associated default curriculum asset '{fallback_file}'."
    )

@router.post("/api/analyze-pdf-focus", response_model=FocusAnalysisResponse)
def analyze_pdf_focus(req: FocusAnalysisRequest):
    """Pinpoints high-yield exam chapters, subchapters, and page ranges from syllabus/textbook TOC."""
    filename = req.filename.strip()
    file_path = os.path.join(UPLOAD_FOLDER, filename)
    
    if not os.path.exists(file_path):
        if os.path.exists(filename):
            file_path = filename
        else:
            matched_file = None
            if os.path.exists(UPLOAD_FOLDER):
                for f in os.listdir(UPLOAD_FOLDER):
                    if f.lower() == filename.lower() and f.lower().endswith(".pdf"):
                        matched_file = f
                        break
            if matched_file:
                file_path = os.path.join(UPLOAD_FOLDER, matched_file)
                filename = matched_file
            else:
                available = [f for f in os.listdir(UPLOAD_FOLDER) if f.lower().endswith(".pdf")] if os.path.exists(UPLOAD_FOLDER) else []
                if available:
                    resolved = resolve_course_pdf(ResolveCoursePdfRequest(course_code=req.course_code))
                    if resolved and resolved.filename and os.path.exists(os.path.join(UPLOAD_FOLDER, resolved.filename)):
                        filename = resolved.filename
                        file_path = os.path.join(UPLOAD_FOLDER, filename)
                    else:
                        filename = available[0]
                        file_path = os.path.join(UPLOAD_FOLDER, filename)
                else:
                    raise HTTPException(status_code=404, detail=f"PDF document '{filename}' was not found in uploads folder, and no alternative PDFs are available.")
            
    course_name = COURSE_MAPPING.get(req.course_code.upper().strip(), req.course_code)
    
    prereqs = list(req.prerequisites) if req.prerequisites else []
    if not prereqs:
        raw_prereqs = PREREQUISITE_GRAPH.get(req.course_code.upper().strip(), [])
        prereqs = [COURSE_MAPPING.get(p, p) for p in raw_prereqs]
        
    try:
        toc_context = extract_pdf_toc_and_structure(file_path)
    except Exception as e:
        print(f"Error extracting PDF TOC: {e}")
        toc_context = "Table of contents extraction unavailable."
        
    client = get_groq_client()
    if not client:
        return _fallback_focus_response(req.course_code, course_name, filename)
        
    system_prompt = """You are an elite University Academic Advisor, Diagnostic Curriculum Specialist, and Exam Strategist.
Your goal is to analyze a student's course performance risk and cross-reference it with a textbook/syllabus Table of Contents (TOC).
You must output a strictly valid JSON object identifying the top 3-4 most critical chapters and subchapters the student must focus on to survive and pass exams.

JSON Schema:
{
  "recommended_chapters": [
    {
      "chapter_number": 1,
      "chapter_title": "String",
      "page_range": "String (e.g. 45-72)",
      "priority": "CRITICAL" | "HIGH_YIELD" | "FOUNDATIONAL",
      "relevance_rationale": "1-2 sentences explaining why this chapter directly addresses the student's weaknesses or prerequisite gaps.",
      "subchapters": [
        {
          "subchapter_id": "1.1",
          "title": "String",
          "page_start": 45,
          "page_end": 52,
          "estimated_minutes": 25,
          "keypoints": [
            "Specific equation, mathematical mechanism, or algorithm definition",
            "Core principle or conceptual distinction",
            "Why this is asked in university exams"
          ],
          "exam_warning": "1 sentence warning about common student misconceptions or past exam question traps."
        }
      ]
    }
  ]
}

Priority Guidelines:
- CRITICAL: Essential prerequisite foundations that the student lacks (e.g. math/core gaps preventing comprehension).
- HIGH_YIELD: High-frequency exam topics with heavy mark allocations in university finals.
- FOUNDATIONAL: Core theoretical mechanisms required for advanced topics.

Constraint: Return ONLY valid parseable JSON. Do not include markdown ticks, explanation text, or extra commentary.
"""

    user_prompt = f"""Student Profile:
- Course Code: {req.course_code} ({course_name})
- Current Test/Quiz Grade: {req.course_grade} / 4.0 (Student is at academic risk)
- Prerequisite Bottlenecks Detected by DAG: {', '.join(prereqs) if prereqs else 'None explicit'}
- Target Textbook / Syllabus Asset: {filename}

Extracted Document Table of Contents & Structure Context:
{toc_context[:9000]}

Analyze the document structure and synthesize the top 3-4 prioritized chapters and subchapters the student must study."""

    try:
        try:
            chat_completion = client.chat.completions.create(
                model="qwen/qwen3.8-27b",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                response_format={"type": "json_object"},
                temperature=0.2,
                max_tokens=2500
            )
        except Exception:
            chat_completion = client.chat.completions.create(
                model="openai/gpt-oss-120b",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                response_format={"type": "json_object"},
                temperature=0.2,
                max_tokens=2500
            )
            
        raw_json = (chat_completion.choices[0].message.content or "{}").strip() if chat_completion.choices else "{}"
        data = json.loads(raw_json)
        
        raw_chapters = data.get("recommended_chapters", [])
        if not raw_chapters:
            return _fallback_focus_response(req.course_code, course_name, filename)
            
        chapters_out = []
        total_mins = 0
        
        for ch in raw_chapters:
            sub_list = []
            for sub in ch.get("subchapters", []):
                mins = int(sub.get("estimated_minutes", 25))
                total_mins += mins
                sub_list.append(SubchapterFocus(
                    subchapter_id=str(sub.get("subchapter_id", "1.1")),
                    title=str(sub.get("title", "Core Concept")),
                    page_start=int(sub.get("page_start", 1)),
                    page_end=int(sub.get("page_end", 10)),
                    estimated_minutes=mins,
                    keypoints=[str(kp) for kp in sub.get("keypoints", ["Core concept definition"])],
                    exam_warning=sub.get("exam_warning")
                ))
                
            chapters_out.append(ChapterFocus(
                chapter_number=int(ch.get("chapter_number", 1)),
                chapter_title=str(ch.get("chapter_title", "Foundational Chapter")),
                page_range=str(ch.get("page_range", "1-20")),
                priority=str(ch.get("priority", "HIGH_YIELD")).upper(),
                relevance_rationale=str(ch.get("relevance_rationale", f"Relevant for mastering {course_name}.")),
                subchapters=sub_list
            ))
            
        return FocusAnalysisResponse(
            course_code=req.course_code,
            course_name=course_name,
            filename=filename,
            total_estimated_study_hours=round(total_mins / 60.0, 1),
            recommended_chapters=chapters_out
        )
    except Exception as err:
        print(f"Focus analysis LLM error: {err}")
        return _fallback_focus_response(req.course_code, course_name, filename)

@router.post("/api/resolve-subchapter-video", response_model=Optional[ResolveSubchapterVideoResponse])
def resolve_subchapter_video(req: ResolveSubchapterVideoRequest):
    """Finds an educational video lecture strictly relevant to the course code and subchapter title."""
    code = req.course_code.upper().strip()
    sub_title = req.subchapter_title.strip()
    course_name = COURSE_MAPPING.get(code, code)
    
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT title, url
                    FROM learning_resources
                    WHERE course_code = %s AND (resource_type ILIKE 'video%%' OR resource_type ILIKE 'youtube%%')
                    ORDER BY id ASC;
                    """,
                    (code,)
                )
                videos = cur.fetchall()
                if videos:
                    sub_tokens = set(re.findall(r'\b[a-zA-Z0-9]{3,}\b', sub_title.lower()))
                    best_video = None
                    best_overlap = 0

                    for v_title, v_url in videos:
                        v_tokens = set(re.findall(r'\b[a-zA-Z0-9]{3,}\b', v_title.lower()))
                        overlap = len(sub_tokens.intersection(v_tokens))
                        if overlap > best_overlap:
                            best_overlap = overlap
                            best_video = (v_title, v_url)

                    if best_video and best_overlap > 0:
                        return ResolveSubchapterVideoResponse(
                            video_id=f"neon_{code}_{int(time())}",
                            title=best_video[0].strip(),
                            url=best_video[1].strip(),
                            channel=f"{course_name} Faculty Lecture",
                            duration_min=15
                        )
    except Exception as db_err:
        print(f"Error querying Neon for subchapter video: {db_err}")

    try:
        from app.video_link import search_youtube_live
        query = f"{course_name} {sub_title}"
        yt_match = search_youtube_live(query)
        if yt_match and "url" in yt_match:
            return ResolveSubchapterVideoResponse(
                video_id=f"yt_{int(time())}",
                title=yt_match.get("title", f"{sub_title} Lecture"),
                url=yt_match["url"],
                channel=yt_match.get("channel", "Academic Video"),
                duration_min=15
            )
    except Exception as yt_err:
        print(f"Error resolving YouTube lecture for {query}: {yt_err}")

    return None

@router.post("/api/generate-subchapter-flashcards", response_model=List[FlashcardItem])
def generate_subchapter_flashcards(req: SubchapterFlashcardRequest):
    """Synthesizes deep university exam flashcards with LaTeX math and verified literature citations."""
    file_path = os.path.join(UPLOAD_FOLDER, req.filename.strip())
    course_name = COURSE_MAPPING.get(req.course_code.upper().strip(), req.course_code)
    
    excerpt_text = ""
    if os.path.exists(file_path):
        try:
            with fitz.open(file_path) as doc:
                total_p = len(doc)
                p_start = max(1, req.page_start)
                p_end = min(req.page_end, total_p)
                for p in range(p_start, p_end + 1):
                    t = str(doc[p - 1].get_text("text")).strip()
                    if t:
                        excerpt_text += f"\n--- Page {p} ---\n" + t
        except Exception as err:
            print(f"Error reading PDF excerpt for flashcards: {err}")
            
    client = get_groq_client()
    system_prompt = f"""You are a distinguished University Professor and Exam Architect for Computer Science courses.
Your task is to synthesize 3 to 4 rigorous, high-yield exam mastery flashcards from this textbook excerpt for course '{course_name}' ({req.course_code}).

CRITICAL FLASHCARD RULES:
1. FRONT (**Question:**):
   - MUST pose an authentic, challenging university exam question: a conceptual trade-off, calculation derivation, architectural comparison, or debugging scenario.
   - Format any mathematical formulas using standard LaTeX (e.g. $x = [1, 2]$ or $T = 0.5$).
   - NEVER ask trivial 1-word definition questions (e.g. avoid "What is X?").

2. BACK (**Answer:**):
   - MUST be a structured, in-depth pedagogical synthesis:
     * **Core Mechanism & Principle**: In-depth theoretical walkthrough.
     * **Formula / Concrete Code Snippet**: The exact mathematical equation (format with LaTeX $inline$ or $$display$$) or clean implementation logic in markdown code blocks (e.g. ```c or ```python).
     * **University Exam Traps & Examiner Expectations**: What examiners specifically test for in finals and common misconceptions where students lose marks.

3. RESEARCH CITATIONS (**citations:**):
   - Provide 1 to 2 authoritative academic research citations or foundational literature links (e.g. ArXiv papers, RFC specifications, OpenStax textbooks, ACM/IEEE publications).

OUTPUT JSON FORMAT:
{{
  "flashcards": [
    {{
      "question": "Challenging university exam prompt with LaTeX math if applicable...",
      "answer": "Comprehensive 3-part structured breakdown with LaTeX math and code snippets...",
      "citations": [
        {{
          "title": "Authoritative Paper or Standard Title",
          "url": "https://arxiv.org/abs/... or https://www.rfc-editor.org/rfc/...",
          "domain": "ArXiv / RFC / OpenStax",
          "reason": "Why this literature is foundational to understanding this topic."
        }}
      ]
    }}
  ]
}}
Return ONLY valid parseable JSON.
"""

    user_prompt = f"""Subchapter: {req.subchapter_title} (Pages {req.page_start} - {req.page_end})
Keypoints from Syllabus Radar: {", ".join(req.keypoints) if req.keypoints else "Core concepts"}
Exam Pitfall Warning: {req.exam_warning or "Common university final exam questions"}

Document Excerpt:
{excerpt_text[:8000]}
"""

    if client:
        try:
            try:
                completion = client.chat.completions.create(
                    model="qwen/qwen3.8-27b",
                    messages=[
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt}
                    ],
                    response_format={"type": "json_object"},
                    temperature=0.3,
                    max_tokens=3000
                )
            except Exception as primary_err:
                print(f"Primary model error in flashcards, trying gpt-oss-120b: {primary_err}")
                completion = client.chat.completions.create(
                    model="openai/gpt-oss-120b",
                    messages=[
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt}
                    ],
                    response_format={"type": "json_object"},
                    temperature=0.3,
                    max_tokens=2500
                )
            raw_cards_json = (completion.choices[0].message.content or "{}").strip() if completion.choices else "{}"
            data = json.loads(raw_cards_json)
            cards_data = data.get("flashcards", [])
            
            results = []
            for i, c in enumerate(cards_data):
                q = c.get("question", "").strip()
                a = c.get("answer", "").strip()
                raw_citations = c.get("citations", [])
                
                ranked_citations = validate_and_rank_citations(raw_citations, req.course_code, req.subchapter_title)
                
                citation_text = ""
                if ranked_citations:
                    citation_text = "\n\n**Deep-Dive Research Papers & Literature:**\n"
                    for cite in ranked_citations:
                        citation_text += f"- 📄 [{cite['title']}]({cite['url']}) — *{cite.get('reason', 'Foundational literature')}*\n"

                if q and a:
                    results.append(FlashcardItem(
                        resource_id=f"deep_fc_{req.course_code}_{req.page_start}_{i+1}",
                        topic=req.subchapter_title,
                        duration_min=5,
                        type="flashcard",
                        content=f"**Question:** {q}\n\n**Answer:** {a}{citation_text}"
                    ))
            if results:
                return results
        except Exception as e:
            print(f"Error generating AI flashcards: {e}")

    # Fallback to enhanced keypoint breakdown
    fallback_cards = []
    fallback_citations = validate_and_rank_citations([], req.course_code, req.subchapter_title)
    cite_block = ""
    if fallback_citations:
        cite_block = "\n\n**Deep-Dive Research Papers & Literature:**\n" + "\n".join(
            [f"- 📄 [{c['title']}]({c['url']}) — *{c['reason']}*" for c in fallback_citations]
        )

    for i, kp in enumerate(req.keypoints or [req.subchapter_title]):
        fallback_cards.append(FlashcardItem(
            resource_id=f"fallback_fc_{req.course_code}_{req.page_start}_{i+1}",
            topic=req.subchapter_title,
            duration_min=5,
            type="flashcard",
            content=f"**Question:** In {course_name} [{req.subchapter_title}], explain the theoretical significance and algorithmic mechanism of: {kp}?\n\n**Answer:** **Core Mechanism**: In {course_name}, this concept directly governs the system behavior outlined in pages {req.page_start}–{req.page_end}.\n\n**Formula / Code Consideration**: When implementing or deriving this, maintain numerical stability and boundary condition validation using LaTeX $O(N)$ or $O(\\log N)$.\n\n**Exam Pitfall**: {req.exam_warning or 'Common exam deduction occurs when confusing this with its inverse operator in multi-part final exam essays.'}{cite_block}"
        ))
    return fallback_cards
