"""The IPA phoneme inventory used by EchoVoice.

This module is the *single source of truth* for the phoneme set. The FastAPI
backend imports it directly; the Flutter app consumes a generated JSON copy
(assets/phonemes/phoneme_set.json) produced by :func:`write_phoneme_set_json`.

The set is deliberately small and therapy-focused: it covers the consonants
and vowels most commonly targeted by speech sound disorder therapy for
autistic children at Growth Journey Learning Center Inc. If the SLP needs a
different phoneme, add it here, regenerate the JSON, and retrain.

Model output size == len(PHONEME_SET) + 1, where the extra index is the CTC
blank / silence token.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List

# Therapy-relevant IPA target phonemes (24 consonants + 10 vowels).
PHONEME_SET: List[str] = [
    # plosives
    "p", "b", "t", "d", "k", "g",
    # fricatives
    "f", "v", "θ", "ð", "s", "z", "ʃ", "ʒ", "h",
    # affricates
    "tʃ", "dʒ",
    # nasals
    "m", "n", "ŋ",
    # approximants / liquids
    "l", "r", "w", "j",
    # vowels
    "i", "ɪ", "e", "æ", "ʌ", "ɑ", "ɔ", "o", "u", "ʊ",
]

# CTC blank / silence token. Not part of the phonetic inventory; it marks
# silence, non-speech, and between-phoneme frames.
BLANK_TOKEN = "<blank>"
BLANK_INDEX = len(PHONEME_SET)


class PhonemeMap:
    """Bidirectional IPA-symbol <-> integer index mapping."""

    def __init__(self, phonemes: List[str] | None = None) -> None:
        self.phonemes: List[str] = list(phonemes) if phonemes else list(PHONEME_SET)
        self.symbol_to_index: Dict[str, int] = {
            symbol: index for index, symbol in enumerate(self.phonemes)
        }
        self.index_to_symbol: Dict[int, str] = {
            index: symbol for symbol, index in self.symbol_to_index.items()
        }

    @property
    def num_phonemes(self) -> int:
        """Number of phoneme symbols (excluding the blank token)."""
        return len(self.phonemes)

    @property
    def vocab_size(self) -> int:
        """Output size of the model: phonemes + blank."""
        return self.num_phonemes + 1

    def encode(self, phonemes: List[str]) -> List[int]:
        """Maps IPA symbols to integer indices (raises on unknown symbols)."""
        try:
            return [self.symbol_to_index[s] for s in phonemes]
        except KeyError as exc:
            raise ValueError(
                f'"{exc.args[0]}" is not in the phoneme inventory.'
            ) from None

    def decode(self, indices: List[int]) -> List[str]:
        """Maps integer indices back to IPA symbols / the blank token."""
        return [self.index_to_symbol[i] for i in indices]


def write_phoneme_set_json(destination: Path) -> None:
    """Writes the phoneme set (including blank) as JSON for the Flutter app."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "phonemes": PHONEME_SET,
        "blank_token": BLANK_TOKEN,
        "blank_index": BLANK_INDEX,
        "version": 1,
    }
    destination.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":  # pragma: no cover
    import sys

    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("phoneme_set.json")
    write_phoneme_set_json(out)
    print(f"Wrote {out.resolve()}")
