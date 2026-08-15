import pytest

from echovoice_ml.alignment import align
from echovoice_ml.scoring import accuracy_score, phoneme_error_rate, score_alignment


def _align(pred, target):
    return align(pred, target)


def test_accuracy_perfect():
    ops = _align(["s", "ʌ", "n"], ["s", "ʌ", "n"])
    assert accuracy_score(ops) == 1.0
    assert phoneme_error_rate(ops) == 0.0


def test_accuracy_half():
    ops = _align(["s", "u"], ["s", "i"])
    assert accuracy_score(ops) == 0.5
    assert phoneme_error_rate(ops) == 0.5


def test_accuracy_empty_raises():
    with pytest.raises(ValueError):
        accuracy_score([])


def test_score_alignment_weighted():
    ops = _align(["s", "i"], ["s", "u"])
    result = score_alignment(ops, difficulty_weights=[0.5, 1.0])
    # target 0 weight 0.5 (match), target 1 weight 1.0 (substitution)
    assert result["accuracy"] == 0.5
    assert result["phoneme_error_rate"] == 0.5
    assert result["weighted_accuracy"] == pytest.approx(0.5 / 1.5)


def test_score_alignment_default_weights():
    ops = _align(["s", "i"], ["s", "u"])
    result = score_alignment(ops)
    assert result["weighted_accuracy"] == pytest.approx(0.5)


def test_weighted_bonus_for_easy_phonemes():
    ops = _align(["s", "i"], ["s", "u"])
    result = score_alignment(ops, difficulty_weights=[0.2, 0.2])
    # both target phonemes easy: a match counts 0.2 of 0.4 -> 0.5
    assert result["weighted_accuracy"] == pytest.approx(0.5)
