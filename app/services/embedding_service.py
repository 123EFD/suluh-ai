from typing import Optional, TYPE_CHECKING

if TYPE_CHECKING:
    from sentence_transformers import SentenceTransformer, CrossEncoder

_embedder: Optional[object] = None
_cross_encoder: Optional[object] = None

def get_embedder():
    """Lazy-load and return the SentenceTransformer embedding model."""
    global _embedder
    if _embedder is None:
        print("Loading PDF Embedding Model (all-MiniLM-L6-v2)...")
        from sentence_transformers import SentenceTransformer
        _embedder = SentenceTransformer('all-MiniLM-L6-v2')
        print("PDF Embedding Engine Ready!")
    return _embedder

def get_cross_encoder():
    """Lazy-load and return the CrossEncoder re-ranking model."""
    global _cross_encoder
    if _cross_encoder is None:
        print("Loading CrossEncoder Model (ms-marco-MiniLM-L-6-v2)...")
        from sentence_transformers import CrossEncoder
        _cross_encoder = CrossEncoder('cross-encoder/ms-marco-MiniLM-L-6-v2')
        print("CrossEncoder Engine Ready!")
    return _cross_encoder
