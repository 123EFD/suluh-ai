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
    """Initializes the student_quiz_logs table in PostgreSQL and SQLite fallback."""
    # 1. PostgreSQL (Neon) initialization
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
            print("Student quiz logs table initialized successfully in PostgreSQL.")
    except Exception as e:
        print(f"Notice: PostgreSQL quiz logs init skipped or failed: {e}")

    # 2. Local SQLite fallback initialization and benchmark seeding
    try:
        with get_sqlite_connection() as conn:
            cur = conn.cursor()
            cur.execute("""
                CREATE TABLE IF NOT EXISTS student_quiz_logs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    topic_name TEXT NOT NULL,
                    is_successful BOOLEAN NOT NULL,
                    baseline_grade REAL NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            cur.execute("""
                CREATE INDEX IF NOT EXISTS idx_quiz_logs_topic ON student_quiz_logs(topic_name)
            """)
            conn.commit()

            # Seed realistic benchmark data if table is currently empty
            row_count = cur.execute("SELECT COUNT(*) FROM student_quiz_logs").fetchone()[0]
            if row_count == 0:
                sample_benchmarks = [
                    ("Pointers in C", 42, 55, 2.3),
                    ("Memory Allocation & Heap", 38, 50, 2.1),
                    ("Graph Theory & DFS/BFS", 65, 80, 2.5),
                    ("Database Normalization & BCNF", 48, 62, 2.4),
                    ("TCP/IP 3-Way Handshake", 55, 68, 2.7),
                    ("Dynamic Programming & Knapsack", 34, 48, 2.0),
                    ("Virtual Memory & Paging", 40, 52, 2.2),
                    ("Cache Coherence & Invalidation", 28, 40, 2.6),
                ]
                for topic, successes, total, grade in sample_benchmarks:
                    for _ in range(successes):
                        cur.execute(
                            "INSERT INTO student_quiz_logs (topic_name, is_successful, baseline_grade) VALUES (?, 1, ?)",
                            (topic, grade)
                        )
                    for _ in range(total - successes):
                        cur.execute(
                            "INSERT INTO student_quiz_logs (topic_name, is_successful, baseline_grade) VALUES (?, 0, ?)",
                            (topic, grade)
                        )
                conn.commit()
                print("Seeded baseline benchmark student quiz logs in SQLite resources.db.")
            print("Student quiz logs table initialized successfully in SQLite.")
    except Exception as e:
        print(f"Error initializing SQLite student quiz logs table: {e}")

def init_all_databases():
    """Initializes all required database tables gracefully."""
    init_chat_db()
    init_jobs_db()
    init_quiz_db()
