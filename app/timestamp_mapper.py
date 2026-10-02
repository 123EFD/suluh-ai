import re
from typing import List, Dict, Any, Optional

def parse_srt_subtitles(srt_content: str) -> List[Dict[str, Any]]:
    """Parses standard SRT subtitle text into timestamped segments."""
    entries = []
    blocks = re.split(r'\n\s*\n', srt_content.strip())
    for block in blocks:
        lines = block.strip().split('\n')
        if len(lines) >= 3:
            time_match = re.search(r'(\d+):(\d+):(\d+),(\d+)\s*-->\s*(\d+):(\d+):(\d+),(\d+)', lines[1])
            if time_match:
                h1, m1, s1, ms1 = map(int, time_match.groups()[:4])
                start_sec = h1 * 3600 + m1 * 60 + s1 + ms1 / 1000.0
                text = " ".join(lines[2:]).strip()
                entries.append({
                    "start_sec": start_sec,
                    "text": text
                })
    return entries

def map_exam_question_to_video_timestamp(
    question_text: str,
    subtitles: List[Dict[str, Any]],
    window_size: int = 3
) -> Dict[str, Any]:
    if not subtitles or not question_text:
        return {
            "timestamp_sec": 0.0,
            "similarity_score": 0.0,
            "matched_text": ""
        }
    question_tokens = set(re.findall(r'\b\w{3,}\b', question_text.lower()))
    best_score = 0.0
    best_timestamp = 0.0
    best_text = ""
    window_count = len(subtitles) - window_size + 1
    for i in range(window_count):
        text_window = " ".join(sub["text"] for sub in subtitles[i:i + window_size])
        text_tokens = set(re.findall(r'\b\w{3,}\b', text_window.lower()))
        intersection = question_tokens.intersection(text_tokens)
        if question_tokens:
            score = len(intersection) / len(question_tokens)
        else:
            score = 0.0
        if score > best_score:
            best_score = score
            best_timestamp = subtitles[i]["start_sec"]
            best_text = text_window
    return {
        "timestamp_sec": best_timestamp,
        "similarity_score": best_score,
        "matched_text": best_text
    }

