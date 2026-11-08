import concurrent.futures
from typing import List, Optional
from fastapi import APIRouter, HTTPException
import numpy as np
import requests
from duckduckgo_search import DDGS
from app.core.config import COURSE_MAPPING, PREREQUISITE_GRAPH, YOUTUBE_API_KEY
from app.core.database import get_db_connection
from app.models.schemas import StudentProfile, LearningResource
from app.models.ml_model import get_ml_components
from app.services.llm_service import get_groq_client

router = APIRouter(tags=["Prediction & Analytics"])

def fetch_and_store_yt_videos(course_code: str) -> Optional[LearningResource]:
    """Fetches a video from YouTube if not in Neon, and saves it to the database."""
    if not YOUTUBE_API_KEY:
        print("YouTube API key not set. Skipping YouTube fetch.")
        return None
    
    course_name = COURSE_MAPPING.get(course_code, course_code)
    search_query = f"{course_name} crash course"
    url = "https://www.googleapis.com/youtube/v3/search"
    params = {
        "part": "snippet",
        "q": search_query,
        "type": "video",
        "maxResults": 1,
        "videoDuration": "short",
        "key": YOUTUBE_API_KEY
    }
    
    response = None
    try:
        response = requests.get(url, params=params, timeout=10)
        if response.status_code != 200:
            print(f"❌ YouTube API Rejected the Request! Status Code: {response.status_code}")
            return None
        
        data = response.json()
        if not data.get("items"):
            return None
            
        video = data["items"][0]
        title = video["snippet"]["title"].replace("&quot;", "'").replace("&#39;", "'")
        video_id = video["id"]["videoId"]
        video_url = f"https://www.youtube.com/watch?v={video_id}"
        
        try:  
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        INSERT INTO learning_resources (course_code, subject_tag, title, url, resource_type) 
                        VALUES (%s, %s, %s, %s, %s) 
                        """,
                        (course_code, course_name, title, video_url, "video")
                    )
                conn.commit()
        except Exception as db_err:
            print(f"❌ Database Insertion Error: {db_err}")
            
        return LearningResource(
            subject_tag=course_name, 
            course_code=course_code, 
            title=title, 
            url=video_url, 
            resource_type="video"
        )
    except Exception as e:
        print(f"YouTube API Error: {e}")
    return None

def fetch_and_store_web_resources(course_code: str) -> List[LearningResource]:
    """Fetches an article and a PDF textbook using DuckDuckGo, and saves them to Neon."""
    course_name = COURSE_MAPPING.get(course_code, course_code)
    discovered_resources = []
    
    try:
        with DDGS(timeout=10) as ddgs:
            article_query = f"{course_name} (tutorial OR basics OR guide) computer science"
            article_results = list(ddgs.text(article_query, max_results=1))
            
            if article_results:
                item = article_results[0]
                title = str(item.get("title", f"{course_name} Guide"))
                url = str(item.get("href", ""))
                
                with get_db_connection() as conn:
                    with conn.cursor() as cur:
                        cur.execute(
                            """
                            INSERT INTO learning_resources (course_code, subject_tag, title, url, resource_type) 
                            VALUES (%s, %s, %s, %s, %s) 
                            """,
                            (course_code, course_name, title, url, "article")
                        )
                    conn.commit()
                
                discovered_resources.append(LearningResource(
                    subject_tag=course_name, course_code=course_code,
                    title=title, url=url, resource_type="article"
                ))
            
        pdf_query = f"{course_name} (textbook OR lecture notes OR pdf OR notes) filetype:pdf"
        pdf_results = list(ddgs.text(pdf_query, max_results=1))
        
        if pdf_results:
            item = pdf_results[0]
            title = str(item.get("title", f"{course_name} Textbook"))
            url = str(item.get("href", ""))
            
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        INSERT INTO learning_resources (course_code, subject_tag, title, url, resource_type) 
                        VALUES (%s, %s, %s, %s, %s) 
                        """,
                        (course_code, course_name, title, url, "book")
                    )
                conn.commit()
            
            discovered_resources.append(LearningResource(
                subject_tag=course_name, course_code=course_code,
                title=title, url=url, resource_type="book"
            ))
    except Exception as e:
        print(f"Web Resource Discovery Error for {course_code}: {e}")
        
    return discovered_resources

def fetch_neon_resources(subjects: List[str]) -> List[LearningResource]:
    """Retrieves learning resources from Neon database for a given list of subject codes."""
    if not subjects:
        return []
    
    resources_list = []
    try: 
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT subject_tag, title, url, resource_type, course_code
                    FROM learning_resources 
                    WHERE course_code = ANY(%s)
                    """,
                    (subjects,)
                )
                rows = cur.fetchall()  
                seen_keys = set()
                for row in rows:
                    key = f"{str(row[4]).strip().upper()}_{str(row[1]).strip().lower()}_{str(row[2]).strip().lower()}"
                    if key in seen_keys:
                        continue
                    seen_keys.add(key)
                    resources_list.append(LearningResource(
                        subject_tag=row[0], 
                        title=row[1], 
                        url=row[2], 
                        resource_type=row[3],
                        course_code=row[4]
                    ))
    except Exception as e:
        print(f"Database Error: {e}")
    return resources_list

def get_all_prerequisites(course_id: str, visited=None) -> List[str]:
    """Recursively traces all upstream prerequisite dependencies using DFS."""
    if visited is None:
        visited = set()
    if course_id in visited:
        return []
    visited.add(course_id)
    prerequisites = PREREQUISITE_GRAPH.get(course_id, [])
    all_prereqs = []
    for prereq in prerequisites:
        all_prereqs.append(prereq)
        all_prereqs.extend(get_all_prerequisites(prereq, visited))
    return list(set(all_prereqs))

@router.post("/predict")
def predict_student_needs(student: StudentProfile):
    try:
        model, scaler = get_ml_components()
        if model is None or scaler is None:
            raise RuntimeError("ML model and scaler not loaded.")

        input_data = np.array([[
            student.income, student.hometown, student.department,
            student.preparation, student.attendance, student.gaming,
            student.ssc, student.last
        ]])
        
        scaled_data = scaler.transform(input_data)
        import torch
        input_tensor = torch.tensor(scaled_data, dtype=torch.float32)
        
        with torch.no_grad():
            raw_pred = model(input_tensor)
            probability = torch.sigmoid(raw_pred).item()
            
        safe_ai_prob = max(0.10, probability)
            
        habit_risk = 0.15
        if student.attendance < 3: habit_risk += 0.25
        if student.preparation == 1: habit_risk += 0.35
        elif student.preparation == 2: habit_risk += 0.25
        if student.gaming == 1: habit_risk += 0.30
        
        habit_risk = min(0.95, habit_risk)

        recommended_subjects = [c.name for c in student.courses if c.grade < 3.0]
        
        prereq_set = set()
        for subject_code in recommended_subjects:
            found_prereqs = get_all_prerequisites(subject_code)
            prereq_set.update(found_prereqs)
            
        recommended_subjects = list(set(recommended_subjects + list(prereq_set)))
        
        final_probability = (safe_ai_prob * 0.6) + (habit_risk * 0.4)
        needs_help = final_probability > 0.5
        risk_percentage = round(final_probability * 100, 2)

        # TODO: Call DAG Depth-First Search (DFS) helper function here

        if len(recommended_subjects) > 0 and needs_help:
            alert_level = "critical"
            msg = "🚨 Critical Risk: Poor study habits and failing current courses."
        elif len(recommended_subjects) > 0 and not needs_help:
            alert_level = "subject_alert"
            msg = "⚠️ Targeted Risk: Good general habits, but struggling in specific classes."
        elif len(recommended_subjects) == 0 and needs_help:
            alert_level = "habit_alert"
            msg = "⚠️ Habit Risk: Current grades are okay, but AI detects risky study patterns."
        else:
            alert_level = "safe"
            msg = "✅ On Track: Strong habits and passing all current courses."
            
        client = get_groq_client()
        resource_links = []
        if len(recommended_subjects) > 0:
            for subject_code in recommended_subjects:
                db_resources = fetch_neon_resources([subject_code])
                if not db_resources:
                    with concurrent.futures.ThreadPoolExecutor() as executor:
                        future_yt = executor.submit(fetch_and_store_yt_videos, subject_code)
                        future_web = executor.submit(fetch_and_store_web_resources, subject_code)
                        new_video = future_yt.result()
                        new_web_docs = future_web.result()
                    if new_video:
                        db_resources.append(new_video)
                    if new_web_docs:
                        db_resources.extend(new_web_docs)
                        
                def generate_explanation(res):
                    if not client:
                        res.explanation = "This resource covers foundational concepts to help you succeed."
                        return res
                    explain_prompt = f"""
                    A university student is struggling with the course '{res.subject_tag}'. 
                    I am recommending a {res.resource_type} titled '{res.title}' for the subject '{res.subject_tag}'.
                    If this subject is a prerequisite for a more advanced class, explain that mastering this foundational concept is the root-cause fix for their struggles.
                    Write a single, encouraging sentence explaining why watching/reading this will help them improve their grade.
                    """
                    try:
                        explain = client.chat.completions.create(
                            model="openai/gpt-oss-20b",
                            messages=[{"role": "user", "content": explain_prompt}],
                            max_tokens=80
                        )
                        content = explain.choices[0].message.content if explain.choices else ""
                        res.explanation = (content or "").strip()
                    except Exception as e:
                        print(f"Groq Explanation Error: {e}")
                        res.explanation = "This resource covers foundational concepts to help you succeed."
                    return res
                
                with concurrent.futures.ThreadPoolExecutor() as executor:
                    resource_links.extend(list(executor.map(generate_explanation, db_resources)))
                    
        elif needs_help and len(recommended_subjects) == 0:
            if client:
                habit_prompt = f"""
                A university student has good grades (GPA: {student.last}), but poor study habits. 
                They study {student.preparation} (1=Low, 3=High), attend {student.attendance} (1=Low, 4=High), 
                and game {student.gaming} (1=High, 0=Low).
                Write a highly personalized, 2-sentence warning about how these specific habits might cause 
                them to burn out or fail future, harder classes. Be direct.
                """
                try: 
                    habit_response = client.chat.completions.create(
                        model="openai/gpt-oss-20b",
                        messages=[{"role": "user", "content": habit_prompt}],
                        max_tokens=100
                    )
                    habit_content = habit_response.choices[0].message.content if habit_response.choices else ""
                    resource_links.append({
                        "subject_tag": "General Advice",
                        "course_code": "Study Strategy",
                        "title": "AI Habit Analysis",
                        "url": "https://www.computersciencedegreehub.com/top-30-computer-science-programming-blogs-2014/",
                        "resource_type": "article",
                        "explanation": (habit_content or "").strip()
                    })
                except Exception as e:
                    print(f"Habit LLM error: {e}")

        # Deduplicate resource_links
        deduped_links = []
        seen_res_keys = set()
        for r in resource_links:
            r_dict = r if isinstance(r, dict) else r.dict() if hasattr(r, 'dict') else vars(r)
            key = f"{str(r_dict.get('course_code', '')).strip().upper()}_{str(r_dict.get('title', '')).strip().lower()}_{str(r_dict.get('url', '')).strip().lower()}"
            if key not in seen_res_keys:
                seen_res_keys.add(key)
                deduped_links.append(r)

        return {
            "alert_level": alert_level,
            "needs_resources": needs_help,
            "confidence_score": risk_percentage,
            "message": msg,
            "subjects_to_focus": recommended_subjects,
            "resource_links": deduped_links
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/analytics/global")
def get_global_analytics():
    """Returns total processed PDFs and AI chat interaction counts."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT COUNT(*) FROM pdf_jobs")
                result = cur.fetchone()
                total_pdfs = result[0] if result else 0
                
                cur.execute("SELECT COUNT(*) FROM chat_messages WHERE role = 'ai'")
                result = cur.fetchone()
                total_ai_interactions = result[0] if result else 0
                
        return {
            "total_pdfs": total_pdfs,
            "total_ai_interactions": total_ai_interactions
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
