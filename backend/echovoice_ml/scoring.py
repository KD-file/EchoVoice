"""Scoring functions computed over an alignment.

Mirrors `PronunciationScorer` in the Flutter app. A target phoneme's
`difficulty_weight` (from the PHONEME_TARGET entity) can weight the accuracy
so harder phonemes contribute proportionally more to the final score.
"""

from __future__ import annotations

from typing import Dict, List, Sequence

from .alignment import AlignmentOp


def accuracy_score(ops: Sequence[AlignmentOp]) -> float:
    """Fraction of aligned positions that were matches.

    Raises ValueError for an empty alignment (a caller/data error).
    """
    if not ops:
        raise ValueError("computeAccuracyScore received an empty alignment.")
    matches = sum(1 for op in ops if op.op_type == "match")
    return matches / len(ops)


def phoneme_error_rate(ops: Sequence[AlignmentOp]) -> float:
    """Fraction of aligned positions that were errors (1 - accuracy)."""
    if not ops:
        raise ValueError("computePhonemeErrorRate received an empty alignment.")
    errors = sum(1 for op in ops if op.op_type != "match")
    return errors / len(ops)


def score_alignment(
    ops: Sequence[AlignmentOp],
    difficulty_weights: List[float] | None = None,
) -> Dict[str, float]:
    """Full scoring bundle for an alignment.

    Args:
        ops: aligned operations (see alignment.align).
        difficulty_weights: optional per-target weights aligned by target
            position (mirrors PhonemeTarget.difficultyWeight). Defaults to
            equal weights (1.0 per target).

    Returns:
        {"accuracy": ..., "phoneme_error_rate": ..., "weighted_accuracy": ...}
    """
    if not ops:
        raise ValueError("score_alignment requires a non-empty alignment.")

    if difficulty_weights is None:
        difficulty_weights = []

    total_weight = 0.0
    earned_weight = 0.0
    for op in ops:
        w = 1.0
        if op.target_index is not None and 0 <= op.target_index < len(difficulty_weights):
            w = float(difficulty_weights[op.target_index])
        total_weight += w
        if op.op_type == "match":
            earned_weight += w

    weighted = earned_weight / total_weight if total_weight > 0 else 0.0
    return {
        "accuracy": accuracy_score(ops),
        "phoneme_error_rate": phoneme_error_rate(ops),
        "weighted_accuracy": round(weighted, 6),
    }
