import os
import re
import pymupdf as fitz
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from app.core.config import GROQ_API_KEY, UPLOAD_FOLDER
from app.core.database import get_db_connection
from app.models.schemas import ChatRequest, MessageRequest
from app.services.llm_service import (
    get_groq_client,
    question_cache,
    generate_cache_key,
    optimize_search_query
)
from app.services.embedding_service import get_embedder, get_cross_encoder
from app.services.pdf_service import extract_direct_page_texts

router = APIRouter(tags=["AI Chat & Retrieval"])

@router.post("/chat")
def ask_pdf_question(request: ChatRequest):
    """Hybrid RAG pipeline combining pgvector semantic search, tsvector keyword search, and CrossEncoder re-ranking."""
    if not GROQ_API_KEY:
        raise HTTPException(status_code=500, detail="GROQ API Key is missing.")
    
    cache_key = generate_cache_key(request.filename, request.question)
    if cache_key in question_cache:
        print("⚡ Cache hit! Returning instant answer.")
        def cached_stream():
            yield question_cache[cache_key]
        return StreamingResponse(cached_stream(), media_type="text/plain")
    
    client = get_groq_client()
    if not client:
        raise HTTPException(status_code=500, detail="Groq client unavailable.")
        
    try:
        # 1. Query optimization
        optimized_query = optimize_search_query(client, request.question)
        print(f"Original: {request.question} | Optimized: {optimized_query}")
        
        # 2. Embedding generation
        embedder = get_embedder()
        question_vector = str(embedder.encode(optimized_query).tolist())
        
        # 3. Hybrid pgvector + tsvector retrieval with local fallback
        retrieved_text = ""
        chat_history_payload = []
        rows = []
        file_path = os.path.join(UPLOAD_FOLDER, request.filename)
        safe_tsquery = re.sub(r'[^\w\s]', ' ', optimized_query).strip() or optimized_query

        try:
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        SELECT role, message_text 
                        FROM chat_messages 
                        WHERE filename = %s 
                        ORDER BY id DESC 
                        LIMIT 4
                        """,
                        (request.filename,)
                    )
                    past_messages = cur.fetchall()
                    for row in reversed(past_messages):
                        db_role = row[0] 
                        llm_role = "assistant" if db_role == "ai" else "user" 
                        chat_history_payload.append({"role": llm_role, "content": row[1]})
                    
                    cur.execute(
                        """
                        SELECT chunk_text 
                        FROM document_chunks
                        WHERE document_name = %s
                        ORDER BY 
                            ((1.0 - (embedding <=> %s::vector)) * 0.7) 
                            + 
                            (ts_rank(to_tsvector('english', chunk_text), plainto_tsquery('english', %s)) * 0.3)
                        DESC
                        LIMIT 30 
                        """,
                        (request.filename, question_vector, safe_tsquery)
                    )
                    rows = cur.fetchall()
        except Exception as db_err:
            print(f"Notice: Remote vector DB retrieval skipped/failed ({db_err}). Falling back to local semantic reader.")
            rows = []

        # Fallback to local PDF semantic search if DB returned 0 chunks
        if not rows and os.path.exists(file_path):
            try:
                with fitz.open(file_path) as doc:
                    candidate_chunks = []
                    for page_idx, page in enumerate(doc):
                        page_text = page.get_text("text").strip()
                        if not page_text:
                            continue
                        paragraphs = [p.strip() for p in page_text.split("\n\n") if len(p.strip()) > 30]
                        if not paragraphs:
                            paragraphs = [page_text]
                        for para in paragraphs:
                            candidate_chunks.append(f"[Page {page_idx + 1}]\n{para}")
                    
                    if candidate_chunks:
                        chunk_embeddings = embedder.encode(candidate_chunks[:60])
                        q_emb = embedder.encode(optimized_query)
                        sims = [
                            float((chunk_embeddings[i] @ q_emb) / (
                                (chunk_embeddings[i] @ chunk_embeddings[i])**0.5 * (q_emb @ q_emb)**0.5 + 1e-9
                            ))
                            for i in range(len(chunk_embeddings))
                        ]
                        ranked_indices = sorted(range(len(sims)), key=lambda k: sims[k], reverse=True)[:30]
                        rows = [(candidate_chunks[idx],) for idx in ranked_indices]
            except Exception as pdf_err:
                print(f"Local PDF semantic extraction error: {pdf_err}")

        # 4. Cross-Encoder Re-Ranking & Semantic Coalescing
        if rows:
            cross_encoder = get_cross_encoder()
            candidate_texts = [row[0] for row in rows]
            sentence_pairs = [[optimized_query, t] for t in candidate_texts]
            scores = cross_encoder.predict(sentence_pairs)
            scored_results = list(zip(scores, candidate_texts))
            scored_results.sort(key=lambda x: x[0], reverse=True)
            top_results = scored_results[:12]

            # Coalesce overlapping/duplicate excerpts and maintain semantic boundary continuity
            coalesced_excerpts = []
            seen_texts = set()
            for score, chunk_text in top_results:
                clean_chunk = chunk_text.strip()
                if not clean_chunk or any(clean_chunk in s for s in seen_texts):
                    continue
                seen_texts.add(clean_chunk)
                coalesced_excerpts.append(clean_chunk)

            for i, chunk_text in enumerate(coalesced_excerpts):
                retrieved_text += f"\n--- Excerpt {i+1} ---\n{chunk_text}\n"

        # 5. Direct Page Range Extraction
        direct_page_texts = extract_direct_page_texts(file_path, request.question)
        if direct_page_texts:
            retrieved_text = "\n\n".join(direct_page_texts) + "\n\n" + retrieved_text

        # 6. Token Budget Guard (12,000 characters)
        if len(retrieved_text) > 12000:
            retrieved_text = retrieved_text[:12000] + "\n\n... [Remaining excerpt condensed to fit rate limit token budget] ..."

        # 7. Final Prompt Assembly
        final_prompt = f"""         
        Thinks as an educational AI assistant helping Malaysian student, especially those studying Computer Science related subjects.
        Your goal is to provide precise, comprehensive, and highly accurate answers to the student's question.
        
        CRITICAL CONTEXT:
        The student is currently asking questions about the document named: '{request.filename}'.
        Whenever they ask "this book" or "this document", they are referring to '{request.filename}'.
        
        RULES:
        1. Base your factual information STRICTLY on the Context Excerpts provided below.
        2. If the user asks for a recommendation, you ARE allowed to provide subjective, expert advice. 
            Base your recommendation on general Information Technology or any related industry principles (e.g., practical application vs. theoretical value).
            Give examples as well which related to current Malaysia well-known companies or startups to make it more relevant to the student's future career.
        3. Do not say "I do not possess personal opinions." You must confidently advise the student.
        4. Synthesize the information logically using clear headings and bullet points.
        5. State explicitly if specific answers cannot be found in the context excerpts.
        6. CRITICAL MARKDOWN TABLE FORMATTING RULES:
           - NEVER include multi-line code blocks (```) or unescaped newlines inside table cells.
           - Inside table cells, ONLY use concise text or short inline code (`int x = 0;`) with <br> for line breaks.
           - If you provide code examples, pseudocode, or multi-line algorithms, place them OUTSIDE of the table under clear subheadings so the markdown table syntax does not break.
        7. CRITICAL LATEX MATHEMATICAL FORMATTING RULES:
           - Use standard single dollar signs for inline math: $formula$, and double dollar signs for display math: $$formula$$.
           - NEVER nest dollar signs inside other dollar signs or inside parentheses with spaces like "( $x$ )". Always write "($x$, where $V$ is the vocabulary size)".
           - Inside LaTeX text blocks, NEVER use dollar signs.
           - Ensure every opening dollar sign has a matching closing dollar sign.
        
        Context Excerpts:
        {retrieved_text}
        
        Student's Question: {request.question}
        
        Answer:
        """
        
        messages_payload = chat_history_payload + [{"role": "user", "content": final_prompt}]
        
        def generate_stream():
            full_answer = ""
            try:
                stream = None
                models_to_try = ["qwen/qwen3.8-27b", "openai/gpt-oss-120b", "openai/gpt-oss-20b"]
                current_payload = messages_payload
                
                for idx, model_name in enumerate(models_to_try):
                    try:
                        stream = client.chat.completions.create(
                            model=model_name,
                            messages=current_payload,
                            max_tokens=2048,
                            stream=True
                        )
                        break
                    except Exception as model_err:
                        print(f"Model {model_name} failed: {model_err}")
                        err_str = str(model_err).lower()
                        if "413" in err_str or "rate_limit" in err_str or "too large" in err_str or "tokens" in err_str:
                            trimmed_prompt = final_prompt[:6000] + f"\n\n[Excerpt condensed for rate limit]\n\nStudent's Question: {request.question}\n\nAnswer:"
                            current_payload = chat_history_payload[-2:] + [{"role": "user", "content": trimmed_prompt}]
                        if idx == len(models_to_try) - 1:
                            raise model_err
                
                for chunk in stream:
                    if chunk.choices and len(chunk.choices) > 0:
                        delta = chunk.choices[0].delta
                        if delta and delta.content is not None:
                            text_chunk = delta.content
                            full_answer += text_chunk
                            yield text_chunk

                if full_answer:
                    question_cache[cache_key] = full_answer
                    try:
                        with get_db_connection() as conn:
                            with conn.cursor() as db_cur:
                                db_cur.execute(
                                    "INSERT INTO chat_messages (filename, role, message_text) VALUES (%s, %s, %s)",
                                    (request.filename, "ai", full_answer)
                                )
                            conn.commit()
                    except Exception as db_err:
                        print(f"Database Error: {db_err}")

            except Exception as stream_err:
                print(f"Streaming Generator Error in ASGI: {stream_err}")
                yield f"\n\n⚠️ AI Error: {str(stream_err)}"
                
        return StreamingResponse(generate_stream(), media_type="text/plain")
    except Exception as e:
        print(f"Chat Error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to generate answer: {str(e)}")

@router.post("/save-message")
def save_message(req: MessageRequest):
    """Saves a user or AI message into PostgreSQL chat history."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO chat_messages (filename, role, message_text) 
                    VALUES (%s, %s, %s)
                    """,
                    (req.filename, req.role, req.text)
                )
            conn.commit()
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/get-chat/{filename}")
def get_chat(filename: str):
    """Fetches the chronological chat message list for a specific document."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT role, message_text FROM chat_messages WHERE filename = %s ORDER BY id ASC",
                    (filename,)
                )
                rows = cur.fetchall()
                return [{"role": row[0], "text": row[1]} for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/clear-chat/{filename}")
def clear_chat_history(filename: str):
    """Deletes all conversational records for the specified PDF."""
    try:
        with get_db_connection() as conn: 
            with conn.cursor() as cur:
                cur.execute("DELETE FROM chat_messages WHERE filename = %s", (filename,))
            conn.commit()
        return {"status": "success", "message": f"Cleared chat history for {filename}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
