# EchoVoice ML — Phoneme-level pronunciation assessment model

Trains and exports the on-device acoustic model used by the EchoVoice Flutter
app and the FastAPI backend.

## Pipeline

```
generate_synthetic_corpus.py ──> manifest.jsonl ──> prepare_corpus.py ──> prepared corpus
                                                                    │
train.py (Whisper encoder + CTC phoneme head) ─────────────────────┘
        │
        └──> checkpoint.pt ──> export_tflite.py ──> echovoice_asr.onnx / .tflite
```

The exported `.tflite` file is copied into the Flutter app at
`assets/models/echovoice_asr.tflite`, and `phoneme_set.json` at
`assets/phonemes/phoneme_set.json`.

## Encoder backends

The acoustic model has two interchangeable backends (`--encoder`):

| Backend | Description |
|---------|-------------|
| `whisper` (default) | A real, compressed Whisper encoder checkpoint loaded from the Hugging Face Hub (or a local dir), frozen by default, with a small trainable projection to the encoder’s native mel width (80 bins for whisper-tiny, 128 for large-v3) and a CTC phoneme head on top. |
| `gru` | The original compact Conv1D + bidirectional GRU baseline for fast iteration and small data. |

For the Whisper backend the encoder is loaded with
`--whisper-model-id`, which accepts any HF Hub id or local directory.
"Distilled/quantized" checkpoints work through the same argument:

- `openai/whisper-tiny.en` (default) — 39M-parameter English-only encoder.
- `distil-whisper/distil-small.en` — distilled (6-layer) encoder.
- a locally saved int8/4-bit export — e.g. produced with
  `optimum-cli export onnx --quantize int8` and then loaded by path.
- `stub` — a tiny dependency-free stand-in used by the unit tests.

The encoder is frozen during training (`--freeze-encoder`, default on) so the
optimizer only touches the input projection and CTC head. Use
`--no-freeze-encoder` or `--unfreeze-last N` to adapt the last N encoder
blocks to the therapy domain. `--quantize int8` applies torch dynamic
quantization to the encoder before freezing (CPU-only), shrinking the
checkpoint.

Note: EchoVoice's shared feature contract uses 80 mel bins; the input
projection maps them to the encoder's native width (80 for whisper-tiny,
128 for whisper-large-v3).
The Whisper encoder also downsamples 2x, so CTC runs at `ceil(T / 2)` output
frames; the trainer computes this automatically via `model.output_length()`.

## Quick start (synthetic corpus)

```powershell
pip install -r requirements.txt
python scripts/generate_synthetic_corpus.py --out data/synthetic --samples-per-word 6
python scripts/prepare_corpus.py --manifest data/synthetic/manifest.jsonl --out data/prepared
python scripts/train.py --corpus data/prepared --out runs/run1 --epochs 15 --device cpu
python scripts/evaluate.py --checkpoint runs/run1/checkpoint.pt --corpus data/prepared
python scripts/export_tflite.py --checkpoint runs/run1/checkpoint.pt --out export --tflite
```

The first `train.py` run downloads the Whisper encoder (≈75 MB) into the
Hugging Face cache. To skip the download, point `--whisper-model-id` at a
local directory containing a saved `WhisperModel`.

## Feature contract

The mel-spectrogram parameters below are the *shared contract* between Python,
the Dart on-device extractor (`lib/services/asr_pipeline.dart`), and the
exported model input. Do not change them on only one side.

| Parameter      | Value |
|----------------|-------|
| sample rate    | 16000 Hz |
| frame length   | 400 (25 ms) |
| hop length     | 160 (10 ms) |
| n_fft          | 512 |
| mel bins       | 80 |
| mel range      | 80–7600 Hz |
| max frames     | 800 (8 s) |
| model input    | float32 `[1, 800, 80]` |

## Real speech corpora

`generate_synthetic_corpus.py` only proves the pipeline works end-to-end. For
production training use a phoneme-labelled corpus:

- **TIMIT** — per-sentence phoneme alignments, ideal (requires licensing).
- **CommonVoice** / **LibriSpeech** — need a grapheme-to-phoneme step. Produce
  a `manifest.jsonl` with rows `path<TAB>word<TAB>phoneme1 phoneme2 ...`
  (either from a G2P system such as `g2p-en`, or the built-in table in
  `prepare_corpus.py` which covers the EchoVoice exercise word list).

## Environment notes

Python 3.10–3.12 is recommended; PyTorch wheels for Python 3.14 are not
guaranteed on Windows. `onnx2tf` (TFLite conversion) pulls in TensorFlow, so
it is optional — ONNX export always works and can be converted later.
