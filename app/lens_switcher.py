#switch explain mode , lets a learner toggle between Analogy, Visual‑Logic (flowchart), 
# and Exam‑Marking‑Scheme lenses for any piece of content.

import json
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import importlib
try:
    from app.groq_client import groq_chat
except ModuleNotFoundError:
    groq_chat = importlib.import_module("groq_client").groq_chat

router = APIRouter(prefix="/lens", tags=["ExplanationLens"])

class LensRequest(BaseModel):
    source_text: str
    lens: str # "analogy", "visual_logic", or "exam_marking_scheme"
    
class LensResponse(BaseModel):
    transformed: str
    
SYSTEM_PROMPT = """You are a learning‑assistant.  
Given a piece of academic text, output ONE of the following lenses **exactly** as requested:
* **analogy** – rewrite the concept using a simple real‑world metaphor. Keep it under 150 words.
* **visual** – output a **valid Mermaid flowchart** that captures the logical steps. Use only `graph TD` syntax.
* **exam** – list the key technical keywords an examiner would look for, each on its own line, prefixed with “✔”.
Do NOT add any explanations, headings, or extra text. Do NOT wrap the output in markdown code blocks or backticks. Return *only* the requested content."""

try:
    from app.lens_cache import lens_cache
except ModuleNotFoundError:
    lens_cache = importlib.import_module("lens_cache").lens_cache

@router.post("/transform", response_model=LensResponse)
def transform(req: LensRequest):
    if req.lens not in {"analogy", "visual", "exam"}:
        raise HTTPException(status_code=400, detail="Invalid lens type. Must be 'analogy', 'visual', or 'exam'.")
    
    # Check LRU TTL Cache first
    cached = lens_cache.get(req.lens, "academic", req.source_text)
    if cached:
        return LensResponse(transformed=cached)
    
    # few-shot prompt
    user_msg = f"""Topic : {req.lens}\n---\n{req.source_text}"""
    
    try:
        result = groq_chat(
            system_prompt=SYSTEM_PROMPT,
            user_message=user_msg,
            model="openai/gpt-oss-20b"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Transformation failed: {str(e)}")
    
    cleaned = result.strip()
    lens_cache.put(req.lens, "academic", req.source_text, cleaned)
    return LensResponse(transformed=cleaned)