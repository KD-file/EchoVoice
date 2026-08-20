"""Evaluates a trained checkpoint against a prepared corpus."""

from __future__ import annotations

import argparse
from pathlib import Path

from echovoice_ml.evaluate import evaluate_predictions, write_evaluation_report
from echovoice_ml.phoneme_map import PhonemeMap
from echovoice_ml.trainer import Trainer, load_corpus


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--corpus", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=Path("evaluation_report.json"))
    parser.add_argument("--device", default="cpu")
    args = parser.parse_args()

    features, labels, _words = load_corpus(args.corpus)
    model, phoneme_map = Trainer.load_checkpoint(args.checkpoint, device=args.device)

    report = evaluate_predictions(model, features, labels, phoneme_map, device=args.device)
    write_evaluation_report(report, args.out)
    print(report)


if __name__ == "__main__":
    main()
