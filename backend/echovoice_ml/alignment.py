"""Edit-distance phoneme alignment.

Mirrors the semantics of `PhonemeAligner` in the Flutter app
(lib/services/asr_pipeline.dart) so server-side scoring and on-device
scoring produce identical results for identical inputs.

Operation types:
    "match"        -- predicted[i] aligns with target[j], symbols equal
    "substitution" -- predicted[i] aligns with target[j], symbols differ
    "deletion"     -- predicted symbol has no counterpart in the target
    "insertion"    -- target symbol has no counterpart in the prediction
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import List, Literal, Optional, Tuple

OpType = Literal["match", "substitution", "insertion", "deletion"]


@dataclass(frozen=True)
class AlignmentOp:
    predicted_index: Optional[int]
    target_index: int
    op_type: OpType

    def to_dict(self) -> dict:
        return {
            "predicted_index": self.predicted_index,
            "target_index": self.target_index,
            "op_type": self.op_type,
        }


def align(predicted: List[str], target: List[str]) -> List[AlignmentOp]:
    """Aligns `predicted` against `target` using Levenshtein backtracking.

    Raises ValueError if `target` is empty. An empty `predicted` list is a
    legitimate outcome (the child said nothing intelligible) and yields one
    insertion op per target phoneme.
    """
    if not target:
        raise ValueError("Cannot align against an empty target phoneme sequence.")

    if not predicted:
        return [
            AlignmentOp(predicted_index=None, target_index=j, op_type="insertion")
            for j in range(len(target))
        ]

    m, n = len(predicted), len(target)
    # dp[i][j] = edit distance between predicted[:i] and target[:j]
    dp: List[List[int]] = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(m + 1):
        dp[i][0] = i
    for j in range(n + 1):
        dp[0][j] = j

    for i in range(1, m + 1):
        for j in range(1, n + 1):
            cost = 0 if predicted[i - 1] == target[j - 1] else 1
            dp[i][j] = min(
                dp[i - 1][j] + 1,          # delete predicted[i-1]
                dp[i][j - 1] + 1,          # insert target[j-1]
                dp[i - 1][j - 1] + cost,   # match / substitute
            )

    ops: List[AlignmentOp] = []
    i, j = m, n
    while i > 0 or j > 0:
        if i > 0 and j > 0 and dp[i][j] == dp[i - 1][j - 1] + (0 if predicted[i - 1] == target[j - 1] else 1):
            ops.append(
                AlignmentOp(
                    predicted_index=i - 1,
                    target_index=j - 1,
                    op_type="match" if predicted[i - 1] == target[j - 1] else "substitution",
                )
            )
            i -= 1
            j -= 1
        elif i > 0 and dp[i][j] == dp[i - 1][j] + 1:
            ops.append(AlignmentOp(predicted_index=i - 1, target_index=j, op_type="deletion"))
            i -= 1
        else:
            ops.append(AlignmentOp(predicted_index=None, target_index=j - 1, op_type="insertion"))
            j -= 1

    ops.reverse()
    return ops


def to_dicts(ops: List[AlignmentOp]) -> List[dict]:
    return [op.to_dict() for op in ops]
