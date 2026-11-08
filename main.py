"""
Educational Resource Predictor API
Clean Architecture Orchestrator & Fast Execution Engine
"""

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
import nest_asyncio

# Apply nest_asyncio for smooth nested asyncio loops in ASGI environments
nest_asyncio.apply()

# Lifespan event handler replacing deprecated on_event
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initializes database tables on application startup."""
    from app.core.database import init_all_databases
    init_all_databases()
    yield

# Initialize the central FastAPI application
app = FastAPI(
    title="Educational Resource Predictor API",
    description="Clean Architecture Modular Recommender and Academic Diagnostic Suite",
    version="2.0.0",
    lifespan=lifespan
)

# CORS middleware configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register modular domain APIRouters
from app.bundler import router as bundler_router
from app.lens_switcher import router as lens_router
from app.routers.predict import router as predict_router
from app.routers.documents import router as documents_router
from app.routers.chat import router as chat_router
from app.routers.diagnostics import router as diagnostics_router
from app.routers.pedagogy import router as pedagogy_router

app.include_router(bundler_router)
app.include_router(lens_router)
app.include_router(predict_router)
app.include_router(documents_router)
app.include_router(chat_router)
app.include_router(diagnostics_router)
app.include_router(pedagogy_router)

# Static file serving for single-page web dashboard
@app.get("/")
def serve_frontend():
    return FileResponse("index.html")

@app.get("/script.js")
def serve_js():
    return FileResponse("script.js")

# Backwards-compatibility re-exports for test suites, scripts, and legacy callers
from app.models.schemas import *
from app.models.ml_model import ResourcePredictorMLP
from app.core.config import (
    DATABASE_URL,
    YOUTUBE_API_KEY,
    GEMINI_API_KEY,
    GROQ_API_KEY,
    COURSE_MAPPING,
    PREREQUISITE_GRAPH
)
from app.core.database import (
    get_db_connection,
    init_chat_db,
    init_jobs_db,
    init_quiz_db
)

# PEP 562 module-level dynamic attributes for lazy-loaded ML models and API clients
def __getattr__(name: str):
    if name == "embedder":
        from app.services.embedding_service import get_embedder
        return get_embedder()
    if name == "cross_encoder":
        from app.services.embedding_service import get_cross_encoder
        return get_cross_encoder()
    if name == "client":
        from app.services.llm_service import get_groq_client
        return get_groq_client()
    raise AttributeError(f"module '{__name__}' has no attribute '{name}'")
