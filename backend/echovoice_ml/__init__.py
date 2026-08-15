"""EchoVoice ML package.

Contains the acoustic feature extraction, phoneme alignment/scoring, and the
phoneme-level acoustic model used both for training and for server-side
inference in the FastAPI backend. The Flutter app mirrors the *feature
contract* (mel-spectrogram parameters) and the *decoding/scoring* semantics so
that on-device (TFLite) results and server-side (PyTorch/ONNX) results are
directly comparable.

Public API:
    phoneme_map  -- the IPA phoneme inventory + blank token (single source of truth)
    features     -- mel-spectrogram extraction (numpy only)
    alignment    -- edit-distance phoneme alignment (matches the Dart aligner)
    scoring      -- accuracy / phoneme error rate / weighted score
    model        -- acoustic models (Whisper encoder or GRU baseline) + CTC greedy decoding
    trainer      -- training loop
    evaluate     -- evaluation (PER, accuracy, confusion)
    export       -- checkpoint -> ONNX / TFLite export
"""

from . import alignment, features, phoneme_map, scoring
from .phoneme_map import PHONEME_SET, BLANK_TOKEN, BLANK_INDEX, PhonemeMap

__all__ = [
    "alignment",
    "features",
    "phoneme_map",
    "scoring",
    "PHONEME_SET",
    "BLANK_TOKEN",
    "BLANK_INDEX",
    "PhonemeMap",
]

__version__ = "0.1.0"
