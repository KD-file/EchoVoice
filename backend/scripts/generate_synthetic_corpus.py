"""Generates a small synthetic speech corpus for running the pipeline end-to-end.

Each target word is spoken "aloud" by concatenating per-phoneme acoustic
templates: vowels are additive formant resonators, fricatives are
band-filtered noise, plosives get a short noise burst, etc. This is *not*
real speech — it exists so that `scripts/train.py` and the tests can be run
without downloading a large corpus. Use `scripts/prepare_corpus.py` with a
real corpus (CommonVoice, TIMIT, LibriSpeech) for production training.

Output layout:
    out/
        wav/  <word>_<idx>.wav
        manifest.jsonl    # path<TAB>word<TAB>phoneme1 phoneme2 ...
"""

from __future__ import annotations

import argparse
import random
import wave
from pathlib import Path

import numpy as np

SAMPLE_RATE = 16000

# word -> IPA phoneme sequence (all symbols present in the phoneme inventory)
WORD_PHONEMES: dict[str, list[str]] = {
    "sun": ["s", "ʌ", "n"],
    "see": ["s", "i"],
    "sit": ["s", "ɪ", "t"],
    "sea": ["s", "i"],
    "ship": ["ʃ", "ɪ", "p"],
    "shop": ["ʃ", "ɑ", "p"],
    "cheese": ["tʃ", "i", "z"],
    "jam": ["dʒ", "æ", "m"],
    "jump": ["dʒ", "ʌ", "m", "p"],
    "fan": ["f", "æ", "n"],
    "van": ["v", "æ", "n"],
    "thumb": ["θ", "ʌ", "m"],
    "this": ["ð", "ɪ", "s"],
    "fish": ["f", "ɪ", "ʃ"],
    "zoo": ["z", "u"],
    "shoes": ["ʃ", "u", "z"],
    "red": ["r", "e", "d"],
    "bed": ["b", "e", "d"],
    "cat": ["k", "æ", "t"],
    "dog": ["d", "ɔ", "g"],
    "pig": ["p", "ɪ", "g"],
    "goat": ["g", "o", "t"],
    "ball": ["b", "ɔ", "l"],
    "lip": ["l", "ɪ", "p"],
    "moon": ["m", "u", "n"],
    "nose": ["n", "o", "z"],
    "tree": ["t", "r", "i"],
    "key": ["k", "i"],
    "car": ["k", "ɑ", "r"],
    "look": ["l", "ʊ", "k"],
    "book": ["b", "ʊ", "k"],
    "clock": ["k", "l", "ɑ", "k"],
}

# Formant resonances per phoneme: (frequency, amplitude, bandwidth)
VOWEL_FORMANTS: dict[str, list[tuple[float, float, float]]] = {
    "i": [(300, 1.0, 60), (2300, 0.5, 140), (3000, 0.25, 220)],
    "ɪ": [(400, 1.0, 80), (2000, 0.5, 160), (2550, 0.2, 240)],
    "e": [(500, 1.0, 90), (1800, 0.5, 170), (2500, 0.2, 240)],
    "æ": [(700, 1.0, 100), (1700, 0.5, 180), (2500, 0.2, 240)],
    "ʌ": [(700, 1.0, 100), (1200, 0.4, 180), (2600, 0.2, 240)],
    "ɑ": [(750, 1.0, 100), (1100, 0.4, 180), (2600, 0.2, 240)],
    "ɔ": [(600, 1.0, 90), (900, 0.5, 160), (2800, 0.2, 240)],
    "o": [(500, 1.0, 90), (900, 0.5, 160), (2700, 0.2, 240)],
    "u": [(350, 1.0, 70), (900, 0.4, 150), (2250, 0.2, 240)],
    "ʊ": [(450, 1.0, 80), (1000, 0.4, 160), (2300, 0.2, 240)],
}

# High-frequency noise bands for fricatives/affricates (Hz)
NOISE_BANDS: dict[str, tuple[float, float]] = {
    "s": (5000, 7200),
    "z": (4500, 6500),
    "ʃ": (3000, 4800),
    "ʒ": (2600, 4200),
    "f": (2600, 4200),
    "v": (2200, 3600),
    "θ": (3500, 5500),
    "ð": (3000, 4800),
    "tʃ": (3200, 5000),
    "dʒ": (2800, 4600),
}

PLOSIVES = {"p", "b", "t", "d", "k", "g"}
NASALS = {"m", "n", "ŋ"}
APPROXIMANTS = {"l", "r", "w", "j"}


def _band_noise(duration: float, center: float, bandwidth: float, fs: int) -> np.ndarray:
    n = int(duration * fs)
    noise = np.random.default_rng().standard_normal(n).astype(np.float32)
    spectrum = np.fft.rfft(noise)
    freqs = np.fft.rfftfreq(n, 1.0 / fs)
    mask = np.exp(-0.5 * ((freqs - center) / (bandwidth / 2.4)) ** 2)
    filtered = np.fft.irfft(spectrum * mask, n=n)
    return filtered.astype(np.float32)


def _resonance_signal(duration: float, formants: list[tuple[float, float, float]], fs: int) -> np.ndarray:
    rng = np.random.default_rng()
    t = np.arange(int(duration * fs)) / fs
    out = np.zeros_like(t, dtype=np.float32)
    f0 = rng.uniform(110, 180)  # pseudo pitch
    for freq, amp, bw in formants:
        # Harmonic excitation of a formant: sum of harmonics near the formant.
        phase = rng.uniform(0, 2 * np.pi)
        f0_env = 1.0 + 0.25 * np.sin(2 * np.pi * 6.5 * t + phase)
        resonance = np.exp(-bw * t) * np.sin(2 * np.pi * freq * t) * f0_env
        out += amp * resonance
    return out / max(np.max(np.abs(out)), 1e-6)


def synthesize_phoneme(phoneme: str, duration: float, fs: int) -> np.ndarray:
    parts: list[np.ndarray] = []

    if phoneme in PLOSIVES:
        burst = _band_noise(min(0.03, duration), 2500, 1800, fs)
        burst *= np.exp(-np.linspace(0, 4, len(burst)))
        parts.append(burst)

    if phoneme in VOWEL_FORMANTS:
        parts.append(_resonance_signal(duration, VOWEL_FORMANTS[phoneme], fs))
    elif phoneme in NOISE_BANDS:
        center, _hi = NOISE_BANDS[phoneme]
        parts.append(_band_noise(duration, center, 1400, fs))
        if phoneme in {"z", "v", "ð", "ʒ", "dʒ"}:
            parts.append(0.4 * _resonance_signal(duration, [(200, 0.8, 80)], fs))
    elif phoneme in NASALS:
        parts.append(_resonance_signal(duration, [(250, 1.0, 60), (1200, 0.5, 200), (2200, 0.3, 250)], fs))
    elif phoneme in APPROXIMANTS:
        if phoneme == "l":
            parts.append(_resonance_signal(duration, [(250, 1.0, 60), (1200, 0.5, 150)], fs))
        elif phoneme == "r":
            parts.append(_resonance_signal(duration, [(400, 1.0, 80), (1500, 0.4, 160)], fs))
        elif phoneme == "w":
            parts.append(_resonance_signal(duration, [(300, 1.0, 70), (900, 0.5, 150)], fs))
        elif phoneme == "j":
            parts.append(_resonance_signal(duration, [(300, 1.0, 70), (2100, 0.5, 150)], fs))
    else:
        parts.append(_resonance_signal(duration, [(400, 1.0, 120)], fs))

    if not parts:
        return np.zeros(int(duration * fs), dtype=np.float32)

    signal = np.concatenate(parts)[: int(duration * fs)]
    # Envelope: smooth attack/release to avoid clicks.
    n = len(signal)
    ramp = int(0.02 * fs)
    env = np.ones(n, dtype=np.float32)
    if n > 2 * ramp:
        env[:ramp] = np.linspace(0, 1, ramp)
        env[-ramp:] = np.linspace(1, 0, ramp)
    return (signal * env).astype(np.float32)


def synthesize_word(phonemes: list[str], fs: int = SAMPLE_RATE) -> np.ndarray:
    rng = np.random.default_rng()
    chunks: list[np.ndarray] = []
    for ph in phonemes:
        if ph in VOWEL_FORMANTS:
            dur = rng.uniform(0.12, 0.24)
        else:
            dur = rng.uniform(0.08, 0.16)
        chunks.append(synthesize_phoneme(ph, dur, fs))
        chunks.append(np.zeros(int(rng.uniform(0.02, 0.05) * fs), dtype=np.float32))
    word = np.concatenate(chunks) if chunks else np.zeros(fs // 2, dtype=np.float32)
    peak = max(np.max(np.abs(word)), 1e-6)
    word = word / peak * 0.8
    if rng.random() < 0.3:  # occasionally add mild background noise
        word = word + 0.02 * np.std(word) * rng.standard_normal(len(word)).astype(np.float32)
    return word


def write_wav(path: Path, samples: np.ndarray, fs: int) -> None:
    pcm = np.clip(samples * 32767.0, -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(fs)
        wav.writeframes(pcm.tobytes())


def generate(out_dir: Path, samples_per_word: int, seed: int = 7) -> Path:
    random.seed(seed)
    out_dir = Path(out_dir)
    wav_dir = out_dir / "wav"
    wav_dir.mkdir(parents=True, exist_ok=True)

    lines: list[str] = []
    for word, phonemes in sorted(WORD_PHONEMES.items()):
        for idx in range(samples_per_word):
            samples = synthesize_word(phonemes)
            path = wav_dir / f"{word}_{idx}.wav"
            write_wav(path, samples, SAMPLE_RATE)
            lines.append(f"{path}\t{word}\t{' '.join(phonemes)}")

    manifest = out_dir / "manifest.jsonl"
    manifest.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=Path("data/synthetic"))
    parser.add_argument("--samples-per-word", type=int, default=4)
    parser.add_argument("--seed", type=int, default=7)
    args = parser.parse_args()

    manifest = generate(args.out, args.samples_per_word, args.seed)
    print(f"Generated {len(manifest.read_text(encoding='utf-8').splitlines())} utterances -> {args.out.resolve()}")


if __name__ == "__main__":
    main()
