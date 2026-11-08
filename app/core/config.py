import os
from dotenv import load_dotenv
from app.curriculum import COURSE_MAPPING, PREREQUISITE_GRAPH

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
YOUTUBE_API_KEY = os.getenv("YOUTUBE_API_KEY")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
HF_TOKEN = os.getenv("HF_TOKEN")

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Verified academic and open repository textbook mapping for UM curriculum
OPEN_COURSE_PDF_REPOSITORY = {
    "WIG3005": {
        "title": "Practical Game Programming with Allegro",
        "filename": "Wang_Ridgewell_2026-Practical-Game-Programming.pdf",
        "url": "https://doi.org/10.15215/remix/9781998944224.01"
    },
    "WIA1006": {
        "title": "The Hundred-page Machine Learning",
        "filename": "The Hundred-page Machine Learning.pdf",
        "url": "https://github.com/HandsOnLLM/Hands-On-Large-Language-Models"
    },
    "WIX1002": {
        "title": "Code like a Pro in C",
        "filename": "Code like a Pro in C (Jort Rodenburg) (z-library.sk, 1lib.sk, z-lib.sk).pdf",
        "url": "https://1lib.sk/book/code-like-a-pro-in-c"
    },
    "WIA2001": {
        "title": "Database Systems & Data Modeling",
        "filename": "Data Model (3).pdf",
        "url": "https://www.cl.cam.ac.uk/teaching/1617/Databases/materials.html"
    },
    "WIX1001": {
        "title": "Discrete Mathematics & Computing Math",
        "filename": "DiscMathII.pdf",
        "url": "https://www.cl.cam.ac.uk/teaching/1213/DiscMathII/DiscMathII.pdf"
    },
    "WIA1005": {
        "title": "Computer Networking Foundations",
        "filename": "Topic01-Foundation.pdf",
        "url": "https://www.cl.cam.ac.uk/teaching/2122/CompNet/files/Topic01-Foundation.pdf"
    },
    "WIA2004": {
        "title": "Operating Systems & File Systems",
        "filename": "File System (2).pdf",
        "url": "https://pages.cs.wisc.edu/~remzi/OSTEP/file-intro.pdf"
    },
    "WIF3001": {
        "title": "Software Testing Techniques",
        "filename": "Testing.pdf",
        "url": "https://mrcet.com/downloads/digital_notes/ME/III+year/Software+Testing+Techniques.pdf"
    },
    "WIF3009": {
        "title": "Fundamentals of Deep Learning",
        "filename": "Fundamentals of deep learning.pdf",
        "url": "https://www.oreilly.com/library/view/fundamentals-of-deep/9781491925607/"
    },
    "WIA2003": {
        "title": "Probability and Statistics for Computer Science",
        "filename": "Probability_and_Statistics_CS.pdf",
        "url": "https://projects.iq.harvard.edu/files/stat110/files/probability_cheatsheet.pdf"
    },
    "WIA2005": {
        "title": "Algorithms Design and Analysis",
        "filename": "Algorithms-JeffE.pdf",
        "url": "https://jeffe.cs.illinois.edu/teaching/algorithms/book/Algorithms-JeffE.pdf"
    },
    "WIA1003": {
        "title": "Computer System Architecture",
        "filename": "SysOrgNotes.pdf",
        "url": "https://www.cl.cam.ac.uk/teaching/0910/CompSys/SysOrgNotes.pdf"
    },
    "WIA2002": {
        "title": "Software Modeling and Engineering",
        "filename": "SoftwareEngineering-IanSommerville.pdf",
        "url": "https://www.comp.nus.edu.sg/~cs2103/AY1920S1/files/SoftwareEngineering-IanSommerville.pdf"
    },
    "WIF2003": {
        "title": "Eloquent Web Programming",
        "filename": "Eloquent_JavaScript.pdf",
        "url": "https://eloquentjavascript.net/Eloquent_JavaScript.pdf"
    }
}

TRUSTED_ACADEMIC_DOMAINS = {
    "arxiv.org": 1.0,
    "ietf.org": 0.95,
    "rfc-editor.org": 0.95,
    "openstax.org": 0.90,
    "acm.org": 0.95,
    "ieee.org": 0.95,
    "semanticscholar.org": 0.85,
    "wikipedia.org": 0.75,
}

CURATED_LITERATURE_REGISTRY = {
    "WIA1005": [
        {"title": "RFC 793: Transmission Control Protocol Specification", "url": "https://www.rfc-editor.org/rfc/rfc793", "domain": "IETF/RFC", "reason": "Official standard defining TCP state machines and 3-way handshakes."},
        {"title": "RFC 5681: TCP Congestion Control (Reno, Fast Retransmit)", "url": "https://www.rfc-editor.org/rfc/rfc5681", "domain": "IETF/RFC", "reason": "Standard algorithm for slow start, congestion avoidance, and fast recovery."},
        {"title": "Computer Networks: A Systems Approach (Peterson & Davie)", "url": "https://book.systemsapproach.org/", "domain": "Academic Book", "reason": "Authoritative open-access textbook on networking layering and protocols."}
    ],
    "WIA1002": [
        {"title": "OpenStax: Advanced Data Structures & Algorithm Analysis", "url": "https://openstax.org/", "domain": "OpenStax", "reason": "Comprehensive university textbook covering amortized complexity and balanced trees."},
        {"title": "Tarjan (1985): Amortized Computational Complexity", "url": "https://epubs.siam.org/doi/10.1137/0606031", "domain": "SIAM/Academic", "reason": "Foundational paper introducing potential methods for dynamic arrays and splay trees."}
    ],
    "WIA2004": [
        {"title": "Operating Systems: Three Easy Pieces (Arpaci-Dusseau)", "url": "https://pages.cs.wisc.edu/~remzi/OSTEP/", "domain": "Academic Book", "reason": "Gold-standard university textbook on virtualization, concurrency, and persistence."},
        {"title": "Dijkstra (1965): Solution of a Problem in Concurrent Programming", "url": "https://www.cs.utexas.edu/users/EWD/ewd01xx/EWD123.PDF", "domain": "Classic Paper", "reason": "Original seminal paper defining the mutual exclusion problem and semaphores."}
    ]
}
