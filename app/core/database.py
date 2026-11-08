import sqlite3
import psycopg
from app.core.config import DATABASE_URL

def get_db_connection():
    """Returns a connection to the Neon PostgreSQL database."""
    if DATABASE_URL is None:
        raise ValueError("DATABASE_URL environment variable is not set")
    return psycopg.connect(DATABASE_URL)

def get_sqlite_connection(db_path: str = "resources.db") -> sqlite3.Connection:
    """Returns a connection to the local SQLite database."""
    return sqlite3.connect(db_path)

def init_chat_db():
    """Initializes the chat_messages table in PostgreSQL."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS chat_messages (
                        id SERIAL PRIMARY KEY,
                        filename TEXT NOT NULL,
                        role TEXT NOT NULL,
                        message_text TEXT NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )        
                """)
            conn.commit()
            print("Chat history table initialized successfully.")
    except Exception as e:
        print(f"Error initializing chat history table: {e}")

def init_jobs_db():
    """Initializes the pdf_jobs table in PostgreSQL."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as curr:
                curr.execute("""
                    CREATE TABLE IF NOT EXISTS pdf_jobs (
                        filename TEXT PRIMARY KEY,
                        status TEXT NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )    
                """)
            conn.commit()
            print("PDF jobs table initialized successfully.")
    except Exception as e:
        print(f"Error initializing pdf jobs table: {e}")

def init_quiz_db():
    """Initializes the student_quiz_logs table in PostgreSQL."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as curr:
                curr.execute("""
                    CREATE TABLE IF NOT EXISTS student_quiz_logs (
                        id SERIAL PRIMARY KEY,
                        topic_name TEXT NOT NULL,
                        is_successful BOOLEAN NOT NULL,
                        baseline_grade FLOAT NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                """)
            conn.commit()
            print("Student quiz logs table initialized successfully.")
    except Exception as e:
        print(f"Error initializing student quiz logs table: {e}")

def init_all_databases():
    """Initializes all required database tables gracefully."""
    init_chat_db()
    init_jobs_db()
    init_quiz_db()
