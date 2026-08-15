import pytest

from echovoice_ml.alignment import align


def test_perfect_match():
    ops = align(["s", "ʌ", "n"], ["s", "ʌ", "n"])
    assert [op.op_type for op in ops] == ["match", "match", "match"]
    assert [op.target_index for op in ops] == [0, 1, 2]


def test_single_substitution():
    ops = align(["s", "i"], ["s", "u"])
    assert ops[0].op_type == "match"
    assert ops[1].op_type == "substitution"
    assert ops[1].predicted_index == 1
    assert ops[1].target_index == 1


def test_deletion_predicted_has_extra():
    ops = align(["s", "t", "o", "p"], ["s", "o", "p"])
    types = [op.op_type for op in ops]
    assert types.count("deletion") == 1
    # The extra predicted symbol is deleted; everything else matches.
    assert ops[0].op_type == "match"


def test_insertion_target_has_extra():
    ops = align(["s", "o", "p"], ["s", "t", "o", "p"])
    types = [op.op_type for op in ops]
    assert types.count("insertion") == 1


def test_empty_predicted_all_insertions():
    ops = align([], ["s", "ʌ", "n"])
    assert len(ops) == 3
    assert all(op.op_type == "insertion" for op in ops)
    assert all(op.predicted_index is None for op in ops)


def test_empty_target_raises():
    with pytest.raises(ValueError):
        align(["s"], [])


def test_edit_distance_is_minimal():
    # substitution is preferred over delete+insert
    ops = align(["a"], ["b"])
    assert len(ops) == 1
    assert ops[0].op_type == "substitution"


def test_indices_are_valid_ranges():
    predicted = ["k", "æ", "t"]
    target = ["k", "ʌ", "t"]
    ops = align(predicted, target)
    for op in ops:
        if op.predicted_index is not None:
            assert 0 <= op.predicted_index < len(predicted)
        assert 0 <= op.target_index < len(target)
