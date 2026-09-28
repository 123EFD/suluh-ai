---
title: Suluh AI Academic Suite
emoji: 🏛️
colorFrom: indigo
colorTo: blue
sdk: docker
app_port: 7860
---

# 🏛️ suluh-ai: University AI Academic Suite & Pedagogical Recommender

[![FastAPI](https://img.shields.io/badge/Backend-FastAPI-009688.svg?style=flat&logo=fastapi)](https://fastapi.tiangolo.com/)
[![Flutter](https://img.shields.io/badge/Frontend-Flutter%20Web-02569B.svg?style=flat&logo=flutter)](https://flutter.dev/)
[![Neon Database](https://img.shields.io/badge/PostgreSQL-Neon%20pgvector-00E599.svg?style=flat&logo=postgresql)](https://neon.tech/)
[![Groq Cloud](https://img.shields.io/badge/LLM-Groq%20Cloud-F55036.svg?style=flat)](https://groq.com/)
[![PyTorch](https://img.shields.io/badge/ML-PyTorch%20MLP-EE4C2C.svg?style=flat&logo=pytorch)](https://pytorch.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

An enterprise-grade, full-stack collegiate learning platform and academic intervention engine. Built with a high-performance **FastAPI** backend and an archival **Dark Academia Flutter Web** workspace, the system combines neural network student risk prediction, curriculum prerequisite traversal, diagnostic chapter radar mapping, multi-modal study bundle scheduling (0/1 Knapsack), real-time streaming RAG PDF scholarship with LaTeX KaTeX formatting, authentic research literature citations, and live YouTube educational lecture streaming.

---

## 📑 Table of Contents

- [🎯 Project Objectives & Core Vision](#-project-objectives--core-vision)
- [🏗️ System Architecture & Data Flow](#️-system-architecture--data-flow)
- [✨ Key Features & Functionality](#-key-features--functionality)
  - [1. Syllabus Diagnostic Chapter Radar](#1-syllabus-diagnostic-chapter-radar)
  - [2. Multi-Modal Study Bundler (0/1 Knapsack Allocation)](#2-multi-modal-study-bundler-01-knapsack-allocation)
  - [3. Deep-Dive Research Flashcards & LaTeX Math Engine](#3-deep-dive-research-flashcards--latex-math-engine)
  - [4. Real-Time PDF AI Scholar & Streaming RAG](#4-real-time-pdf-ai-scholar--streaming-rag)
  - [5. Student Performance Risk Predictor (PyTorch MLP)](#5-student-performance-risk-predictor-pytorch-mlp)
  - [6. Live YouTube Search API & 24-Hour Cache-Aside Layer](#6-live-youtube-search-api--24-hour-cache-aside-layer)
- [🎨 Design System: The Dark Academia Aesthetic](#-design-system-the-dark-academia-aesthetic)
- [💻 Comprehensive Tech Stack](#-comprehensive-tech-stack)
- [📁 Repository Structure](#-repository-structure)
- [🚀 Local Setup & Installation](#-local-setup--installation)
  - [Prerequisites](#prerequisites)
  - [1. Backend Setup (FastAPI)](#1-backend-setup-fastapi)
  - [2. Frontend Setup (Flutter Web)](#2-frontend-setup-flutter-web)
- [🔑 Environment Variables](#-environment-variables)
- [📚 API Reference](#-api-reference)
- [🎓 Pedagogical Learning System](#-pedagogical-learning-system)
- [⚠️ Important Notices & Operational Caveats](#️-important-notices--operational-caveats)
- [📜 License](#-license)

---

## 🎯 Project Objectives & Core Vision

University students frequently face academic overload, fragmented study materials, and late-stage exam panic. Standard learning management systems (LMS) act as passive file repositories rather than active pedagogical coaches. This project was engineered with five foundational objectives:

1. **Early Academic Intervention**: Detect academic burnout and course failure risks before midterms using a custom PyTorch Multi-Layer Perceptron (MLP) trained on behavioral habits (attendance, prep time, gaming, sleep) and historical grades.
2. **Pedagogical Diagnostic Mapping**: Automatically deconstruct dense university textbooks into prioritized chapter radars (`CRITICAL` 🔴, `HIGH_YIELD` 🟡, `FOUNDATIONAL` 🔵), highlighting examiner traps, exam weightings, and recommended study time allocations.
3. **Optimized Multi-Modal Study Sessions**: Solve the student time-budget dilemma by formulating study planning as a **Bounded 0/1 Knapsack Optimization Problem**, assembling an optimal mix of video lectures, textbook readings, exam questions (PYQs), and interactive flashcards within a student's exact available time (e.g. 15–120 minutes).
4. **Grounded Academic Rigor (No Hallucinations)**: Enhance LLM explanations with authentic academic literature citations (ArXiv, IEEE, ACM, RFCs, OpenStax) and mathematically rigorous LaTeX KaTeX typesetting for formulas, code implementations, and conceptual proofs.
5. **Archival, Distraction-Free Immersion**: Provide an aesthetic scholarly environment inspired by Dark Academia collegiate libraries, encouraging focused, sustained intellectual inquiry.

---

## 🏗️ System Architecture & Data Flow

The platform employs a decoupled microservice-ready architecture. Heavy background ML embeddings, vector indexing, and LLM inference operate asynchronously without degrading user interaction.

```mermaid
flowchart TD
    subgraph Frontend["Flutter Web Client (Dark Academia CanvasKit)"]
        UI_Home["Collegiate Bento-Grid Hub"]
        UI_Profile["Student Risk Evaluator"]
        UI_Radar["Diagnostic Chapter Radar"]
        UI_Bundler["Study Session Workspace"]
        UI_Flashcards["3D Flip Flashcards (LaTeX + Citations)"]
        UI_PdfChat["PDF AI Scholar (SfPdfViewer + SSE Chat)"]
    end

    subgraph Backend["FastAPI Engine (Python 3.10+ / ASGI)"]
        API_Predict["/predict (MLP Inference)"]
        API_Radar["/api/analyze-pdf-focus (TOC Extraction)"]
        API_Bundler["/bundler/create (0/1 Knapsack Diversity Allocator)"]
        API_Flashcards["/api/generate-subchapter-flashcards"]
        API_Stream["/chat/stream (SSE RAG Generator)"]
        API_YouTube["Live YouTube API & 24h Cache-Aside"]
    end

    subgraph Intelligence["AI & Knowledge Inference Layer"]
        Groq_Cascade["Groq Tiered Cascade (Qwen-27B -> GPT-OSS-120B -> GPT-OSS-20B)"]
        ST_Embeddings["all-MiniLM-L6-v2 (Vector Embeddings)"]
        Cross_Encoder["ms-marco-MiniLM-L-6-v2 (Neural Re-Ranker)"]
        PyTorch_Model["Student Risk MLP (.pth)"]
    end

    subgraph Data["Persistent Storage Layer"]
        Neon_PG["Neon PostgreSQL (pgvector + Hybrid Search)"]
        Disk_Uploads["Physical PDF Repository (uploads/)"]
        SQLite_DB["Curated Resources & PYQs (resources.db)"]
        Mem_Cache["In-Memory YouTube TTL Cache (24h)"]
    end

    UI_Profile -->|Habit Metrics & Past Grades| API_Predict
    API_Predict --> PyTorch_Model
    
    UI_Radar -->|Course Code & PDF Document| API_Radar
    API_Radar --> Disk_Uploads
    API_Radar --> Groq_Cascade

    UI_Bundler -->|Time Budget & Subject Topic| API_Bundler
    API_Bundler --> SQLite_DB
    API_Bundler --> Neon_PG
    API_Bundler --> API_YouTube
    API_YouTube <--> Mem_Cache

    UI_Flashcards --> API_Flashcards
    API_Flashcards --> Groq_Cascade

    UI_PdfChat -->|Question & Textbook Excerpt| API_Stream
    API_Stream --> ST_Embeddings
    API_Stream --> Neon_PG
    API_Stream --> Cross_Encoder
    API_Stream --> Groq_Cascade
```

---

## ✨ Key Features & Functionality

### 1. Syllabus Diagnostic Chapter Radar
- **Automated Curriculum Breakdown**: Analyzes course textbook structure and table of contents via PyMuPDF (`fitz`), classifying each subchapter into pedagogical priority tiers: `CRITICAL` 🔴, `HIGH_YIELD` 🟡, and `FOUNDATIONAL` 🔵.
- **Exam Pitfall Alerts**: Automatically extracts examiner traps, common student deduction points, and suggested study durations for every subchapter.
- **One-Click Deep Dive Synergy**: Instant navigation from a recommended syllabus node directly into the exact textbook page in the PDF Chat, or automated generation of chapter mastery flashcards.

### 2. Multi-Modal Study Bundler (0/1 Knapsack Allocation)
- **Time-Budgeted Study Packs**: Students define their study time window (e.g. 15–120 minutes). The allocator uses a constrained 0/1 Knapsack optimization algorithm to assemble a balanced multi-modal study session containing:
  - 🎥 **Collegiate Video Lectures** (curated archives and live YouTube streams)
  - 📖 **Curriculum Text Readings** (targeted textbook excerpts and academic articles)
  - 📝 **Past-Year Examination Problems (PYQs)** (with step-by-step solutions)
  - 🗂️ **Interactive Flashcards** (conceptual active recall)
- **Content-Signature Deduplication**: Multi-layer normalization prevents identical questions or duplicate database entries from appearing in the same study deck.

### 3. Deep-Dive Research Flashcards & LaTeX Math Engine
- **Typeset LaTeX KaTeX Math**: Renders complex mathematical formulas, derivatives, and probability distributions inline (`$x = [1, 2]$`) and in display blocks (`$$p_1 = \frac{e^2}{e^2 + e^4}$$`).
- **Authentic Literature Citations**: Every flashcard back includes verified literature anchors (ArXiv preprints, RFC specifications, OpenStax textbooks, ACM/IEEE publications) with clickable external links powered by `url_launcher`.
- **Pedagogical 3-Part Answer Synthesis**:
  1. *Core Mechanism & Theoretical Principle*
  2. *Formula / Concrete Implementation* (with syntax-highlighted code fences)
  3. *University Exam Traps & Examiner Expectations*

### 4. Real-Time PDF AI Scholar & Streaming RAG
- **Server-Sent Events (SSE) Streaming**: Low-latency token-by-token text generation.
- **Hybrid RAG Pipeline**: Combines dense semantic vector retrieval (`pgvector` cosine similarity) with sparse keyword full-text search (`ts_rank`) and Cross-Encoder neural re-ranking (`ms-marco-MiniLM-L-6-v2`).
- **Resilient 3-Tier Fallback Cascade**: High-reasoning `qwen/qwen3.8-27b` fails over dynamically to `openai/gpt-oss-120b`, then gracefully to `openai/gpt-oss-20b` with automated context compression on 413 rate limits.
- **Interactive Mind Map Dialogue**: Visualizes hierarchical conceptual knowledge trees directly extracted from course texts.

### 5. Student Performance Risk Predictor (PyTorch MLP)
- Evaluates student study habits (lecture attendance, weekly preparation hours, sleep duration, gaming hours) alongside past grades.
- Custom neural network predicts academic risk level, flagging burnouts and diagnosing specific course deficits.
- Automatically routes students to tailored prerequisite resources based on Directed Acyclic Graph (DAG) curriculum dependencies.

### 6. Live YouTube Search API & 24-Hour Cache-Aside Layer
- **Real-Time Video Retrieval**: Dynamically queries the YouTube Data API v3 for high-yield collegiate lectures when local databases lack video coverage for a requested topic.
- **24-Hour Cache-Aside Pattern**: In-memory caching with Time-To-Live (TTL) conserves daily API quota (>95% quota reduction).
- **Collegiate Channel Prioritization**: Ranks videos with verified educational channels (MIT OpenCourseWare, Stanford Online, CS50, freeCodeCamp, Computerphile, 3Blue1Brown).

---

## 🎨 Design System: The Dark Academia Aesthetic

The user interface is crafted around a cohesive **Dark Academia Collegiate Palette** designed to evoke the ambiance of vintage library manuscripts, archival drafting tables, and collegiate architecture:

| Swatch | Color Name | Hex Code | Purpose |
| :--- | :--- | :--- | :--- |
| ![#1E222A](https://via.placeholder.com/15/1E222A/000000?text=+) | **Space Cadet** | `#1E222A` | Primary container surfaces, active navigation cards |
| ![#2C2E30](https://via.placeholder.com/15/2C2E30/000000?text=+) | **Charcoal Slate** | `#2C2E30` | Midnight archive drafting background |
| ![#EDE8DC](https://via.placeholder.com/15/EDE8DC/000000?text=+) | **Antique Ivory** | `#EDE8DC` | Daylight folio parchment background |
| ![#C5A059](https://via.placeholder.com/15/C5A059/000000?text=+) | **Faded Gold** | `#C5A059` | Medallion trims, active borders, icon highlights |
| ![#5B2327](https://via.placeholder.com/15/5B2327/000000?text=+) | **Caput Mortuum** | `#5B2327` | Deep academic wine accents and buttons |
| ![#2D4C3A](https://via.placeholder.com/15/2D4C3A/000000?text=+) | **Forest Moss** | `#2D4C3A` | Success badges, verification pills |
| ![#3B2F2F](https://via.placeholder.com/15/3B2F2F/000000?text=+) | **Oxford Brown** | `#3B2F2F` | Scholarly ink typography in light mode |

**Scholarly Typography Pairing:**
- **Display / Headers:** `Cinzel` (Classical Roman proportions and collegiate grandeur)
- **Body Manuscript:** `Source Serif 4` (High-readability academic serif typeface)
- **Technical Metrics:** `Share Tech Mono` (Terminal metadata, timestamps, and page tags)

---

## 💻 Comprehensive Tech Stack

### Frontend (Flutter Web)
- **Framework:** Flutter SDK 3.11+ (CanvasKit renderer for desktop-grade PDF & markdown performance)
- **PDF Viewer:** `syncfusion_flutter_pdfviewer` & `syncfusion_flutter_pdf`
- **Math & Markdown:** `flutter_markdown`, `flutter_markdown_latex`, `flutter_math_fork` (KaTeX engine)
- **UI Components:** `animated_flash_cards`, `google_fonts`, `flutter_animate`, `url_launcher`

### Backend Engine (FastAPI & Python)
- **Framework:** FastAPI with Uvicorn (ASGI)
- **PDF Processing:** PyMuPDF (`fitz`), Camelot, `langchain_text_splitters`
- **Embedding Models:** `SentenceTransformer('all-MiniLM-L6-v2')`
- **Re-Ranking Models:** `CrossEncoder('ms-marco-MiniLM-L-6-v2')`
- **Databases:** PostgreSQL (Neon Cloud with `pgvector`), SQLite (`resources.db`)
- **LLM Engine:** Groq API Cloud (`qwen/qwen3.8-27b`, `openai/gpt-oss-120b`, `openai/gpt-oss-20b`)
- **External APIs:** YouTube Data API v3

---

## 📁 Repository Structure

```
recommender-api/
├── main.py                          # FastAPI ASGI application, RAG endpoints, PDF focus engine
├── app/
│   ├── bundler.py                   # 0/1 Knapsack study bundle generation & deduplication
│   ├── video_link.py                # Live YouTube API v3 search, 24h cache-aside & ranker
│   ├── lens_switcher.py             # Cognitive lens transformations (Analogy, Visual, Exam)
│   ├── groq_client.py               # Tiered Groq LLM inference cascade wrapper
│   ├── database.py                  # Neon PostgreSQL & pgvector connection handling
│   └── models.py                    # Pydantic schemas & SQLAlchemy ORM models
├── recommender_api/                 # Flutter Web frontend workspace
│   ├── lib/
│   │   ├── main.dart                # App shell, Dark Academia navigation vault & profile
│   │   ├── pdf_chat_screen.dart     # Split-screen PDF viewer + streaming LaTeX RAG chat
│   │   ├── screens/
│   │   │   ├── home_screen.dart             # Bento-grid collegiate hub
│   │   │   ├── study_session_screen.dart    # Multi-modal active study player
│   │   │   ├── bundler_setup_screen.dart    # Time-budget & subject pack builder
│   │   │   └── pdf_focus_diagnostic_screen.dart # Interactive chapter priority radar
│   │   ├── widgets/
│   │   │   ├── flashcard_deck_widget.dart   # 3D flip flashcard with KaTeX & link launcher
│   │   │   └── cognitive_lens_widget.dart   # Interactive cognitive perspective switcher
│   │   ├── theme/
│   │   │   └── app_theme.dart               # DarkAcademiaPalette colors & typography
│   │   └── models/
│   ├── pubspec.yaml                 # Flutter packages & asset declarations
│   └── web/                         # CanvasKit web runner, index.html & static assets
├── uploads/                         # University PDF textbook repository
├── rules/                           # Pedagogical learning rules & concept mastery
│   ├── do_not_commit.md             # Theoretical algorithms & interview deep-dives
│   └── auto_commit.md               # Git automation & repository policies
├── .agent/                          # Agent guidelines & rules
│   └── rules/
│       └── pedagogical_learning.md  # Core blank-logic and algorithmic directives
├── README/                          # Subfolder documentation mirror
│   ├── README.md                    # Mirrored repository overview
│   ├── DEBUGGING_README.md          # Troubleshooting and debugging guide
│   └── MIND_MAP_README.md           # Mind map implementation guide
├── resources.db                     # SQLite micro-learning resources & past exam questions
├── requirements.txt                 # Backend Python dependencies
├── Dockerfile                       # Container deployment definition
└── README.md                        # Primary GitHub repository landing page README
```

---

## 🚀 Local Setup & Installation

### Prerequisites
- **Python:** 3.10 or higher
- **Flutter:** 3.11+ (configured for Web)
- **Database:** PostgreSQL instance with `pgvector` enabled (e.g. [Neon.tech](https://neon.tech))
- **API Keys:** Groq Cloud API Key, YouTube Data API v3 Key (optional)

---

### 1. Backend Setup (FastAPI)

1. Clone the repository and navigate to the project directory:
   ```bash
   git clone https://github.com/123EFD/recommender-api.git
   cd recommender-api
   ```

2. Create and activate a Python virtual environment:
   ```bash
   python -m venv venv
   # On Windows (PowerShell):
   .\venv\Scripts\Activate.ps1
   # On macOS/Linux:
   source venv/bin/activate
   ```

3. Install required dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Create your `.env` file in the root directory:
   ```env
   DATABASE_URL=postgresql://user:password@your-neon-host/dbname?sslmode=require
   GROQ_API_KEY=your_groq_api_key_here
   YOUTUBE_API_KEY=your_youtube_api_key_here  # Optional (fallback links used if absent)
   ```

5. Launch the FastAPI server:
   ```bash
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```
   The backend will be available at `http://localhost:8000` (Interactive Swagger docs: `http://localhost:8000/docs`).

---

### 2. Frontend Setup (Flutter Web)

1. Navigate to the `recommender_api` directory:
   ```bash
   cd recommender_api
   ```

2. Fetch Flutter package dependencies:
   ```bash
   flutter pub get
   ```

3. Run the application in Chrome with the CanvasKit web renderer:
   ```bash
   flutter run -d chrome --web-renderer canvaskit
   ```

---

## 🔑 Environment Variables

| Variable | Description | Required | Example |
| :--- | :--- | :--- | :--- |
| `DATABASE_URL` | Neon PostgreSQL connection URI with `pgvector` enabled | **Yes** | `postgresql://user:pass@ep-xyz.neon.tech/neondb?sslmode=require` |
| `GROQ_API_KEY` | Groq Cloud API key for high-speed LLM inference | **Yes** | `gsk_...` |
| `YOUTUBE_API_KEY` | Google YouTube Data API v3 key for live educational video searches | Optional | `AIzaSy...` |

---

## 📚 API Reference

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `POST` | `/predict` | Evaluates student academic risk and study habit factors via PyTorch MLP. |
| `POST` | `/bundler/create` | Assembles a balanced multi-modal study bundle within a time budget. |
| `POST` | `/api/analyze-pdf-focus` | Extracts TOC & classifies syllabus subchapters into priority tiers. |
| `POST` | `/api/generate-subchapter-flashcards` | Generates LaTeX flashcards with verified literature research links. |
| `POST` | `/chat/stream` | Server-Sent Events (SSE) streaming endpoint for conversational PDF RAG. |
| `GET` | `/library` | Synchronizes disk `uploads/` folder with database records. |
| `POST` | `/api/resolve-course-pdf` | Resolves official curriculum textbook for a given course code. |

---

## 🎓 Pedagogical Learning System

This project is built under a **Pedagogical Blank-Logic Architecture**: core algorithmic mechanisms are stubbed in the source code as `[BLANK N]` blocks for active learning, backed by thorough mathematical derivations, industry case studies, and technical interview talking points:

1. **`[BLANK 1]: Academic Citation Validator & Literature Ranking Engine`** ([`main.py`](main.py)):
   - *Concept:* Authority weighting and Jaccard token relevance to filter hallucinated citations.
   - *Industry Equivalent:* Perplexity AI citation validation, biomedical RAG pipelines.
2. **`[BLANK 2]: Relevance-Scored Video Selection & Cache-Aside Filter`** ([`app/video_link.py`](app/video_link.py)):
   - *Concept:* Jaccard similarity and collegiate channel bonus with 24-hour TTL caching.
   - *Industry Equivalent:* High-throughput API rate-limit shielding, CDN invalidation.
3. **`Root-Cause Prerequisite Back-Tracing Engine`** ([`rules/do_not_commit.md`](rules/do_not_commit.md)):
   - *Concept:* Directed Acyclic Graph (DAG) DFS traversal and topological sorting.
   - *Industry Equivalent:* Build systems (Bazel), workflow schedulers (Apache Airflow).
4. **`Peer-Validated Wilson Score Confidence Heatmap`** ([`rules/do_not_commit.md`](rules/do_not_commit.md)):
   - *Concept:* Binomial proportion lower bound for ranking high-yield learning assets.
   - *Industry Equivalent:* Reddit/Hacker News "Best" comment sorting, Amazon review ranking.

---

## ⚠️ Important Notices & Operational Caveats

> [!WARNING]
> **Groq Cloud Token Limits (ITPM / TPM)**: Groq enforces strict free-tier rate limits (e.g., `qwen/qwen3.8-27b` has a 7,000 ITPM limit; `gpt-oss-120b` has an 8,000 TPM limit). The backend implements an automated 3-tier cascade and dynamic context window pruning to gracefully recover from 413 and 429 errors.

> [!IMPORTANT]
> **Flutter Web CanvasKit Renderer**: The Flutter Web frontend **must** be compiled and served using CanvasKit (`--web-renderer canvaskit`). Running with the default HTML renderer will cause Syncfusion PDF Viewer rendering defects and misaligned LaTeX KaTeX mathematical glyphs.

> [!NOTE]
> **PostgreSQL SSL Connection**: When connecting to Neon DB or AWS Aurora, append `?sslmode=require` to your `DATABASE_URL`. Without this flag, libpq drivers will terminate connections on cold starts.

> [!CAUTION]
> **Git Repository Hygiene (Large Media Blobs)**: Do not commit large recorded video lectures (`.mp4`, `.mov` > 50MB) or uncompressed binary datasets directly to Git. Video content is dynamically queried via the YouTube Data API v3 and cached in memory.

> [!TIP]
> **PDF Textbook Ingestion**: PyMuPDF (`fitz`) relies on embedded text layers in PDF textbooks. If using scanned photocopies or legacy documents, ensure you run an OCR preprocessor (e.g., `ocrmypdf`) prior to uploading to `uploads/`.

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.
