import os
import re
import time
import requests
from typing import List, Dict, Optional, Any
from dotenv import load_dotenv

load_dotenv()

# Curated YouTube links for video chunk topics
# Maps the topic names in our database to high-quality CS lecture videos
CURATED_VIDEOS = {
    "Reinforcement Learning High Res": "https://www.youtube.com/watch?v=2pWv7GOvuf0",
    "Ml For Health High Res": "https://www.youtube.com/watch?v=Gxs-HBIS0cU",
    "Deep Learning High Res": "https://www.youtube.com/watch?v=aircAruvnKk",
    "Numerics High Res": "https://www.youtube.com/watch?v=fNk_zzaMoSs",
    "Cryptocurrency High Res": "https://www.youtube.com/watch?v=bBC-nXj3Ng4",
    "Theory Of Computation High Res": "https://www.youtube.com/watch?v=58N2N7zJGrQ",
    "Cognitive Robotics High Res": "https://www.youtube.com/watch?v=SIIiMGOelnE",
    "Computer Vision 2 2 High Res": "https://www.youtube.com/watch?v=vT1JzLTH4G4",
    "Image Processing High Res": "https://www.youtube.com/watch?v=QMLbTEQJCaI",
    "Computer Networks": "https://www.youtube.com/watch?v=IPvYjXCsTg8",
    "Data Structures": "https://www.youtube.com/watch?v=RBSGKlAvoiM",
    "Algorithms": "https://www.youtube.com/watch?v=0IAPZzGSbME",
    "Operating Systems": "https://www.youtube.com/watch?v=26QPDBe-NB8",
}

# Verified academic and premier pedagogical channels
VERIFIED_COLLEGIATE_CHANNELS = {
    "mit opencourseware",
    "stanford online",
    "harvard university",
    "freecodecamp.org",
    "computerphile",
    "3blue1brown",
    "neso academy",
    "gate smashers",
    "cs50",
    "ben eater",
}

# In-Memory Cache-Aside Storage for YouTube API responses
# Structure: { normalized_query: { "url": str, "title": str, "channel": str, "timestamp": float } }
_YOUTUBE_CACHE: Dict[str, Dict[str, Any]] = {}
CACHE_TTL_SECONDS = 86400  # 24-hour Time-To-Live to conserve quota


# ==============================================================================
# [BLANK 2]: Relevance-Scored Video Selection & Cache-Aside Filter
# Task: Given a target CS topic and candidate YouTube videos retrieved from the
# YouTube Data API v3 or educational video search, calculate a lexical and semantic
# title-matching score (Jaccard token similarity + Levenshtein distance), grant priority
# weights to verified university channels (e.g. MIT OpenCourseWare, Stanford Online, Harvard,
# freeCodeCamp, CrashCourse, Computerphile), select the most pedagogically relevant video,
# and persist the selection in the LRU cache with a 24-hour TTL (Time-To-Live).
#
# Input:
#   topic: str - Educational topic query (e.g., "Dijkstra algorithm lecture")
#   candidates: List[Dict[str, str]] - [{title, video_id, channel, description}]
# Output:
#   Optional[Dict[str, str]] - Winning candidate video object with direct URL
# ==============================================================================
def rank_and_cache_video_selection(topic: str, candidates: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:

    # --------------------------------------------------------------------------
    # [BLANK 2 - TODO FOR LEARNER]:
    # 1. Normalize the topic string into lowercase words (stopwords excluded).
    # 2. For each video in candidates:
    #      a. Compute Jaccard Index = len(topic_tokens & title_tokens) / len(topic_tokens | title_tokens)
    #      b. Check if video['channel'].lower() matches any in VERIFIED_COLLEGIATE_CHANNELS (+0.3 bonus)
    #      c. Check for educational keywords ("lecture", "tutorial", "algorithm", "cs") (+0.1 bonus)
    # 3. Identify the candidate with the highest overall relevance score.
    # 4. Save the winner to _YOUTUBE_CACHE[topic.lower()] with {"url": ..., "timestamp": time.time()}.
    # 5. Return the winner dict.
    # --------------------------------------------------------------------------
    if not candidates:
        return None

    norm_topic = topic.lower()
    topic_tokens = set(re.findall(r'\b[a-z0-9]{3,}\b', norm_topic))

    best_candidate = None
    best_score = -1.0

    for cand in candidates:
        title = cand.get("title", "").lower()
        channel = cand.get("channel", "").lower()
        title_tokens = set(re.findall(r'\b[a-z0-9]{3,}\b', title))

        intersection = len(topic_tokens & title_tokens)
        union = len(topic_tokens | title_tokens) or 1
        jaccard = intersection / union

        score = jaccard
        if any(vc in channel for vc in VERIFIED_COLLEGIATE_CHANNELS):
            score += 0.35
        if any(w in title for w in ("lecture", "full course", "tutorial", "explained", "algorithm", "cs", "computer science")):
            score += 0.15

        if score > best_score:
            best_score = score
            best_candidate = cand

    winner = best_candidate or candidates[0]
    result = {
        "url": f"https://www.youtube.com/watch?v={winner['video_id']}",
        "title": winner.get("title", topic),
        "channel": winner.get("channel", "Academic Video"),
        "timestamp": time.time()
    }
    
    # Cache result
    _YOUTUBE_CACHE[norm_topic] = result
    return result

def search_youtube_live(topic: str) -> Optional[Dict[str, Any]]:
    """
    Retrieves live educational YouTube videos using the official YouTube Data API v3
    with quota-conserving Cache-Aside lookup and scraper fallback.
    """
    norm_topic = topic.strip().lower()

    # 1. Check in-memory Cache-Aside with TTL
    cached = _YOUTUBE_CACHE.get(norm_topic)
    if cached and (time.time() - cached.get("timestamp", 0) < CACHE_TTL_SECONDS):
        return cached

    # 2. Check Static Curated Fallback
    for cur_title, cur_url in CURATED_VIDEOS.items():
        if cur_title.lower() == norm_topic or cur_title.lower() in norm_topic:
            return {"url": cur_url, "title": cur_title, "channel": "Curated Archive", "timestamp": time.time()}

    # 3. Call Live YouTube Data API v3 if API key exists
    api_key = os.getenv("YOUTUBE_API_KEY")
    if api_key and api_key.strip():
        try:
            query = f"{topic} computer science university lecture"
            endpoint = "https://www.googleapis.com/youtube/v3/search"
            params = {
                "part": "snippet",
                "q": query,
                "type": "video",
                "videoCategoryId": "27",  # Education category
                "maxResults": 5,
                "key": api_key.strip(),
            }
            resp = requests.get(endpoint, params=params, timeout=5)
            if resp.status_code == 200:
                data = resp.json()
                candidates = []
                for item in data.get("items", []):
                    vid_id = item.get("id", {}).get("videoId")
                    snippet = item.get("snippet", {})
                    if vid_id:
                        candidates.append({
                            "video_id": vid_id,
                            "title": snippet.get("title", ""),
                            "channel": snippet.get("channelTitle", ""),
                            "description": snippet.get("description", "")
                        })
                if candidates:
                    return rank_and_cache_video_selection(topic, candidates)
            else:
                print(f"YouTube Data API returned status {resp.status_code}: {resp.text[:120]}")
        except Exception as err:
            print(f"YouTube API call failed: {err}")

    # 4. Resilient Fallback to YouTube Search Result Page Parsing / Safe Link
    try:
        query_enc = topic.replace(" ", "+")
        # Attempt public oEmbed / discovery endpoint
        search_url = f"https://www.youtube.com/results?search_query={query_enc}+lecture"
        headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
        resp = requests.get(search_url, headers=headers, timeout=4)
        if resp.status_code == 200:
            video_ids = re.findall(r'/watch\?v=([a-zA-Z0-9_-]{11})', resp.text)
            if video_ids:
                unique_vids = list(dict.fromkeys(video_ids))[:4]
                candidates = [{"video_id": vid, "title": f"{topic} Lecture", "channel": "YouTube Educational"} for vid in unique_vids]
                return rank_and_cache_video_selection(topic, candidates)
    except Exception as scrape_err:
        print(f"YouTube discovery fallback failed: {scrape_err}")

    # 5. Final Graceful Fallback
    fallback_result = {
        "url": f"https://www.youtube.com/results?search_query={topic.replace(' ', '+')}+lecture",
        "title": f"{topic} Collegiate Lecture Search",
        "channel": "YouTube Search",
        "timestamp": time.time()
    }
    _YOUTUBE_CACHE[norm_topic] = fallback_result
    return fallback_result


def get_video_url(topic: str) -> str:
    """
    Returns the direct YouTube URL for a given topic.
    """
    result = search_youtube_live(topic)
    if result and "url" in result:
        return result["url"]
    return CURATED_VIDEOS.get(topic, "https://www.youtube.com/results?search_query=" + topic.replace(" ", "+"))
