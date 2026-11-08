import hashlib
from typing import Optional, Dict
from groq import Groq
from app.core.config import GROQ_API_KEY

_client: Optional[Groq] = None

def get_groq_client() -> Optional[Groq]:
    """Returns a singleton instance of the Groq API client."""
    global _client
    if _client is None and GROQ_API_KEY:
        _client = Groq(api_key=GROQ_API_KEY)
    return _client

# Short-term in-memory RAM cache for instant Q&A answers
question_cache: Dict[str, str] = {}

def generate_cache_key(pdf_name: str, question: str) -> str:
    """Creates a deterministic MD5 hash key for a specific question on a specific PDF."""
    unique_string = f"{pdf_name}_{question.strip().lower()}"
    return hashlib.md5(unique_string.encode(), usedforsecurity=False).hexdigest()

def optimize_search_query(client: Optional[Groq], question: str) -> str:
    """Transforms a user question into a natural search query for semantic vector DB."""
    if not client:
        return question

    prompt = f"""
    You are a search query optimizer for a Semantic Vector Database. 
    Extract the core academic subjects and keywords from the student's question. 
    CRITICAL RULES: 
    1. NEVER use boolean operators like "OR", "AND", or parentheses "()".
    2. NEVER write SQL code (like SELECT or WHERE).
    3. Write the query as a simple, natural plain-English sentence.
    Only output the query itself, nothing else.
    Student Question: {question}
    """
    try:
        optimizer_response = client.chat.completions.create(
            model="qwen/qwen3.8-27b",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=150
        )
        content = optimizer_response.choices[0].message.content if optimizer_response.choices else None
        optimized = (content or "").strip() if content else question
        return optimized.replace('"', '')
    except Exception as e:
        print(f"Optimizer fallback to original query: {e}")
        return question
