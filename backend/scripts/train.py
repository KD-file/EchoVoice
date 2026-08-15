"""Trains the phoneme acoustic model on a prepared corpus.

Example:
    python scripts/generate_synthetic_corpus.py --out data/synthetic --samples-per-word 6
    python scripts/prepare_corpus.py --manifest data/synthetic/manifest.jsonl --out data/prepared
    python scripts/train.py --corpus data/prepared --out runs/run1 --epochs 20 --device cpu

By default the encoder is a real Whisper checkpoint (``openai/whisper-tiny.en``)
with the CTC phoneme head trained on top; the encoder is frozen unless
``--no-freeze-encoder`` / ``--unfreeze-last`` are used. Pass ``--encoder gru``
for the original compact GRU baseline.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from torch.utils.data import DataLoader

from echovoice_ml.export import export_onnx
from echovoice_ml.model import build_model
from echovoice_ml.phoneme_map import PhonemeMap
from echovoice_ml.trainer import PhonemeDataset, Trainer, ctc_collate, load_corpus


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--epochs", type=int, default=15)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--learning-rate", type=float, default=1e-3)
    parser.add_argument("--device", default="cpu")
    parser.add_argument("--val-split", type=float, default=0.15)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument(
        "--encoder",
        choices=["gru", "whisper"],
        default="whisper",
        help="'gru' = original baseline; 'whisper' = Whisper encoder + CTC head",
    )
    parser.add_argument(
        "--whisper-model-id",
        default="openai/whisper-tiny.en",
        help="HF Hub id, local dir, or 'stub' for a downloadable Whisper encoder "
        "(e.g. openai/whisper-tiny.en, openai/whisper-tiny, distil-whisper/distil-small.en)",
    )
    parser.add_argument(
        "--freeze-encoder",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="freeze all Whisper encoder weights (default: on)",
    )
    parser.add_argument(
        "--unfreeze-last",
        type=int,
        default=0,
        help="re-enable training on the last N Whisper encoder blocks",
    )
    parser.add_argument(
        "--quantize",
        choices=["none", "int8"],
        default="none",
        help="apply torch int8 dynamic quantization to the encoder (CPU only)",
    )
    args = parser.parse_args()

    import torch

    torch.manual_seed(args.seed)

    features, labels, _words = load_corpus(args.corpus)
    phoneme_map = PhonemeMap()
    model = build_model(
        num_mel_bins=features.shape[-1],
        encoder=args.encoder,
        whisper_model_id=args.whisper_model_id,
        freeze_encoder=args.freeze_encoder,
        unfreeze_last=args.unfreeze_last,
        quantize=args.quantize,
    )
    print(
        f"Model: encoder={args.encoder} "
        f"freeze_encoder={args.freeze_encoder} unfreeze_last={args.unfreeze_last} "
        f"quantize={args.quantize}"
    )

    n = len(labels)
    n_val = max(1, int(n * args.val_split))
    train_dataset = PhonemeDataset(features[:-n_val], labels[:-n_val])
    val_dataset = PhonemeDataset(features[-n_val:], labels[-n_val:])

    train_loader = DataLoader(
        train_dataset, batch_size=args.batch_size, shuffle=True, collate_fn=ctc_collate
    )
    val_loader = DataLoader(
        val_dataset, batch_size=args.batch_size, shuffle=False, collate_fn=ctc_collate
    )

    trainer = Trainer(model, phoneme_map, learning_rate=args.learning_rate, device=args.device)

    for epoch in range(1, args.epochs + 1):
        train_loss = trainer.train_epoch(train_loader)
        val_metrics = trainer.evaluate(val_loader)
        print(
            f"epoch {epoch:3d}  train_loss {train_loss:.4f}  "
            f"val_loss {val_metrics['loss']:.4f}  val_PER {val_metrics['phoneme_error_rate']:.4f}"
        )

    out_dir = Path(args.out)
    checkpoint = out_dir / "checkpoint.pt"
    trainer.save_checkpoint(checkpoint)

    spec = export_onnx(checkpoint, out_dir, device=args.device)
    print(f"Saved checkpoint + ONNX model to {out_dir.resolve()}")
    print(f"Model spec: {spec['input_shape']}")


if __name__ == "__main__":
    main()
