import wave

import numpy as np
import pytest

from echovoice_ml import features


def _write_wav(path, samples, fs=16000):
    pcm = np.clip(samples * 32767, -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(fs)
        wav.writeframes(pcm.tobytes())
    return path


def test_contract_constants_are_sane():
    assert features.NUM_MEL_BINS == 80
    assert features.MAX_FRAMES == 800
    assert features.SAMPLE_RATE == 16000
    assert features.FRAME_LENGTH > features.HOP_LENGTH


def test_hann_window_is_symmetric():
    w = features.hann_window(400)
    assert np.allclose(w, w[::-1])
    assert w.min() >= 0.0


def test_stft_shape():
    samples = np.sin(2 * np.pi * 440 * np.arange(16000) / 16000).astype(np.float32)
    magnitude = features.stft(samples)
    assert magnitude.ndim == 2
    assert magnitude.shape[1] == 512 // 2 + 1
    assert magnitude.shape[0] > 0


def test_mel_filterbank_shape_and_positivity():
    fb = features.mel_filterbank()
    assert fb.shape == (80, 512 // 2 + 1)
    assert (fb >= 0).all()
    assert (fb.sum(axis=1) > 0).all()


def test_mel_spectrogram_shape():
    samples = np.sin(2 * np.pi * 440 * np.arange(16000) / 16000).astype(np.float32)
    mel = features.mel_spectrogram(samples)
    assert mel.shape[1] == 80
    assert mel.shape[0] == features.MAX_FRAMES or mel.shape[0] > 0
    assert mel.dtype == np.float32


def test_extract_to_buffer_fixed_shape():
    samples = np.zeros(16000, dtype=np.float32)
    padded = features.extract_to_buffer(samples)
    assert padded.shape == (features.MAX_FRAMES, 80)


def test_extract_to_buffer_truncates_long():
    samples = np.zeros(16000 * 12, dtype=np.float32)
    padded = features.extract_to_buffer(samples)
    assert padded.shape == (features.MAX_FRAMES, 80)


def test_read_wav_roundtrip(tmp_path):
    t = np.linspace(0, 1, 16000, endpoint=False)
    samples = (0.5 * np.sin(2 * np.pi * 440 * t)).astype(np.float32)
    path = _write_wav(tmp_path / "test.wav", samples)
    out, fs = features.read_wav(path)
    assert fs == 16000
    assert len(out) == 16000
    assert np.max(np.abs(out)) <= 1.0


def test_read_wav_rejects_non_16bit(tmp_path):
    path = tmp_path / "8bit.wav"
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(1)
        wav.setframerate(16000)
        wav.writeframes(bytes([0] * 16000))
    with pytest.raises(ValueError):
        features.read_wav(path)


def test_wav_to_mel(tmp_path):
    t = np.linspace(0, 1, 16000, endpoint=False)
    samples = (0.5 * np.sin(2 * np.pi * 440 * t)).astype(np.float32)
    path = _write_wav(tmp_path / "tone.wav", samples)
    mel = features.wav_to_mel(path)
    assert mel.shape[1] == 80
