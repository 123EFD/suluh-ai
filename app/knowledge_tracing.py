from typing import List, Dict, Any, Optional

# ==============================================================================
# [BLANK 5a]: Bayesian Knowledge Tracing (BKT) Posterior Mastery Update
# Task: Update a student's latent mastery probability P(L_t) for a specific CS
# concept after observing their response (correct or incorrect) on a flashcard/quiz.
#
# Standard BKT Model Parameters:
#   P(L_{t-1}) : Prior probability that the student already mastered the concept
#   P(G)       : Guess probability (answered correctly by chance without knowing)
#   P(S)       : Slip probability (made a careless mistake despite knowing)
#   P(T)       : Transition probability (learned the concept during this practice attempt)
#
# Mathematical Derivation:
# 1. Observation Update (Bayes' Theorem):
#    If is_correct == True:
#        P(L_{t-1} | Obs=1) = [ P(L_{t-1}) * (1 - P(S)) ] / [ P(L_{t-1}) * (1 - P(S)) + (1 - P(L_{t-1})) * P(G) ]
#    If is_correct == False:
#        P(L_{t-1} | Obs=0) = [ P(L_{t-1}) * P(S) ] / [ P(L_{t-1}) * P(S) + (1 - P(L_{t-1})) * (1 - P(G)) ]
#
# 2. Learning Transition:
#    P(L_t) = P(L_{t-1} | Obs) + (1 - P(L_{t-1} | Obs)) * P(T)
#
# Input:
#   prior_mastery: float - Prior belief in [0.0, 1.0]
#   is_correct: bool - Whether student answered correctly
#   p_transit: float - Learning transition rate (default 0.15)
#   p_guess: float - Guess rate (default 0.20)
#   p_slip: float - Slip rate (default 0.10)
#
# Output:
#   float - Updated posterior mastery probability P(L_t) in [0.0, 1.0]
# ==============================================================================
def update_bkt_mastery(
    prior_mastery: float,
    is_correct: bool,
    p_transit: float = 0.15,
    p_guess: float = 0.20,
    p_slip: float = 0.10
) -> float:
    """
    Computes updated knowledge mastery probability using Bayesian Knowledge Tracing.
    
    TODO:
    1. Clamp prior_mastery to range [0.001, 0.999] to prevent zero division.
    2. Compute p_obs_given_known: (1 - p_slip) if is_correct else p_slip.
    3. Compute p_obs_given_unknown: p_guess if is_correct else (1 - p_guess).
    4. Compute posterior p_learned_given_obs via Bayes' rule:
         numerator = prior_mastery * p_obs_given_known
         denominator = numerator + (1 - prior_mastery) * p_obs_given_unknown
         p_learned_given_obs = numerator / denominator
    5. Compute new mastery with transition:
         p_learned_given_obs + (1 - p_learned_given_obs) * p_transit
    6. Return result rounded or clamped to [0.0, 1.0].
    """
    # [LEARNER IMPLEMENTATION REQUIRED - DO NOT WRITE WORKING LOGIC HERE]
    return prior_mastery


# ==============================================================================
# [BLANK 5b]: BKT Next-Trial Performance Probability Prediction
# Task: Given current knowledge state P(L_t), calculate the predicted probability
# that the student will answer the NEXT upcoming question on this topic correctly.
#
# Formula:
#   P(Correct_{t+1}) = P(L_t) * (1 - P(S)) + (1 - P(L_t)) * P(G)
#
# Input:
#   mastery: float - Current latent mastery probability P(L_t)
#   p_guess: float - Guess probability (default 0.20)
#   p_slip: float - Slip probability (default 0.10)
#
# Output:
#   float - Probability in [0.0, 1.0]
# ==============================================================================
def predict_next_correct_probability(
    mastery: float, 
    p_guess: float = 0.20, 
    p_slip: float = 0.10
) -> float:
    """
    Predicts probability of correctly answering the next assessment item.
    
    TODO:
    1. Calculate P(Correct) = mastery * (1 - p_slip) + (1 - mastery) * p_guess.
    2. Return clamped value in [0.0, 1.0].
    """
    # [LEARNER IMPLEMENTATION REQUIRED - DO NOT WRITE WORKING LOGIC HERE]
    return 0.5


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
