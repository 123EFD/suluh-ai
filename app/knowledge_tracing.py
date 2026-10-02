from typing import List, Dict, Any, Optional

def update_bkt_mastery(
    prior_mastery: float,
    is_correct: bool,
    p_transit: float = 0.15,
    p_guess: float = 0.20,
    p_slip: float = 0.10
) -> float:
    prior_mastery = max(0.001, min(prior_mastery, 0.999))
    p_obs_given_known = (1 - p_slip) if is_correct else p_slip
    p_obs_given_unknown = p_guess if is_correct else (1 - p_guess)
    numerator = prior_mastery * p_obs_given_known
    denominator = numerator + (1 - prior_mastery) * p_obs_given_unknown 
    p_learned_given_obs = numerator / denominator
    posterior_mastery = p_learned_given_obs + (1 - p_learned_given_obs) * p_transit
    return max(0.0, min(posterior_mastery, 1.0))        

def predict_next_correct_probability(
    mastery: float, 
    p_guess: float = 0.20, 
    p_slip: float = 0.10
) -> float:
    p_correct = mastery * (1 - p_slip) + (1 - mastery) * p_guess
    return max(0.0, min(p_correct, 1.0))

def trace_mastery_trajectory(
    responses: List[bool], 
    initial_prior: float = 0.10
) -> List[float]:
    """Traces a student's sequential mastery trajectory across a session."""
    trajectory = []
    current_mastery = initial_prior
    for resp in responses:
        current_mastery = update_bkt_mastery(current_mastery, resp)
        trajectory.append(round(current_mastery, 4))
    return trajectory
