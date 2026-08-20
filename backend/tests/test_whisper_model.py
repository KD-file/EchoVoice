"""Tests for the Whisper-encoder acoustic model backend."""

from __future__ import annotations

import pytest
import torch

from echovoice_ml.model import (
    AcousticModel,
    WhisperAcousticModel,
    build_model,
    build_whisper_model,
)
from echovoice_ml.phoneme_map import PhonemeMap
from echovoice_ml.trainer import Trainer


def test_whisper_model_output_shape():
    model = build_whisper_model(
        num_mel_bins=80, vocab_size=35, whisper_model_id="stub"
    )
    model.eval()
    features = torch.randn(2, 400, 80)
    with torch.no_grad():
        logits = model(features)
    # Encoder downsamples 2x: 400 -> 200 frames; CTC format is [T, B, vocab].
    assert tuple(logits.shape) == (200, 2, 35)


def test_whisper_log_probs_are_normalized():
    model = build_whisper_model(
        num_mel_bins=80, vocab_size=35, whisper_model_id="stub"
    )
    model.eval()
    with torch.no_grad():
        log_probs = model(torch.randn(1, 128, 80), log_probs=True)
    probs = torch.exp(log_probs)
    assert torch.allclose(probs.sum(dim=-1), torch.ones_like(probs.sum(dim=-1)), atol=1e-5)


def test_output_length():
    whisper = build_whisper_model(vocab_size=10, whisper_model_id="stub")
    assert whisper.output_length(800) == 400
    assert whisper.output_length(400) == 200
    assert whisper.output_length(401) == 201
    gru = AcousticModel(num_mel_bins=80, vocab_size=10)
    assert gru.output_length(800) == 800


def test_whisper_encoder_frozen_and_head_trainable():
    model = build_whisper_model(vocab_size=10, whisper_model_id="stub")
    assert all(not p.requires_grad for p in model.encoder.parameters())
    assert all(p.requires_grad for p in model.input_proj.parameters())
    assert all(p.requires_grad for p in model.head.parameters())


def test_unfreeze_last_encoder_blocks():
    model = build_whisper_model(
        vocab_size=10, whisper_model_id="stub", unfreeze_last=1
    )
    assert all(p.requires_grad for p in model.encoder.layers[-1].parameters())
    assert all(not p.requires_grad for p in model.encoder.layers[0].parameters())


def test_whisper_training_step():
    phonemes = list("abcdefghij")[:10]
    phoneme_map = PhonemeMap(phonemes)
    model = build_whisper_model(vocab_size=phoneme_map.vocab_size, whisper_model_id="stub")
    trainer = Trainer(model, phoneme_map)
    logits_before = model(torch.zeros(1, 64, 80))
    loss = trainer.train_epoch(
        [
            (
                torch.zeros(2, 64, 80),
                torch.tensor([64, 64]),
                torch.tensor([1, 2, 3]),
                torch.tensor([2, 1]),
            )
        ]
    )
    assert loss >= 0.0
    logits_after = model(torch.zeros(1, 64, 80))
    assert not torch.equal(logits_before, logits_after)


def test_whisper_checkpoint_roundtrip(tmp_path):
    model = build_whisper_model(vocab_size=10, whisper_model_id="stub")
    phoneme_map = PhonemeMap(list("abcdefghij")[:10])
    checkpoint = tmp_path / "checkpoint.pt"
    Trainer(model, phoneme_map).save_checkpoint(checkpoint)

    loaded, loaded_map = Trainer.load_checkpoint(checkpoint, device="cpu")
    assert isinstance(loaded, WhisperAcousticModel)
    assert loaded_map.phonemes == phoneme_map.phonemes

    with torch.no_grad():
        features = torch.randn(2, 128, 80)
        model.eval()
        loaded.eval()
        expected = model(features)
        actual = loaded(features)
    assert torch.allclose(actual, expected, atol=1e-5)


def test_whisper_quantize_int8(tmp_path):
    model = build_whisper_model(
        vocab_size=10, whisper_model_id="stub", quantize="int8"
    )
    model.eval()
    with torch.no_grad():
        logits = model(torch.randn(1, 128, 80))
    assert tuple(logits.shape) == (64, 1, 10)

    phoneme_map = PhonemeMap(list("abcdefghij")[:10])
    checkpoint = tmp_path / "quantized.pt"
    Trainer(model, phoneme_map).save_checkpoint(checkpoint)
    loaded, _ = Trainer.load_checkpoint(checkpoint, device="cpu")
    with torch.no_grad():
        assert tuple(loaded(torch.randn(1, 128, 80)).shape) == (64, 1, 10)


def test_gru_backend_still_works():
    model = build_model(num_mel_bins=80, vocab_size=35, encoder="gru")
    assert isinstance(model, AcousticModel)
    model.eval()
    with torch.no_grad():
        logits = model(torch.randn(1, 300, 80))
    assert tuple(logits.shape) == (300, 1, 35)


def test_real_whisper_encoder_through_frontend():
    """Drives the actual transformers WhisperEncoder (no download) through
    the variable-length frontend to validate integration with the installed
    transformers version."""
    pytest.importorskip("transformers")
    try:
        from transformers.models.whisper.modeling_whisper import (
            WhisperConfig,
            WhisperEncoder,
        )
    except ImportError:  # transformers < 5.x exports these at top level
        from transformers import WhisperConfig, WhisperEncoder

    from echovoice_ml.model import _WhisperEncoderFrontend

    config = WhisperConfig(
        d_model=64,
        encoder_layers=2,
        encoder_attention_heads=4,
        encoder_ffn_dim=256,
        num_mel_bins=128,
        max_source_positions=1500,
    )
    encoder = WhisperEncoder(config)
    frontend = _WhisperEncoderFrontend(encoder)
    frontend.eval()
    with torch.no_grad():
        out = frontend(torch.randn(1, 64, 128))
    assert tuple(out.shape) == (1, 32, 64)


def test_whisper_model_onnx_export(tmp_path):
    """ONNX export of the Whisper-encoder model traces cleanly (no network)."""
    pytest.importorskip("onnx")
    model = build_whisper_model(vocab_size=35, whisper_model_id="stub")
    model.eval()
    onnx_path = tmp_path / "echovoice_asr.onnx"
    dummy = torch.zeros(1, 800, 80)
    with torch.no_grad():
        torch.onnx.export(
            model,
            dummy,
            str(onnx_path),
            input_names=["mel_spectrogram"],
            output_names=["phoneme_logits"],
            dynamic_axes={
                "mel_spectrogram": {0: "batch"},
                "phoneme_logits": {0: "frames"},
            },
            opset_version=17,
        )
    assert onnx_path.exists()
    assert onnx_path.stat().st_size > 0
