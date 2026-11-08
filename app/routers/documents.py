import os
from fastapi import APIRouter, HTTPException, UploadFile, File, BackgroundTasks
from fastapi.responses import FileResponse
import httpx
import pymupdf as fitz
from langchain_text_splitters import RecursiveCharacterTextSplitter
from app.core.database import get_db_connection
from app.core.config import UPLOAD_FOLDER
from app.models.schemas import RenameRequest
from app.services.embedding_service import get_embedder

router = APIRouter(tags=["Document Management"])

def process_pdf_in_background(filename: str):
    """Background worker task to parse, chunk, and embed an uploaded PDF."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("UPDATE pdf_jobs SET status = 'processing' WHERE filename = %s", (filename,))
            conn.commit()
            
        import worker
        print(f"Starting background PDF processing for: {filename}...")
        is_success = worker.process_pdf(filename)
        final_status = 'completed' if is_success else 'failed'
        
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE pdf_jobs SET status = %s WHERE filename = %s",
                    (final_status, filename)
                )
            conn.commit()
        print(f"🏁 Background task finished {filename}: {final_status}")
    except Exception as e:
        print(f"Background task error for {filename}: {e}")
        try:
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        "UPDATE pdf_jobs SET status = 'failed' WHERE filename = %s",
                        (filename,)
                    )
                conn.commit()
        except Exception:
            pass

@router.post("/upload-pdf")
async def process_and_store_pdf(background_tasks: BackgroundTasks, file: UploadFile = File(...)):
    """Receives an uploaded PDF file, saves it to disk, and queues background processing."""
    if not file.filename:
        raise HTTPException(status_code=400, detail="Filename is required.")
    
    safe_filename = os.path.basename(file.filename)
    file_path = os.path.join(UPLOAD_FOLDER, safe_filename)
    
    try:
        with open(file_path, "wb") as f:
            f.write(await file.read())
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to save temp file: {str(e)}")
    
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO pdf_jobs (filename, status) 
                    VALUES (%s, %s) 
                    ON CONFLICT (filename)
                    DO UPDATE SET status = 'pending', created_at = CURRENT_TIMESTAMP
                    """,
                    (safe_filename, 'pending')
                )
            conn.commit()        
        
        background_tasks.add_task(process_pdf_in_background, safe_filename)

        return {
            "message": "Upload received. Processing in background.",
            "filename": safe_filename,
            "status": "pending"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to queue PDF for processing: {str(e)}")

@router.post("/analyze-pdf-url")
async def process_pdf_from_url(request: dict):
    """Downloads a PDF from a direct URL, chunks it, embeds it, and stores chunks in Neon."""
    url = request.get("url")
    if not url:
        raise HTTPException(status_code=400, detail="URL is required.")
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(url)
            if response.status_code != 200:
                raise HTTPException(status_code=400, detail="Could not download PDF from URL")
            
            file_bytes = response.content
            doc = fitz.open(stream=file_bytes, filetype="pdf")

            full_text = ""
            for page in doc:
                full_text += str(page.get_text())
                
            if not full_text.strip():
                raise HTTPException(status_code=400, detail="No text extracted from PDF")
            
            text_splitter = RecursiveCharacterTextSplitter(
                chunk_size=500, 
                chunk_overlap=50,
                separators=["\n\n", "\n", ".", " ", ""]
            )
            chunks = text_splitter.split_text(full_text)
            
            embedder = get_embedder()
            embeddings = embedder.encode(chunks)
            
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    for i, chunk_text in enumerate(chunks):
                        vector_string = str(embeddings[i].tolist())
                        cur.execute(
                            """
                            INSERT INTO document_chunks (document_name, chunk_text, embedding) 
                            VALUES (%s, %s, %s)
                            """,
                            (url, chunk_text, vector_string)
                        )
                conn.commit()
                
            return {
                "message": "Success",
                "chunks_processed": len(chunks)
            }
    except Exception as e:
        error_msg = str(e)
        print(f"Analyze PDF URL Error: {error_msg}")
        if "429" in error_msg or "RESOURCE_EXHAUSTED" in error_msg:
            raise HTTPException(status_code=429, detail="Groq API rate limit exceeded. Please wait 30 seconds and try again later.")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/get-pdf/{filename}")
def get_pdf(filename: str):
    """Serves the requested PDF file from uploads directory."""
    file_path = os.path.join(UPLOAD_FOLDER, filename)
    if os.path.exists(file_path):
        return FileResponse(file_path, media_type="application/pdf")
    raise HTTPException(status_code=404, detail="File not found.")

@router.get("/job-status/{filename}")
def get_job_status(filename: str):
    """Checks the background ingestion status for a given PDF."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT status FROM pdf_jobs WHERE filename = %s", (filename,))
                row = cur.fetchone()
                if row: 
                    return {"filename": filename, "status": row[0]}
                return {"status": "not found"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/library")
def get_pdf_library():
    """Returns the deduplicated list of physically available PDFs verified against Neon."""
    try:
        disk_files = []
        if os.path.exists(UPLOAD_FOLDER):
            disk_files = [
                f for f in os.listdir(UPLOAD_FOLDER)
                if f.lower().endswith(".pdf") and os.path.isfile(os.path.join(UPLOAD_FOLDER, f))
            ]

        db_files = []
        try:
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT filename FROM pdf_jobs ORDER BY created_at DESC")
                    rows = cur.fetchall()
                    db_files = [row[0] for row in rows]

                    for df in disk_files:
                        if df not in db_files:
                            try:
                                cur.execute(
                                    "INSERT INTO pdf_jobs (filename, status) VALUES (%s, %s) ON CONFLICT DO NOTHING",
                                    (df, "completed")
                                )
                            except Exception:
                                pass
                    conn.commit()
        except Exception as db_err:
            print(f"Database query error in /library: {db_err}")

        disk_set = set(disk_files)
        valid_library = []
        seen = set()

        for f in db_files:
            if f in disk_set and f not in seen:
                valid_library.append(f)
                seen.add(f)

        for f in sorted(disk_files, key=lambda s: s.lower()):
            if f not in seen:
                valid_library.append(f)
                seen.add(f)

        return valid_library
    except Exception as e:
        print(f"Error in get_pdf_library: {e}")
        if os.path.exists(UPLOAD_FOLDER):
            return [f for f in os.listdir(UPLOAD_FOLDER) if f.lower().endswith(".pdf")]
        return []

@router.put("/rename-pdf")
def rename_pdf(req: RenameRequest):
    """Renames an uploaded PDF across file system and all database tables."""
    try:
        new_name = req.new_filename if req.new_filename.endswith('.pdf') else req.new_filename + '.pdf'
        
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("UPDATE document_chunks SET document_name = %s WHERE document_name = %s", (new_name, req.old_filename))
                cur.execute("UPDATE chat_messages SET filename = %s WHERE filename = %s", (new_name, req.old_filename))
                cur.execute("UPDATE pdf_jobs SET filename = %s WHERE filename = %s", (new_name, req.old_filename))
            conn.commit()
            
        old_path = os.path.join(UPLOAD_FOLDER, req.old_filename)
        new_path = os.path.join(UPLOAD_FOLDER, new_name)
        if os.path.exists(old_path):
            os.rename(old_path, new_path)
            
        return {"status": "success", "message": f"Renamed {req.old_filename} to {new_name}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/delete-pdf/{filename}")
def delete_pdf(filename: str):
    """Purges a PDF document from disk and cleans associated vectors and chat records."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM document_chunks WHERE document_name = %s", (filename,))
                cur.execute("DELETE FROM chat_messages WHERE filename = %s", (filename,))
                cur.execute("DELETE FROM pdf_jobs WHERE filename = %s", (filename,))
            conn.commit()
            
        file_path = os.path.join(UPLOAD_FOLDER, filename)
        if os.path.exists(file_path):
            os.remove(file_path)
            
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
