import re
from typing import List, Dict, Tuple, Set

def detect_and_break_graph_cycles(edges: List[Tuple[str, str]]) -> List[Tuple[str, str]]:
    if not edges: return []
    graph: Dict[str, List[str]] = {}
    #Maintain color dict: 0 = unvisited, 1 = visiting, 2 = visited.
    color: Dict[str, int] = {}

    for u, v in edges:
        if u not in graph:
            graph[u] = []
        if v not in graph:
            graph[v] = []
        graph[u].append(v)
        color[u] = 0
        color[v] = 0
    
    back_edges: Set[Tuple[str, str]] = set()
    
    #DFS helper 
    def dfs(node : str) -> None:
        color[node] = 1 
        for neighbor in graph.get(node, []):
            if color[neighbor] == 1:
                back_edges.add((node, neighbor))  # Cycle detected
            elif color[neighbor] == 0:
                dfs(neighbor) #unvisited then traverse deeper explored 
        color[node] = 2  
        #outer loop: handle all disconnected components of the graph
    for node in list(graph.keys()): 
        if color[node] == 0:
            dfs(node)
    
    #filter out detected back-edges while preserving original order of edges
    return [edge for edge in edges if edge not in back_edges]

def sanitize_mermaid_syntax(mermaid_code: str) -> str:
    """
    Cleans raw LLM Mermaid text to prevent rendering errors in client canvases.
    Ensures safe node quoting and valid header.
    """
    lines = mermaid_code.strip().split('\n')
    cleaned_lines = []
    
    header_found = False
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("```"):
            continue
        if stripped.startswith("graph ") or stripped.startswith("flowchart "):
            header_found = True
            cleaned_lines.append(stripped)
            continue
        
        # Protect special characters inside node labels by wrapping with double quotes
        # e.g., A[Intro (Basics)] -> A["Intro (Basics)"]
        sanitized_line = re.sub(r'\[([^"\]]+[\(\)\{\}\:\/][^"\]]*)\]', r'["\1"]', stripped)
        cleaned_lines.append(sanitized_line)
        
    if not header_found:
        cleaned_lines.insert(0, "graph TD")
        
    return "\n".join(cleaned_lines)
