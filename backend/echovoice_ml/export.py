"""Checkpoint -> ONNX / TFLite export for on-device deployment.

The exported model keeps the *feature contract* input: float32 [1, T, mel]
where T == max_frames (800) and mel == 80. The Flutter app pads/truncates
recorded audio to exactly that shape before calling TFLite (see
lib/services/asr/asr_input.dart).
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path
from typing import Dict, Optional

from .features import NUM_MEL_BINS, MAX_FRAMES
from .phoneme_map import BLANK_INDEX, write_phoneme_set_json
from .trainer import Trainer


def export_onnx(checkpoint: Path, out_dir: Path, device: str = "cpu") -> Dict:
    """Exports a trained checkpoint to an ONNX model + input spec JSON."""
    _ensure_utf8_stdout()  # torch's exporter prints Unicode emoji that crash on cp1252 consoles
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    model, phoneme_map = Trainer.load_checkpoint(checkpoint, device=device)
    model.eval()

    import torch

    dummy = torch.zeros(1, MAX_FRAMES, NUM_MEL_BINS, dtype=torch.float32)
    onnx_path = out_dir / "echovoice_asr.onnx"

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

    spec = {
        "model": str(onnx_path),
        "model_type": getattr(model, "model_type", "gru"),
        "input_name": "mel_spectrogram",
        "output_name": "phoneme_logits",
        "input_shape": [1, MAX_FRAMES, NUM_MEL_BINS],
        "sample_rate": 16000,
        "max_frames": MAX_FRAMES,
        "num_mel_bins": NUM_MEL_BINS,
        "blank_index": BLANK_INDEX,
        "phoneme_set": phoneme_map.phonemes,
    }
    spec_path = out_dir / "input_spec.json"
    spec_path.write_text(json.dumps(spec, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_phoneme_set_json(out_dir / "phoneme_set.json")
    return spec


def export_tflite(checkpoint: Path, out_dir: Path, device: str = "cpu") -> Path:
    """Exports to TFLite via ONNX -> (onnx2tf if available) -> TFLite.

    Falls back to ONNX export alone if `onnx2tf` is not installed, with a
    clear message (conversion is optional and best run in the provided
    ml/conda environment).
    """
    out_dir = Path(out_dir)
    spec = export_onnx(checkpoint, out_dir, device=device)
    onnx_path = out_dir / "echovoice_asr.onnx"

    if not shutil.which("onnx2tf") and not _importable("onnx2tf"):
        raise RuntimeError(
            "onnx2tf is not installed; ONNX model was exported to "
            f"{onnx_path}. Install the ml/requirements.txt extras and run "
            "onnx2tf on the ONNX file to produce a .tflite artifact."
        )

    tflite_dir = out_dir / "tflite"
    tflite_dir.mkdir(exist_ok=True)
    cmd = [
        "onnx2tf",
        "-i", str(onnx_path),
        "-o", str(tflite_dir),
        "-n",
    ]
    subprocess.run(cmd, check=True)

    candidates = sorted(tflite_dir.glob("*.tflite"))
    if not candidates:
        raise RuntimeError("onnx2tf completed but produced no .tflite file.")
    return candidates[0]


def _importable(module: str) -> bool:
    try:
        __import__(module)
        return True
    except ImportError:
        return False


def _ensure_utf8_stdout() -> None:
    import sys

    if sys.platform == "win32":
        try:
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
