"""Exports a trained checkpoint to ONNX and (if onnx2tf is available) TFLite.

The .tflite artifact is what the Flutter app loads from
assets/models/echovoice_asr.tflite via tflite_flutter.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from echovoice_ml.export import export_onnx, export_tflite


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=Path("export"))
    parser.add_argument("--device", default="cpu")
    parser.add_argument("--tflite", action="store_true", help="attempt TFLite conversion")
    args = parser.parse_args()

    spec = export_onnx(args.checkpoint, args.out, device=args.device)
    print(f"ONNX exported -> {args.out.resolve()}")
    if args.tflite:
        artifact = export_tflite(args.checkpoint, args.out, device=args.device)
        print(f"TFLite exported -> {artifact}")


if __name__ == "__main__":
    main()
