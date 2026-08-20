"""Offline evaluation: PER, accuracy, and a per-phoneme confusion report."""

from __future__ import annotations

import json
from collections import Counter
from pathlib import Path
from typing import Dict, List

import numpy as np
import torch
from torch.utils.data import DataLoader

from .alignment import align
from .phoneme_map import PhonemeMap
from .trainer import PhonemeDataset, ctc_collate, greedy_from_logits


def evaluate_predictions(
    model,  # AcousticModel
    features: np.ndarray,
    labels: List[List[int]],
    phoneme_map: PhonemeMap,
    batch_size: int = 16,
    device: str = "cpu",
) -> Dict:
    """Runs greedy decoding over a prepared corpus and reports metrics.

    Args:
        model: trained AcousticModel.
        features: [N, max_frames, mel] tensor from a prepared corpus.
        labels: reference phoneme-index sequences per utterance.
        phoneme_map: mapping used by the model.

    Returns:
        dict with phoneme_error_rate, phoneme_accuracy, total_phonemes and
        the top-25 confusion pairs.
    """
    dataset = PhonemeDataset(features, labels)
    loader = DataLoader(
        dataset, batch_size=batch_size, shuffle=False, collate_fn=ctc_collate
    )
    model.eval()
    model = model.to(device)

    total_ph = 0
    total_errors = 0
    confusion: Counter = Counter()
    per_phoneme_total: Counter = Counter()
    per_phoneme_correct: Counter = Counter()

    with torch.no_grad():
        for features_batch, input_lengths, targets, target_lengths in loader:
            features_batch = features_batch.to(device)
            logits = model(features_batch)
            sequences = greedy_from_logits(logits, phoneme_map.vocab_size - 1)

            flat_targets = targets.cpu().tolist()
            start = 0
            for i, tlen in enumerate(target_lengths.tolist()):
                ref = flat_targets[start : start + tlen]
                start += tlen
                pred = sequences[i]

                total_ph += len(ref)
                total_errors += _edit_distance(pred, ref)
                _count_confusion(
                    pred, ref, per_phoneme_total, per_phoneme_correct, confusion
                )

    return {
        "total_phonemes": total_ph,
        "phoneme_error_rate": round(total_errors / max(total_ph, 1), 6),
        "phoneme_accuracy": round(1.0 - (total_errors / max(total_ph, 1)), 6),
        "per_phoneme_accuracy": {
            phoneme_map.index_to_symbol[idx]: (
                round(per_phoneme_correct[idx] / max(per_phoneme_total[idx], 1), 6)
            )
            for idx in sorted(per_phoneme_total)
        },
        "confusion": {
            f"{phoneme_map.index_to_symbol[a]} -> {phoneme_map.index_to_symbol[b]}": count
            for (a, b), count in confusion.most_common(25)
        },
    }


def _edit_distance(a: List[int], b: List[int]) -> int:
    m, n = len(a), len(b)
    dp = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(m + 1):
        dp[i][0] = i
    for j in range(n + 1):
        dp[0][j] = j
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            dp[i][j] = min(
                dp[i - 1][j] + 1,
                dp[i][j - 1] + 1,
                dp[i - 1][j - 1] + (0 if a[i - 1] == b[j - 1] else 1),
            )
    return dp[m][n]


def _count_confusion(
    pred: List[int],
    ref: List[int],
    per_phoneme_total: Counter,
    per_phoneme_correct: Counter,
    confusion: Counter,
) -> None:
    pred_s = [str(i) for i in pred]
    ref_s = [str(i) for i in ref]
    for op in align(pred_s, ref_s):
        if op.target_index is None:
            continue
        if op.target_index >= len(ref):
            continue
        true_index = ref[op.target_index]
        per_phoneme_total[true_index] += 1
        if op.op_type == "match":
            per_phoneme_correct[true_index] += 1
            if op.predicted_index is not None:
                confusion[(true_index, true_index)] += 1
        elif op.op_type == "substitution" and op.predicted_index is not None:
            confusion[(true_index, pred[op.predicted_index])] += 1


def write_evaluation_report(result: Dict, path: Path) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
