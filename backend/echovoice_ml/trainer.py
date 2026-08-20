"""Training utilities: dataset, collate, and the training loop."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import Dataset
from torch.utils.data.dataloader import default_collate

from .model import AcousticModel, build_model
from .phoneme_map import PhonemeMap


@dataclass
class Corpus:
    """Prepared corpus (output of scripts/prepare_corpus.py)."""

    features_path: Path
    labels_path: Path
    manifest_path: Path
    num_features: int
    max_frames: int
    num_mel_bins: int


def load_corpus(dirpath: Path) -> Tuple[np.ndarray, List[List[int]], List[str]]:
    """Loads features.npz + labels.json + manifest.jsonl from a prepared dir.

    Returns (features: float32 [N, max_frames, mel], labels, word_ids).
    """
    dirpath = Path(dirpath)
    features = np.load(dirpath / "features.npz", allow_pickle=False)["features"]
    with open(dirpath / "labels.json", encoding="utf-8") as fh:
        labels = json.load(fh)  # list of list[int]
    words = [
        line.strip().split("\t")[0]
        for line in (dirpath / "manifest.jsonl").read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    return features, [list(x) for x in labels], words


class PhonemeDataset(Dataset):
    """Wraps the prepared feature tensor + label sequences."""

    def __init__(
        self,
        features: np.ndarray,
        labels: List[List[int]],
        length_padding: int = 8,
    ) -> None:
        if len(features) != len(labels):
            raise ValueError("features and labels length mismatch.")
        self.features = features
        self.labels = labels
        self.length_padding = length_padding

    def __len__(self) -> int:
        return len(self.features)

    def __getitem__(self, idx: int) -> Tuple[torch.Tensor, torch.Tensor]:
        feat = torch.from_numpy(self.features[idx]).float()  # [T, mel]
        length = self._padded_length(feat.shape[0])
        feat = feat[:length]  # discard padding beyond the real length
        label = torch.tensor(self.labels[idx], dtype=torch.long)
        return feat, label

    def _padded_length(self, actual: int) -> int:
        if self.length_padding <= 1:
            return actual
        return max(self.length_padding, int(np.ceil(actual / self.length_padding) * self.length_padding))


def ctc_collate(batch: List[Tuple[torch.Tensor, torch.Tensor]]) -> Tuple[torch.Tensor, torch.Tensor, torch.Tensor, torch.Tensor]:
    """Collates variable-length features into a padded batch.

    Returns (features [B, T, mel], input_lengths [B], targets, target_lengths [B]).
    """
    features, targets = zip(*batch)
    max_len = max(f.shape[0] for f in features)
    mel = features[0].shape[-1]
    padded = torch.zeros((len(features), max_len, mel), dtype=torch.float32)
    for i, f in enumerate(features):
        padded[i, : f.shape[0]] = f
    input_lengths = torch.tensor([f.shape[0] for f in features], dtype=torch.long)
    target_lengths = torch.tensor([len(t) for t in targets], dtype=torch.long)
    flattened = torch.cat(list(targets), dim=0)
    return padded, input_lengths, flattened, target_lengths


class Trainer:
    """Minimal, dependency-light training loop with CTC loss."""

    def __init__(
        self,
        model: AcousticModel,
        phoneme_map: PhonemeMap,
        learning_rate: float = 1e-3,
        device: str | torch.device = "cpu",
    ) -> None:
        self.model = model.to(device)
        self.phoneme_map = phoneme_map
        self.device = torch.device(device)
        self.criterion = nn.CTCLoss(blank=self.phoneme_map.vocab_size - 1, zero_infinity=True)
        # Frozen encoder params (requires_grad False) are excluded so the
        # optimizer only touches the trainable projection / CTC head.
        trainable = [p for p in model.parameters() if p.requires_grad]
        if not trainable:
            raise ValueError("Model has no trainable parameters.")
        self.optimizer = torch.optim.Adam(trainable, lr=learning_rate)

    def train_epoch(self, loader: torch.utils.data.DataLoader) -> float:
        self.model.train()
        total_loss = 0.0
        num_batches = 0
        for features, input_lengths, targets, target_lengths in loader:
            features = features.to(self.device)
            input_lengths = input_lengths.to(self.device)
            targets = targets.to(self.device)
            target_lengths = target_lengths.to(self.device)

            # CTC loss requires log-probabilities, not raw logits.
            logits = self.model(features, log_probs=True)  # [T', B, vocab]
            loss = self.criterion(
                logits,
                targets,
                self.model.output_length(input_lengths),
                target_lengths,
            )
            self.optimizer.zero_grad()
            loss.backward()
            torch.nn.utils.clip_grad_norm_(self.model.parameters(), 5.0)
            self.optimizer.step()

            total_loss += loss.item()
            num_batches += 1
        return total_loss / max(num_batches, 1)

    @torch.no_grad()
    def evaluate(self, loader: torch.utils.data.DataLoader) -> Dict[str, float]:
        self.model.eval()
        total_loss = 0.0
        num_batches = 0
        total_ph = 0
        errors = 0
        for features, input_lengths, targets, target_lengths in loader:
            features = features.to(self.device)
            input_lengths = input_lengths.to(self.device)
            targets = targets.to(self.device)
            target_lengths = target_lengths.to(self.device)

            logits = self.model(features, log_probs=True)
            loss = self.criterion(
                logits,
                targets,
                self.model.output_length(input_lengths),
                target_lengths,
            )
            total_loss += loss.item()
            num_batches += 1

            # Greedy decode and compare against targets (PER).
            sequences = greedy_from_logits(logits, self.phoneme_map.vocab_size - 1)
            start = 0
            for i, tlen in enumerate(target_lengths.tolist()):
                ref = targets[start : start + tlen].tolist()
                start += tlen
                total_ph += len(ref)
                errors += _edit_distance(sequences[i], ref)
        return {
            "loss": total_loss / max(num_batches, 1),
            "phoneme_error_rate": errors / max(total_ph, 1),
        }

    def save_checkpoint(self, path: Path) -> None:
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        model = self.model
        if model.model_type == "whisper":
            config = {
                "model_type": "whisper",
                "num_mel_bins": model.num_mel_bins,
                "vocab_size": model.vocab_size,
                "whisper_model_id": getattr(
                    model, "whisper_model_id", "openai/whisper-tiny.en"
                ),
                "freeze_encoder": bool(getattr(model, "freeze_encoder", True)),
                "unfreeze_last": int(getattr(model, "unfreeze_last", 0)),
                "quantize": getattr(model, "quantize", "none"),
            }
        else:
            config = {
                "model_type": "gru",
                "num_mel_bins": model.num_mel_bins,
                "vocab_size": model.vocab_size,
                "conv_channels": model.conv_stack[0].out_channels,
                "rnn_hidden": model.rnn.hidden_size,
                "rnn_layers": model.rnn.num_layers,
            }
        torch.save(
            {
                "model_state": model.state_dict(),
                "model_config": config,
                "phonemes": self.phoneme_map.phonemes,
            },
            str(path),
        )

    @classmethod
    def load_checkpoint(cls, path: Path, device: str = "cpu"):
        path = Path(path)
        ckpt = torch.load(str(path), map_location=device)
        cfg = ckpt["model_config"]
        model_type = cfg.get("model_type", "gru")
        if model_type == "whisper":
            model = build_model(
                num_mel_bins=cfg["num_mel_bins"],
                vocab_size=cfg["vocab_size"],
                encoder="whisper",
                whisper_model_id=cfg.get(
                    "whisper_model_id", "openai/whisper-tiny.en"
                ),
                freeze_encoder=cfg.get("freeze_encoder", True),
                unfreeze_last=cfg.get("unfreeze_last", 0),
                quantize=cfg.get("quantize", "none"),
                device=device,
            )
        else:
            model = build_model(
                num_mel_bins=cfg["num_mel_bins"],
                vocab_size=cfg["vocab_size"],
                encoder="gru",
                conv_channels=cfg["conv_channels"],
                rnn_hidden=cfg["rnn_hidden"],
                rnn_layers=cfg["rnn_layers"],
            )
        model.load_state_dict(ckpt["model_state"])
        model.to(device)
        model.eval()
        phoneme_map = PhonemeMap(ckpt["phonemes"])
        return model, phoneme_map


def greedy_from_logits(logits: torch.Tensor, blank_index: int) -> List[List[int]]:
    """Greedy decode of a [T, B, vocab] logits tensor."""
    from .model import greedy_decode

    return greedy_decode(logits, blank_index=blank_index)


def _edit_distance(a: List[int], b: List[int]) -> int:
    m, n = len(a), len(b)
    dp = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(m + 1):
        dp[i][0] = i
    for j in range(n + 1):
        dp[0][j] = j
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            dp[i][j] = min(
                dp[i - 1][j] + 1,
                dp[i][j - 1] + 1,
                dp[i - 1][j - 1] + (0 if a[i - 1] == b[j - 1] else 1),
            )
    return dp[m][n]
