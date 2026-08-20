"""Prepares an audio corpus into the training format consumed by train.py.

Input manifest (manifest.jsonl), one utterance per line:
    <path-to-wav>\t<word>\t<phoneme1 phoneme2 ...>

For the synthetic corpus this manifest is produced by
`generate_synthetic_corpus.py`. For a real corpus, produce the same manifest
with phoneme-level transcriptions (TIMIT gives these directly; CommonVoice /
LibriSpeech need a G2P step). A small built-in G2P table covers the exercise
word list; unknown words are skipped with a warning.

Output directory:
    features.npz     # float32 [N, max_frames, num_mel_bins]
    labels.json      # list of phoneme-index lists (one per utterance)
    manifest.jsonl   # subset of the input with resolvable phoneme labels
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import List

import numpy as np

from echovoice_ml import features
from echovoice_ml.phoneme_map import PhonemeMap

# Built-in grapheme-to-phoneme table for the exercise word list (fallback
# only; prefer explicit phoneme columns in the manifest).
G2P: dict[str, List[str]] = {
    "sun": ["s", "ʌ", "n"], "see": ["s", "i"], "sit": ["s", "ɪ", "t"],
    "ship": ["ʃ", "ɪ", "p"], "cheese": ["tʃ", "i", "z"], "jam": ["dʒ", "æ", "m"],
    "jump": ["dʒ", "ʌ", "m", "p"], "fan": ["f", "æ", "n"], "van": ["v", "æ", "n"],
    "thumb": ["θ", "ʌ", "m"], "this": ["ð", "ɪ", "s"], "fish": ["f", "ɪ", "ʃ"],
    "zoo": ["z", "u"], "shoes": ["ʃ", "u", "z"], "red": ["r", "e", "d"],
    "bed": ["b", "e", "d"], "cat": ["k", "æ", "t"], "dog": ["d", "ɔ", "g"],
    "pig": ["p", "ɪ", "g"], "goat": ["g", "o", "t"], "ball": ["b", "ɔ", "l"],
    "lip": ["l", "ɪ", "p"], "moon": ["m", "u", "n"], "nose": ["n", "o", "z"],
    "tree": ["t", "r", "i"], "key": ["k", "i"], "car": ["k", "ɑ", "r"],
    "look": ["l", "ʊ", "k"], "book": ["b", "ʊ", "k"], "clock": ["k", "l", "ɑ", "k"],
    "shop": ["ʃ", "ɑ", "p"], "sea": ["s", "i"],
}


def parse_manifest(path: Path) -> List[dict]:
    rows: List[dict] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            raise ValueError(f"Malformed manifest line: {line!r}")
        audio_path = Path(parts[0])
        word = parts[1].strip().lower()
        phonemes = parts[2].split() if len(parts) > 2 else None
        rows.append({"path": audio_path, "word": word, "phonemes": phonemes})
    return rows


def resolve_phonemes(row: dict, pmap: PhonemeMap) -> List[str]:
    phonemes = row["phonemes"] or G2P.get(row["word"])
    if not phonemes:
        return []
    # Drop any symbol outside the inventory.
    valid = [ph for ph in phonemes if ph in pmap.symbol_to_index]
    return valid


def prepare(manifest_path: Path, out_dir: Path) -> None:
    manifest_path = Path(manifest_path)
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    pmap = PhonemeMap()
    rows = parse_manifest(manifest_path)

    features_list: List[np.ndarray] = []
    labels_list: List[List[int]] = []
    kept: List[str] = []

    skipped = 0
    for row in rows:
        if not row["path"].exists():
            skipped += 1
            continue
        phonemes = resolve_phonemes(row, pmap)
        if not phonemes:
            skipped += 1
            continue
        samples, sample_rate = features.read_wav(row["path"])
        if sample_rate != features.SAMPLE_RATE:
            samples = features._resample_linear(samples, sample_rate, features.SAMPLE_RATE)
        mel = features.extract_to_buffer(samples, sample_rate=features.SAMPLE_RATE)
        features_list.append(mel)
        labels_list.append(pmap.encode(phonemes))
        kept.append(f"{row['path']}\t{row['word']}\t{' '.join(phonemes)}")

    if not features_list:
        raise RuntimeError(
            "No usable utterances found. Check the manifest paths and that "
            "every word's phonemes exist in the phoneme inventory."
        )

    array = np.stack(features_list).astype(np.float32)
    np.savez_compressed(out_dir / "features.npz", features=array)
    (out_dir / "labels.json").write_text(
        json.dumps(labels_list) + "\n", encoding="utf-8"
    )
    (out_dir / "manifest.jsonl").write_text(
        "\n".join(kept) + "\n", encoding="utf-8"
    )
    features.write_feature_contract_json(out_dir / "feature_contract.json")

    print(f"Prepared {len(kept)} utterances (skipped {skipped}) -> {out_dir.resolve()}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    prepare(args.manifest, args.out)


if __name__ == "__main__":
    main()
