from pydantic import BaseModel
from typing import List, Optional, Dict, Any

class MindMapRequest(BaseModel):
    filename: str
    source_type: str  # "chat_history" or "pdf_range"
    map_type: str = "hierarchical"  # "hierarchical", "flowchart", "bubble", "tree", "concept"
    page_start: Optional[int] = None
    page_end: Optional[int] = None
    chapter_query: Optional[str] = None

class MindMapNode(BaseModel):
    id: str
    label: str
    type: str   # root, leaf node, branch

class MindMapEdge(BaseModel):
    id_from: str                      
    id_to: str                        
    label: Optional[str] = None

class MindMapResponse(BaseModel): 
    title: str
    map_type: str
    nodes: List[MindMapNode]
    edges: List[MindMapEdge]
    mermaid_code: str   # pre-compile syntax ready for client-side rendering

class MessageRequest(BaseModel):
    filename: str
    role: str
    text: str

class RenameRequest(BaseModel):
    old_filename: str
    new_filename: str

class ChatRequest(BaseModel):
    question: str
    filename: str

class URLRequest(BaseModel):
    url: str

class CourseGrade(BaseModel):
    name: str
    grade: float

class StudentProfile(BaseModel):
    income: int
    hometown: int
    department: int
    preparation: int
    attendance: int
    gaming: int
    ssc: float
    last: float
    courses: List[CourseGrade]

class LearningResource(BaseModel):
    subject_tag: str
    course_code: str
    title: str
    url: str
    resource_type: str
    explanation: Optional[str] = None

class HeatmapResource(BaseModel):
    id: str
    title: str
    type: str
    wilson_score: float
    success_rate: float
    total_struggling_attempts: int

class QuizAttemptLog(BaseModel):
    topic_name: str
    is_successful: bool
    baseline_grade: float = 0.0

class RateResourceRequest(BaseModel):
    resource_id: str
    topic_name: str = ""
    is_positive: bool
    baseline_grade: float = 2.0

class RateResourceResponse(BaseModel):
    status: str
    wilson_score: float
    total_reviews: int
    positive_reviews: int

class BktUpdateRequest(BaseModel):
    prior_mastery: float
    is_correct: bool
    p_transit: float = 0.15
    p_guess: float = 0.20
    p_slip: float = 0.10

class BktUpdateResponse(BaseModel):
    updated_mastery: float
    predicted_next_correct: float

class TimestampMapRequest(BaseModel):
    question_text: str
    srt_subtitles: str
    window_size: int = 3

class ScannedQuestionData(BaseModel):
    question_text: str
    core_concept: str
    question_type: str = "short_answer"  # "multiple_choice", "code_trace", "short_answer", "proof"
    extracted_code: Optional[str] = None
    summary: str

class PyqPhotoScanRequest(BaseModel):
    image_base64: str  # Data URI (e.g. data:image/jpeg;base64,...) or raw base64 string
    course_code: Optional[str] = None
    srt_subtitles: Optional[str] = None
    window_size: int = 3

class PyqPhotoScanResponse(BaseModel):
    status: str
    scanned_question: ScannedQuestionData
    timestamp_mapping: Optional[Dict[str, Any]] = None

class MermaidValidateRequest(BaseModel):
    raw_mermaid: str

class FocusAnalysisRequest(BaseModel):
    course_code: str
    course_grade: Optional[float] = 2.0
    filename: str
    prerequisites: Optional[List[str]] = []

class SubchapterFocus(BaseModel):
    subchapter_id: str
    title: str
    page_start: int
    page_end: int
    estimated_minutes: int
    keypoints: List[str]
    exam_warning: Optional[str] = None

class ChapterFocus(BaseModel):
    chapter_number: int
    chapter_title: str
    page_range: str
    priority: str  # "CRITICAL", "HIGH_YIELD", "FOUNDATIONAL"
    relevance_rationale: str
    subchapters: List[SubchapterFocus]

class FocusAnalysisResponse(BaseModel):
    course_code: str
    course_name: str
    filename: str
    total_estimated_study_hours: float
    recommended_chapters: List[ChapterFocus]

class ResolveCoursePdfRequest(BaseModel):
    course_code: str

class ResolveCoursePdfResponse(BaseModel):
    course_code: str
    course_name: str
    filename: str
    source: str  # "neon", "local", "online"
    title: str
    message: str

class SubchapterFlashcardRequest(BaseModel):
    course_code: str
    subchapter_title: str
    page_start: int
    page_end: int
    filename: str
    keypoints: Optional[List[str]] = []
    exam_warning: Optional[str] = None

class FlashcardItem(BaseModel):
    resource_id: str
    topic: str
    duration_min: int
    type: str
    content: str

class ResolveSubchapterVideoRequest(BaseModel):
    course_code: str
    subchapter_title: str

class ResolveSubchapterVideoResponse(BaseModel):
    video_id: str
    title: str
    url: str
    channel: str
    duration_min: int
