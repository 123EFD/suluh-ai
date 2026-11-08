import os
import re
from typing import Optional, List, Dict
from urllib.parse import urlparse
import pymupdf as fitz
from app.core.config import TRUSTED_ACADEMIC_DOMAINS, CURATED_LITERATURE_REGISTRY
from app.core.database import get_db_connection
from app.services.embedding_service import get_embedder

def gather_chat_source(filename: str) -> str:
    """Queries the operational database to pull conversational history context."""
    chat_text = ""
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT role, message_text FROM chat_messages WHERE filename = %s ORDER BY id ASC",
                (filename,)
            )
            rows = cur.fetchall()
            for row in rows:
                chat_text += f"{row[0].upper()}: {row[1]}\n\n"
    return chat_text

def gather_pdf_range_source(filename: str, start: Optional[int], end: Optional[int]) -> str:
    """Uses PyMuPDF (fitz) to dynamically extract text from specific page indices."""
    extracted_text = ""
    file_path = os.path.join("uploads", filename)
    
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"Source asset not found: {filename}")
        
    doc = fitz.open(file_path)
    total_pages = len(doc)
    
    p_start = max(1, start if start else 1)
    p_end = min(total_pages, end if end else total_pages)
    
    for page_num in range(p_start - 1, p_end):
        page = doc.load_page(page_num)
        raw_text = str(page.get_text())
        extracted_text += f"--- Page {page_num + 1} ---\n{raw_text}\n"
        
    return extracted_text

def gather_chapter_chunks_source(filename: str, chapter_query: str) -> str:
    """Leverages the pgvector hybrid index to scrape text chunks belonging to a chapter topic."""
    context_text = ""
    embedder = get_embedder()
    query_vector = str(embedder.encode(chapter_query).tolist())
    
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT chunk_text FROM document_chunks
                WHERE document_name = %s
                ORDER BY ((1.0 - (embedding <=> %s::vector)) * 0.7)
                LIMIT 15
                """,
                (filename, query_vector)
            )
            rows = cur.fetchall()
            for row in rows:
                context_text += row[0] + "\n"
    return context_text

def extract_pdf_toc_and_structure(file_path: str) -> str:
    """
    Extracts the Table of Contents or chapter structure from a PDF using PyMuPDF.
    Falls back to preliminary page text scanning if no embedded outline exists.
    """
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"PDF asset not found: {file_path}")
        
    doc = fitz.open(file_path)
    toc = doc.get_toc()
    
    # 1. Embedded PDF Bookmarks / Outline
    if toc and len(toc) >= 3:
        toc_lines = []
        for item in toc:
            lvl, title, page = item[0], item[1], item[2]
            if lvl <= 2:
                toc_lines.append(f"{'  ' * (lvl - 1)}- {title} (Page {page})")
        if toc_lines:
            return "\n".join(toc_lines[:80])
            
    # 2. Fallback: Scan preliminary pages for Table of Contents
    preliminary_text = ""
    max_scan_pages = min(15, len(doc))
    for p_idx in range(max_scan_pages):
        page_text = str(doc[p_idx].get_text("text"))
        lower_text = page_text.lower()
        if any(marker in lower_text for marker in ["contents", "table of contents", "chapter 1", "chapter one"]):
            preliminary_text += f"\n--- Preliminary Page {p_idx + 1} ---\n" + page_text
            
    if preliminary_text.strip():
        return preliminary_text[:10000]
        
    # 3. Last Fallback: Sample headings from throughout the document
    sample_text = ""
    step = max(1, len(doc) // 10)
    for p_idx in range(0, min(len(doc), 100), step):
        sample_text += f"\n--- Page {p_idx + 1} ---\n" + str(doc[p_idx].get_text("text"))[:400]
    return sample_text[:8000]

def extract_direct_page_texts(file_path: str, question: str) -> List[str]:
    """Extracts exact physical pages or printed book page ranges mentioned in question."""
    page_range_match = re.search(r'pages?\s*(\d+)\s*(?:-|to)\s*(\d+)', question, re.IGNORECASE)
    single_page_match = re.search(r'page\s*(\d+)', question, re.IGNORECASE)

    direct_page_texts = []
    target_start_page = None
    target_end_page = None

    if page_range_match:
        target_start_page = int(page_range_match.group(1))
        target_end_page = int(page_range_match.group(2))
    elif single_page_match:
        target_start_page = int(single_page_match.group(1))
        target_end_page = target_start_page

    if target_start_page is not None and target_end_page is not None:
        if target_start_page > target_end_page:
            target_start_page, target_end_page = target_end_page, target_start_page
        if os.path.exists(file_path):
            try:
                with fitz.open(file_path) as doc:
                    total_p = len(doc)
                    # Physical PDF pages
                    if 1 <= target_start_page <= total_p:
                        for p_num in range(target_start_page, min(target_end_page + 1, total_p + 1)):
                            p_text = str(doc[p_num - 1].get_text("text")).strip()
                            if p_text:
                                direct_page_texts.append(f"--- [Exact Target Document Page {p_num}] ---\n{p_text}")

                    # Fallback for Roman numeral offset in books
                    if not direct_page_texts:
                        for idx in range(total_p):
                            p = doc[idx]
                            first_lines = str(p.get_text("text"))[:400]
                            if re.search(rf'\b{target_start_page}\b', first_lines):
                                for p_num in range(idx, min(idx + (target_end_page - target_start_page) + 1, total_p)):
                                    t = str(doc[p_num].get_text("text")).strip()
                                    if t:
                                        direct_page_texts.append(f"--- [Printed Book Page {target_start_page + (p_num - idx)} (PDF Page {p_num + 1})] ---\n{t}")
                                break
            except Exception as read_err:
                print(f"Direct page extraction error: {read_err}")

    return direct_page_texts

def normalize_url(url: str) -> str:
    """Canonicalizes URLs to prevent duplication by stripping protocols and query strings."""
    if not url:
        return ""
    if "://" not in url:
        url = "http://" + url
    parsed_url = urlparse(url.strip())
    domain = parsed_url.netloc.lower()
    if domain.startswith("www."):
        domain = domain[4:]
    path = parsed_url.path.rstrip("/")
    return f"{domain}{path}"

def get_domain_info(url: str, trusted_domains: Dict[str, float]) -> tuple[bool, float, str]:
    """Extracts hostname from URL and checks if it belongs to trusted academic domains."""
    try:
        if "://" not in url:
            url = "https://" + url
        netloc = urlparse(url.strip()).netloc.lower()
        if netloc.startswith("www."):
            netloc = netloc[4:]
        for trusted_host, weight in trusted_domains.items():
            if netloc == trusted_host or netloc.endswith("." + trusted_host):
                return True, weight, trusted_host
    except Exception as e:
        print(f"Error checking domain: {e}")
    return False, 0.0, ""

def validate_and_rank_citations(raw_citations: List[Dict[str, str]], course_code: str, topic_title: str) -> List[Dict[str, str]]:
    """Scores, filters, and ranks academic citations against trusted sources."""
    validated = []
    seen_urls = set()
    
    if raw_citations and isinstance(raw_citations, list):
        topic_tokens = set(re.findall(r'\w+', topic_title.lower()))
        for item in raw_citations:
            url = item.get("url", "").strip()
            title = item.get("title", "").strip()
            if not url or not title:
                continue
            canonical_url = normalize_url(url)
            if canonical_url in seen_urls:
                continue
            is_trusted, domain_weight, domain_name = get_domain_info(url, TRUSTED_ACADEMIC_DOMAINS)
            if not is_trusted:
                continue
            title_tokens = set(re.findall(r'\w+', title.lower()))
            keywords = len(topic_tokens.intersection(title_tokens))
            score = domain_weight + (keywords * 0.1)
            validated.append({
                "title": title,
                "url": url,
                "domain": domain_name or item.get("domain", "Academic Literature"),
                "reason": item.get("reason", "Foundational literature on this topic."),
                "score": score,
                "canonical_url": canonical_url
            })
            seen_urls.add(canonical_url)
    
    validated.sort(key=lambda x: x["score"], reverse=True)
    validated = [
        {"title": c["title"], "url": c["url"], "domain": c["domain"], "reason": c["reason"]}
        for c in validated
    ]

    registry_hits = CURATED_LITERATURE_REGISTRY.get(course_code.upper().strip(), [])
    for reg in registry_hits:
        if len(validated) >= 2:
            break
        canonical_url = normalize_url(reg["url"])
        if canonical_url not in seen_urls:
            validated.append({
                "title": reg["title"],
                "url": reg["url"],
                "domain": reg["domain"],
                "reason": reg["reason"]
            })
            seen_urls.add(canonical_url)

    return validated[:2]
