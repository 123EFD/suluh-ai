# ==============================================================================
# Canonical Curriculum & Topic Taxonomy Mapping
# Ensures zero cross-topic contamination across all subject dropdowns & DAG lookups
# ==============================================================================

COURSE_MAPPING = {
    # Faculty Core
    "WIX1001": "Computing Mathematics I",
    "WIX1002": "Fundamentals of Programming",
    "WIX1003": "Computer Systems and Organization",
    "WIX2001": "Thinking and Communication Skills",
    "WIX2002": "Project Management",
    
    # Programme Core
    "WIA1002": "Data Structure",
    "WIA1003": "Computer System Architecture",
    "WIA1005": "Network Technology Foundation",
    "WIA1006": "Machine Learning",
    "WIA2001": "Database",
    "WIA2002": "Software Modeling",
    "WIA2003": "Probability and Statistics",
    "WIA2004": "Operating Systems",
    "WIA2005": "Algorithm Design and Analysis",
    "WIA2007": "Mobile Application Development",
    "WIA2010": "Human Computer Interaction",
    "WIA3001": "Industrial Training",
    "WIA3002": "Academic Project I",
    "WIA3003": "Academic Project II",
    
    # Specialization Electives
    "WIF2002": "Software Requirements Engineering",
    "WIF2003": "Web Programming",
    "WIF3001": "Software Testing",
    "WIF3002": "Software Process and Quality",
    "WIF3004": "Software Architecture and Design Paradigms",
    "WIF3005": "Software Maintenance and Evolution",
    "WIF3006": "Component Based Software Engineering",
    "WIF3008": "Real Time Systems",
    "WIF3009": "Python for Scientific Computing",
    "WIF3010": "Programming Language Paradigm",
    "WIF3011": "Concurrent and Parallel Programming",
    "WIG3005": "Game Development",
    "WIC2008": "Internet of Things",
    "WIA2006": "System Analysis and Design"
}

# Directed Acyclic Graph (DAG) for Prerequisite Traversal
PREREQUISITE_GRAPH = {
    "WIA1002": ["WIX1002"],             # Data Structure -> Fundamentals of Programming
    "WIA1003": ["WIX1003"],             # Architecture -> Systems & Org
    "WIA1005": ["WIA1003"],             # Computer Networks -> Computer Architecture / Systems
    "WIA2005": ["WIA1002"],             # Algorithm Design -> Data Structure
    "WIA3003": ["WIA3002"],             # Project II -> Project I
    "WIF3004": ["WIA2002", "WIF2002"],  # Software Arch -> Modeling & Req Eng
    "WIF3006": ["WIA2002"],             # Component Based SE -> Software Modeling
    "WIF3011": ["WIX1002", "WIA2004"],  # Concurrent Programming -> Programming & OS
    "WIC2008": ["WIA1005"],             # IoT -> Network Tech
    "WIA1006": ["WIA2003", "WIF3009"],  # Machine Learning -> Prob&Stats, Python
    "WIA2004": ["WIX1003", "WIA1003"],  # OS -> Systems & Org, Architecture
    "WIF2003": ["WIA1002", "WIA2006"],  # Web Programming / Database -> Data Structure, System Analysis
    "WIA2001": ["WIA1002"],             # Database -> Data Structure
}

# Canonical taxonomy mapping every user dropdown / search term to:
# 1. Primary Course Code
# 2. Whitelisted Database Topic Tags in SQLite (Strict isolation)
# 3. Positive Domain Keywords (must match at least one)
# 4. Negative Prohibited Keywords (reject cross-domain contamination)
TOPIC_TAXONOMY = {
    "computer network": {
        "course_code": "WIA1005",
        "canonical_name": "Computer Networks",
        "allowed_sqlite_topics": ["Computer Networks", "Networking"],
        "keywords": [
            "network", "tcp", "ip", "osi", "protocol", "router", "switch", "packet", "socket",
            "subnet", "dns", "http", "ethernet", "fddi", "lan", "wan", "routing", "bandwidth",
            "transport layer", "data link", "transmission", "wireshark", "port", "payload", "icmp",
            "arp", "mac address", "crc", "checksum", "cable", "bps", "bit stuffing"
        ],
        "negative_keywords": [
            "solid principle", "interface segregation", "dynamic programming", "sql", "normalization",
            "coin flip", "probability of getting", "foreign key", "relational database"
        ]
    },
    "computer networks": {
        "course_code": "WIA1005",
        "canonical_name": "Computer Networks",
        "allowed_sqlite_topics": ["Computer Networks", "Networking"],
        "keywords": [
            "network", "tcp", "ip", "osi", "protocol", "router", "switch", "packet", "socket",
            "subnet", "dns", "http", "ethernet", "fddi", "lan", "wan", "routing", "bandwidth",
            "transport layer", "data link", "transmission", "wireshark", "port", "payload", "icmp",
            "arp", "mac address", "crc", "checksum", "cable", "bps", "bit stuffing"
        ],
        "negative_keywords": [
            "solid principle", "interface segregation", "dynamic programming", "sql", "normalization",
            "coin flip", "probability of getting", "foreign key", "relational database"
        ]
    },
    "networking": {
        "course_code": "WIA1005",
        "canonical_name": "Computer Networks",
        "allowed_sqlite_topics": ["Computer Networks", "Networking"],
        "keywords": ["network", "tcp", "ip", "osi", "protocol", "router", "switch", "packet", "socket", "subnet", "dns", "http", "ethernet"],
        "negative_keywords": ["solid principle", "interface segregation", "dynamic programming", "sql", "normalization"]
    },
    "database": {
        "course_code": "WIA2001",
        "canonical_name": "Database Systems",
        "allowed_sqlite_topics": [
            "Database", "Database Systems", "Database and SQL",
            "C++ Databases", "Python Databases", "Java Databases", "Rust Databases",
            "Kotlin Databases", "Swift Databases", "Go Databases", "JavaScript Databases"
        ],
        "keywords": [
            "database", "sql", "table", "query", "relation", "schema", "acid", "index",
            "normalization", "foreign key", "primary key", "join", "transaction", "3nf", "bcnf",
            "relational", "select", "rdbms", "dml", "ddl", "entity", "er diagram"
        ],
        "negative_keywords": [
            "cache line", "cache write policy", "osi layer", "router", "dynamic programming", "sliding window"
        ]
    },
    "database systems": {
        "course_code": "WIA2001",
        "canonical_name": "Database Systems",
        "allowed_sqlite_topics": [
            "Database", "Database Systems", "Database and SQL",
            "C++ Databases", "Python Databases", "Java Databases", "Rust Databases",
            "Kotlin Databases", "Swift Databases", "Go Databases", "JavaScript Databases"
        ],
        "keywords": ["database", "sql", "table", "query", "relation", "schema", "acid", "index", "normalization", "rdbms"],
        "negative_keywords": ["cache line", "cache write policy", "osi layer", "router", "dynamic programming"]
    },
    "normalization": {
        "course_code": "WIA2001",
        "canonical_name": "Database Normalization",
        "allowed_sqlite_topics": [
            "Database", "Database Systems", "Database and SQL",
            "C++ Databases", "Python Databases", "Java Databases", "Rust Databases",
            "Kotlin Databases", "Swift Databases", "Go Databases", "JavaScript Databases"
        ],
        "keywords": ["normalization", "1nf", "2nf", "3nf", "bcnf", "dependency", "functional dependency", "database", "key", "redundancy", "anomaly", "decomposition"],
        "negative_keywords": ["cache line", "cache write policy", "osi", "router", "dynamic programming"]
    },
    "algorithms": {
        "course_code": "WIA2005",
        "canonical_name": "Algorithm Design and Analysis",
        "allowed_sqlite_topics": [
            "Algorithms", "Graph Theory", "Theory of Computation",
            "C++ Dynamic Programming", "Python Dynamic Programming", "Java Dynamic Programming", "Rust Dynamic Programming",
            "Kotlin Dynamic Programming", "Swift Dynamic Programming", "Go Dynamic Programming", "JavaScript Dynamic Programming",
            "C++ Graph Theory", "Python Graph Theory", "Java Graph Theory", "Rust Graph Theory",
            "Kotlin Graph Theory", "Swift Graph Theory", "Go Graph Theory", "JavaScript Graph Theory",
            "C++ Sorting Algorithms", "Python Sorting Algorithms", "Java Sorting Algorithms", "Rust Sorting Algorithms",
            "Kotlin Sorting Algorithms", "Swift Sorting Algorithms", "Go Sorting Algorithms", "JavaScript Sorting Algorithms"
        ],
        "keywords": [
            "algorithm", "complexity", "big-o", "sort", "search", "graph", "dynamic programming",
            "greedy", "divide and conquer", "dijkstra", "knapsack", "tree", "shortest path",
            "memoization", "quicksort", "mergesort", "asymptotic", "recurrence"
        ],
        "negative_keywords": [
            "sql", "osi layer", "packet transmission", "tcp", "foreign key", "relational database"
        ]
    },
    "graph theory": {
        "course_code": "WIA2005",
        "canonical_name": "Graph Theory",
        "allowed_sqlite_topics": [
            "Algorithms", "Graph Theory",
            "C++ Graph Theory", "Python Graph Theory", "Java Graph Theory", "Rust Graph Theory",
            "Kotlin Graph Theory", "Swift Graph Theory", "Go Graph Theory", "JavaScript Graph Theory"
        ],
        "keywords": ["graph", "vertex", "vertices", "edge", "directed", "acyclic", "dag", "bfs", "dfs", "cycle", "tree", "dijkstra", "euler", "hamilton", "topological"],
        "negative_keywords": ["sql", "osi layer", "packet transmission", "tcp", "foreign key"]
    },
    "data structures": {
        "course_code": "WIA1002",
        "canonical_name": "Data Structures",
        "allowed_sqlite_topics": [
            "Data Structures",
            "C++ Data Structures", "Python Data Structures", "Java Data Structures", "Rust Data Structures",
            "Kotlin Data Structures", "Swift Data Structures", "Go Data Structures", "JavaScript Data Structures",
            "C++ Recursion", "Python Recursion", "Java Recursion", "Rust Recursion",
            "Kotlin Recursion", "Swift Recursion", "Go Recursion", "JavaScript Recursion"
        ],
        "keywords": [
            "data structure", "array", "linked list", "stack", "queue", "binary tree", "bst", "heap",
            "hash table", "hash map", "trie", "node", "recursion", "traversal", "inorder", "preorder"
        ],
        "negative_keywords": [
            "sql", "osi layer", "router", "probability of getting", "foreign key"
        ]
    },
    "data structure": {
        "course_code": "WIA1002",
        "canonical_name": "Data Structures",
        "allowed_sqlite_topics": [
            "Data Structures",
            "C++ Data Structures", "Python Data Structures", "Java Data Structures", "Rust Data Structures",
            "Kotlin Data Structures", "Swift Data Structures", "Go Data Structures", "JavaScript Data Structures",
            "C++ Recursion", "Python Recursion", "Java Recursion", "Rust Recursion",
            "Kotlin Recursion", "Swift Recursion", "Go Recursion", "JavaScript Recursion"
        ],
        "keywords": ["data structure", "array", "linked list", "stack", "queue", "binary tree", "bst", "heap", "hash table", "node", "recursion"],
        "negative_keywords": ["sql", "osi layer", "router", "probability of getting", "foreign key"]
    },
    "pointers in c": {
        "course_code": "WIX1002",
        "canonical_name": "Pointers in C / Memory",
        "allowed_sqlite_topics": [
            "Data Structures", "Programming", "Low-level Systems",
            "C++ Data Structures", "C++ OOP Concepts", "C++ Recursion"
        ],
        "keywords": ["pointer", "memory", "address", "dereference", "malloc", "free", "segmentation", "heap", "stack", "c language"],
        "negative_keywords": ["sql", "osi", "router", "foreign key"]
    },
    "operating systems": {
        "course_code": "WIA2004",
        "canonical_name": "Operating Systems",
        "allowed_sqlite_topics": ["Operating Systems", "Low-level Systems", "Embedded Systems", "Computer Architecture"],
        "keywords": [
            "operating system", "process", "thread", "scheduling", "deadlock", "concurrency", "mutex",
            "semaphore", "virtual memory", "paging", "file system", "kernel", "interrupt", "syscall",
            "context switch", "mmu", "page replacement", "cpu scheduling", "fread", "write"
        ],
        "negative_keywords": [
            "probability of getting", "coin flip", "sql", "osi layer", "solid principle"
        ]
    },
    "memory allocation": {
        "course_code": "WIA2004",
        "canonical_name": "Memory Allocation & Management",
        "allowed_sqlite_topics": ["Operating Systems", "Low-level Systems", "Computer Architecture"],
        "keywords": ["memory", "allocation", "paging", "segmentation", "virtual memory", "mmu", "heap", "stack", "fragmentation", "page replacement", "tlb", "malloc"],
        "negative_keywords": ["probability of getting", "coin flip", "sql", "osi layer"]
    },
    "machine learning": {
        "course_code": "WIA1006",
        "canonical_name": "Machine Learning",
        "allowed_sqlite_topics": [
            "Machine Learning", "Artificial Intelligence", "Data Science",
            "C++ Machine Learning", "Python Machine Learning", "Java Machine Learning", "Rust Machine Learning",
            "Kotlin Machine Learning", "Swift Machine Learning", "Go Machine Learning", "JavaScript Machine Learning"
        ],
        "keywords": [
            "machine learning", "model", "training", "supervised", "unsupervised", "neural network",
            "regression", "classification", "loss", "gradient", "overfitting", "feature", "epoch", "dataset"
        ],
        "negative_keywords": ["osi layer", "router", "sql normalization", "cable links"]
    },
    "backpropagation": {
        "course_code": "WIA1006",
        "canonical_name": "Backpropagation & Deep Learning",
        "allowed_sqlite_topics": [
            "Machine Learning", "Artificial Intelligence", "Data Science",
            "Python Machine Learning", "Java Machine Learning"
        ],
        "keywords": ["backpropagation", "gradient descent", "chain rule", "loss", "weights", "bias", "neural network", "activation", "learning rate"],
        "negative_keywords": ["osi layer", "router", "sql normalization"]
    },
    "data science": {
        "course_code": "WIA1006",
        "canonical_name": "Data Science",
        "allowed_sqlite_topics": ["Data Science", "Machine Learning", "Python Machine Learning"],
        "keywords": ["data science", "statistics", "dataset", "pandas", "visualization", "hypothesis", "variance", "distribution", "correlation"],
        "negative_keywords": ["osi layer", "router", "sliding window"]
    },
    "software engineering": {
        "course_code": "WIF2002",
        "canonical_name": "Software Engineering",
        "allowed_sqlite_topics": ["Software Engineering", "Software Testing", "DevOps", "Version Control", "System Design"],
        "keywords": ["software engineering", "sdlc", "agile", "scrum", "requirements", "design pattern", "uml", "testing", "unit test", "ci/cd", "refactoring", "git", "solid"],
        "negative_keywords": ["osi layer", "router", "cable links", "ip address"]
    },
    "general programming": {
        "course_code": "WIX1002",
        "canonical_name": "Fundamentals of Programming",
        "allowed_sqlite_topics": [
            "Programming", "General Programming", "Object-Oriented Programming", "Languages and Frameworks",
            "C++ OOP Concepts", "Java OOP Concepts", "Python OOP Concepts", "Rust OOP Concepts",
            "Kotlin OOP Concepts", "Swift OOP Concepts", "Go OOP Concepts", "JavaScript OOP Concepts"
        ],
        "keywords": ["programming", "function", "variable", "loop", "class", "object", "inheritance", "polymorphism", "encapsulation", "oop", "compiler", "syntax"],
        "negative_keywords": ["osi layer", "router", "cable links"]
    },
    "discrete mathematics": {
        "course_code": "WIX1001",
        "canonical_name": "Computing Mathematics",
        "allowed_sqlite_topics": ["Discrete Mathematics"],
        "keywords": ["discrete math", "logic", "propositional", "predicate", "set theory", "proof", "induction", "relation", "boolean algebra", "combinatorics"],
        "negative_keywords": ["osi layer", "router", "cable links", "sql table"]
    },
    "computing mathematics": {
        "course_code": "WIX1001",
        "canonical_name": "Computing Mathematics",
        "allowed_sqlite_topics": ["Discrete Mathematics"],
        "keywords": ["mathematics", "logic", "truth table", "set", "relation", "function", "matrix", "combinatorics", "probability"],
        "negative_keywords": ["osi layer", "router", "cable links"]
    }
}

def resolve_topic_metadata(topic: str | None) -> dict:
    """
    Resolves any user topic string to canonical taxonomy metadata.
    Handles case, singular/plural, and substrings gracefully.
    """
    if not topic or not topic.strip():
        return {
            "course_code": "WIX1002",
            "canonical_name": "General Programming",
            "allowed_sqlite_topics": ["Programming", "Data Structures", "Algorithms"],
            "keywords": ["programming", "algorithm", "data structure"],
            "negative_keywords": ["osi layer", "router"]
        }

    norm = topic.strip().lower()

    # 1. Exact or alias match
    if norm in TOPIC_TAXONOMY:
        return TOPIC_TAXONOMY[norm]

    # 2. Singularize / strip trailing 's'
    if norm.endswith("s") and norm[:-1] in TOPIC_TAXONOMY:
        return TOPIC_TAXONOMY[norm[:-1]]

    # 3. Substring match against taxonomy keys
    for k, meta in TOPIC_TAXONOMY.items():
        if k in norm or norm in k:
            return meta

    # 4. Fallback check against official COURSE_MAPPING
    for code, title in COURSE_MAPPING.items():
        if norm in code.lower() or norm in title.lower() or title.lower() in norm:
            for meta in TOPIC_TAXONOMY.values():
                if meta["course_code"] == code:
                    return meta
            return {
                "course_code": code,
                "canonical_name": title,
                "allowed_sqlite_topics": [title],
                "keywords": [w.lower() for w in title.split() if len(w) > 3],
                "negative_keywords": []
            }

    # 5. Default safe return scoped strictly to Computer Science foundations (NEVER General CS trivia)
    return {
        "course_code": "WIX1002",
        "canonical_name": topic.title(),
        "allowed_sqlite_topics": ["Programming", "Data Structures"],
        "keywords": [w for w in norm.split() if len(w) > 3],
        "negative_keywords": []
    }
