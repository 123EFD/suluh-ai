import os
import re
import json
from typing import Dict, Any, Optional, List
from app.services.llm_service import get_groq_client
from app.timestamp_mapper import parse_srt_subtitles, map_exam_question_to_video_timestamp

def normalize_base64_image(image_input: str) -> str:
    """Ensures image string has the proper data URI scheme for multimodal LLM APIs."""
    cleaned = image_input.strip()
    if cleaned.startswith("data:image/"):
        return cleaned
    # Default to jpeg if raw base64 string is provided
    return f"data:image/jpeg;base64,{cleaned}"

def scan_pyq_exam_photo(
    image_base64: str,
    course_code: Optional[str] = None,
    srt_subtitles: Optional[str] = None,
    window_size: int = 3
) -> Dict[str, Any]:
    """
    Multimodal PYQ Photo Scanner:
    Transcribes photographed university past-exam questions, converts math into LaTeX,
    identifies core concept, and optionally maps to lecture video timestamps.
    """
    client = get_groq_client()
    if not client:
        raise RuntimeError("Groq LLM client is unavailable.")

    data_uri = normalize_base64_image(image_base64)

    # Multi-tier multimodal vision cascade: Llama 4 suite -> Qwen 3.8 27B multimodal
    configured_model = os.getenv("VISION_MODEL", "").strip()
    candidate_vision_models = []
    if configured_model:
        candidate_vision_models.append(configured_model)
    candidate_vision_models.extend([
        "meta-llama/llama-4-scout-17b-16e-instruct",
        "meta-llama/llama-4-maverick-17b-128e-instruct",
        "qwen/qwen3.8-27b"
    ])

    course_context = f" for course {course_code.strip().upper()}" if course_code else ""
    prompt = f"""You are an expert academic exam digitization scanner{course_context}.
Transcribe this photographed university past-exam question accurately into structured JSON.

Requirements:
1. Preserve all mathematical notation using standard LaTeX syntax enclosed in $...$ for inline or $$...$$ for display equations.
2. If code snippets or pseudocode are present, extract them verbatim into 'extracted_code'.
3. Classify the question type into one of: 'multiple_choice', 'code_trace', 'short_answer', 'proof'.
4. Produce a concise 1-sentence 'summary' query optimal for lecture video retrieval.

Return STRICTLY a JSON object matching this schema:
{{
  "question_text": "full exact question text with LaTeX math formulas",
  "core_concept": "primary Computer Science topic / syllabus chapter",
  "question_type": "short_answer",
  "extracted_code": null,
  "summary": "1-sentence video search summary"
}}
Do NOT output any markdown commentary outside the JSON block."""

    scanned_data = None
    last_error = None

    for model_name in candidate_vision_models:
        try:
            response = client.chat.completions.create(
                model=model_name,
                messages=[{
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {"type": "image_url", "image_url": {"url": data_uri}}
                    ]
                }],
                temperature=0.1,
                max_tokens=600
            )
            raw_content = response.choices[0].message.content or ""
            # Clean possible markdown ```json formatting
            cleaned_json = re.sub(r'^```(?:json)?\s*|\s*```$', '', raw_content.strip(), flags=re.MULTILINE).strip()
            scanned_data = json.loads(cleaned_json)
            break
        except Exception as err:
            last_error = err
            continue

    if not scanned_data:
        raise RuntimeError(f"Vision model transcription failed across candidate suite: {last_error}")

    result: Dict[str, Any] = {
        "status": "success",
        "scanned_question": {
            "question_text": scanned_data.get("question_text", ""),
            "core_concept": scanned_data.get("core_concept", "General CS"),
            "question_type": scanned_data.get("question_type", "short_answer"),
            "extracted_code": scanned_data.get("extracted_code"),
            "summary": scanned_data.get("summary", scanned_data.get("question_text", "")[:100])
        },
        "timestamp_mapping": None
    }

    # If subtitle text was supplied, perform automatic video timestamp alignment
    if srt_subtitles and srt_subtitles.strip():
        parsed_subs = parse_srt_subtitles(srt_subtitles)
        query_text = result["scanned_question"]["summary"] or result["scanned_question"]["question_text"]
        mapping = map_exam_question_to_video_timestamp(query_text, parsed_subs, window_size)
        result["timestamp_mapping"] = mapping

    return result
