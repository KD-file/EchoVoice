"""Acoustic feature extraction (mel-spectrogram).

The parameters here form the *feature contract* shared with the Flutter app:
`DartAcousticFeatureExtractor` in `lib/services/asr_pipeline.dart` reproduces
exactly the same STFT + mel-filterbank math on-device so that TFLite results
and server-side results are computed over identical inputs.

Only numpy is required (no librosa/scipy), which keeps the pipeline portable.
"""

from __future__ import annotations

import math
import wave
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import List, Tuple

import numpy as np

# ---------------------------------------------------------------------------
# Feature contract (must stay in sync with lib/services/asr_pipeline.dart)
# ---------------------------------------------------------------------------
SAMPLE_RATE = 16000
FRAME_LENGTH = 400       # 25 ms at 16 kHz
HOP_LENGTH = 160         # 10 ms at 16 kHz
N_FFT = 512
NUM_MEL_BINS = 80
MEL_FMIN = 80.0
MEL_FMAX = 7600.0
LOG_OFFSET = 1e-6        # log-floor to keep log(mel) finite
MAX_FRAMES = 800         # 8 s at 10 ms/frame (matches kMaximumAudioDurationMs)


@dataclass(frozen=True)
class FeatureContract:
    sample_rate: int = SAMPLE_RATE
    frame_length: int = FRAME_LENGTH
    hop_length: int = HOP_LENGTH
    n_fft: int = N_FFT
    num_mel_bins: int = NUM_MEL_BINS
    mel_fmin: float = MEL_FMIN
    mel_fmax: float = MEL_FMAX
    max_frames: int = MAX_FRAMES

    def to_dict(self) -> dict:
        return asdict(self)


def read_wav(path: Path | str) -> Tuple[np.ndarray, int]:
    """Reads a 16-bit mono PCM WAV file into float32 samples in [-1, 1]."""
    path = Path(path)
    with wave.open(str(path), "rb") as wav:
        channels = wav.getnchannels()
        sample_width = wav.getsampwidth()
        sample_rate = wav.getframerate()
        frames = wav.readframes(wav.getnframes())

    if sample_width != 2:
        raise ValueError(f"Expected 16-bit PCM audio, got {sample_width * 8}-bit.")
    samples = np.frombuffer(frames, dtype="<i2").astype(np.float32) / 32768.0
    if channels > 1:
        samples = samples.reshape(-1, channels).mean(axis=1)
    return samples, sample_rate


def hann_window(n: int) -> np.ndarray:
    """DFT-symmetric Hann window (same formula as the Dart implementation).

    Uses (n - 1) so that window[0] == window[n - 1] == 0 (perfect symmetry).
    """
    return 0.5 * (1.0 - np.cos(2.0 * np.pi * np.arange(n) / (n - 1)))


def stft(
    samples: np.ndarray,
    sample_rate: int = SAMPLE_RATE,
    frame_length: int = FRAME_LENGTH,
    hop_length: int = HOP_LENGTH,
    n_fft: int = N_FFT,
) -> np.ndarray:
    """Short-time Fourier transform via numpy FFT.

    Returns magnitude spectrum of shape [T, n_fft // 2 + 1].
    """
    if samples.ndim != 1:
        raise ValueError("stft expects a 1-D float signal.")
    if len(samples) < frame_length:
        return np.zeros((0, n_fft // 2 + 1), dtype=np.float32)

    window = hann_window(frame_length)
    num_frames = (len(samples) - frame_length) // hop_length + 1
    frames = np.lib.stride_tricks.sliding_window_view(
        samples, frame_length
    )[::hop_length][:num_frames]
    windowed = frames * window
    spectrum = np.fft.rfft(windowed, n=n_fft, axis=1)
    magnitude = np.abs(spectrum).astype(np.float32)
    return magnitude


def mel_filterbank(
    num_mel_bins: int = NUM_MEL_BINS,
    n_fft: int = N_FFT,
    sample_rate: int = SAMPLE_RATE,
    fmin: float = MEL_FMIN,
    fmax: float = MEL_FMAX,
) -> np.ndarray:
    """Triangular mel-scale filterbank of shape [num_mel_bins, n_fft // 2 + 1]."""
    def hz_to_mel(freq: float) -> float:
        return 1127.0 * math.log(1.0 + freq / 700.0)

    def mel_to_hz(mel: float) -> float:
        return 700.0 * (math.exp(mel / 1127.0) - 1.0)

    num_bins = n_fft // 2 + 1
    fft_freqs = np.linspace(0.0, sample_rate / 2.0, num_bins)
    mel_points = np.linspace(hz_to_mel(fmin), hz_to_mel(fmax), num_mel_bins + 2)
    hz_points = np.array([mel_to_hz(m) for m in mel_points])

    filterbank = np.zeros((num_mel_bins, num_bins), dtype=np.float32)
    for m in range(num_mel_bins):
        left, center, right = hz_points[m], hz_points[m + 1], hz_points[m + 2]
        if right - left <= 0:
            continue
        rising = (fft_freqs - left) / (center - left + 1e-12)
        falling = (right - fft_freqs) / (right - center + 1e-12)
        triangle = np.minimum(rising, falling)
        filterbank[m] = np.clip(triangle, 0.0, None)
    return filterbank


def mel_spectrogram(
    samples: np.ndarray,
    sample_rate: int = SAMPLE_RATE,
    frame_length: int = FRAME_LENGTH,
    hop_length: int = HOP_LENGTH,
    n_fft: int = N_FFT,
    num_mel_bins: int = NUM_MEL_BINS,
    fmin: float = MEL_FMIN,
    fmax: float = MEL_FMAX,
    max_frames: int = MAX_FRAMES,
) -> np.ndarray:
    """Computes a log-mel spectrogram of shape [T, num_mel_bins]."""
    magnitude = stft(
        samples,
        sample_rate=sample_rate,
        frame_length=frame_length,
        hop_length=hop_length,
        n_fft=n_fft,
    )
    if magnitude.shape[0] == 0:
        return np.zeros((0, num_mel_bins), dtype=np.float32)

    filterbank = mel_filterbank(
        num_mel_bins, n_fft, sample_rate, fmin, fmax
    )
    power = magnitude.astype(np.float32) ** 2
    mel = np.dot(power, filterbank.T)
    log_mel = np.log(mel + LOG_OFFSET).astype(np.float32)

    if log_mel.shape[0] > max_frames:
        log_mel = log_mel[:max_frames]
    return log_mel


def extract_to_buffer(
    samples: np.ndarray,
    sample_rate: int = SAMPLE_RATE,
    max_frames: int = MAX_FRAMES,
) -> np.ndarray:
    """Mel features padded/truncated to a fixed [max_frames, num_mel_bins]
    tensor, as required by a fixed-shape TFLite input."""
    mel = mel_spectrogram(samples, sample_rate=sample_rate)
    num_frames = mel.shape[0]
    if num_frames == 0:
        return np.zeros((max_frames, NUM_MEL_BINS), dtype=np.float32)
    if num_frames > max_frames:
        return mel[:max_frames]
    padded = np.zeros((max_frames, NUM_MEL_BINS), dtype=np.float32)
    padded[:num_frames] = mel
    return padded


def wav_to_mel(path: Path | str) -> np.ndarray:
    """Convenience: reads a WAV and returns its log-mel spectrogram."""
    samples, sample_rate = read_wav(path)
    if sample_rate != SAMPLE_RATE:
        samples = _resample_linear(samples, sample_rate, SAMPLE_RATE)
    return mel_spectrogram(samples, sample_rate=SAMPLE_RATE)


def _resample_linear(samples: np.ndarray, src: int, dst: int) -> np.ndarray:
    """Crude linear resampler (adequate for 8k/16k/44.1k conversions)."""
    n = round(len(samples) * dst / src)
    x_old = np.linspace(0.0, 1.0, len(samples))
    x_new = np.linspace(0.0, 1.0, n)
    return np.interp(x_new, x_old, samples).astype(np.float32)


def write_feature_contract_json(path: Path) -> None:
    """Writes the feature contract as JSON (documentation + app config aid)."""
    import json as _json

    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        _json.dumps(FeatureContract().to_dict(), indent=2) + "\n",
        encoding="utf-8",
    )
