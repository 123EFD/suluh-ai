import math
from typing import List, Dict, Any, Optional

def calculate_wilson_score_lower_bound(positives: int, total: int, z: float = 1.96) -> float:
    if total <= 0:
        return 0.0

    p_hat = positives / total
    deno = 1 + (z ** 2 / total)
    center = p_hat + (z ** 2 / (2 * total))
    spread = z * math.sqrt((p_hat * (1 - p_hat) / total) + (z**2 / (4 * total**2)))
    lower_bound = (center - spread) / deno
    return max(0.0, lower_bound)

def rank_resources_by_wilson_score(
    resources: List[Dict[str, Any]], 
    quiz_metrics: Dict[str, Dict[str, int]]
) -> List[Dict[str, Any]]:
    for resource in resources:
        topic = resource.get("topic", "")
        metrics = quiz_metrics.get(topic, {"positives": 0, "total": 0})
        score = calculate_wilson_score_lower_bound(metrics["positives"], metrics["total"])
        resource["wilson_score"] = score
    resources.sort(key=lambda x: x["wilson_score"], reverse=True)
    return resources
