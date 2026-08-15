"""Phoneme-level acoustic models (PyTorch).

Two interchangeable backends share the same I/O contract so that training,
evaluation and export work identically for either:

  * ``gru``  -- compact Conv1D front-end -> bidirectional GRU -> CTC head
    (the original EchoVoice baseline, kept for fast iteration / testing).
  * ``whisper`` -- a real, compressed Whisper encoder checkpoint (e.g.
    ``openai/whisper-tiny.en``, a distilled ``distil-whisper`` model, or a
    quantized export) with a small trainable input projection and a CTC
    phoneme head on top. The encoder is loaded from the Hugging Face Hub
    or a local directory and frozen by default.

Input : float32 tensor [B, T, num_mel_bins] log-mel features.
Output: logits float32 [T', B, vocab_size] (CTC / torch format), or
        log-probabilities with ``log_probs=True``.

The Whisper encoder downsamples 2x (its second conv has stride 2), so the
CTC frame count for ``T`` input frames is ``ceil(T / 2)``. Callers must go
through :meth:`AcousticModel.output_length` (or
:meth:`WhisperAcousticModel.output_length`) to pass correct CTC input
lengths.

Decoding is CTC greedy (collapse repeats + drop blanks), which the Flutter
app reproduces on-device.
"""

from __future__ import annotations

from typing import List, Optional

import torch
import torch.nn as nn

from .phoneme_map import BLANK_INDEX

# Default mel width for the dependency-free test encoder. Real Whisper
# encoders use 80 bins (tiny/base/small/medium, large v1-v2) or 128 bins
# (large-v3); the wrapper projects the EchoVoice 80-bin feature contract up
# to whatever the loaded encoder expects.
WHISPER_ENCODER_MEL_BINS = 128


class AcousticModel(nn.Module):
    """GRU baseline: Conv1D front-end -> bidirectional GRU -> CTC head."""

    model_type = "gru"

    def __init__(
        self,
        num_mel_bins: int = 80,
        vocab_size: int = 35,
        conv_channels: int = 64,
        rnn_hidden: int = 128,
        rnn_layers: int = 2,
        dropout: float = 0.2,
    ) -> None:
        super().__init__()
        self.num_mel_bins = num_mel_bins
        self.vocab_size = vocab_size

        # Convolutional front-end: local spectral/temporal context.
        self.conv_stack = nn.Sequential(
            nn.Conv1d(num_mel_bins, conv_channels, kernel_size=3, padding=1),
            nn.BatchNorm1d(conv_channels),
            nn.ReLU(),
            nn.Conv1d(conv_channels, conv_channels, kernel_size=3, padding=1),
            nn.BatchNorm1d(conv_channels),
            nn.ReLU(),
        )

        self.rnn = nn.GRU(
            input_size=conv_channels,
            hidden_size=rnn_hidden,
            num_layers=rnn_layers,
            batch_first=True,
            bidirectional=True,
            dropout=dropout if rnn_layers > 1 else 0.0,
        )
        self.projection = nn.Linear(rnn_hidden * 2, vocab_size)
        self.dropout = nn.Dropout(dropout)

    def forward(
        self, features: torch.Tensor, log_probs: bool = False
    ) -> torch.Tensor:
        """features: [B, T, mel] -> [T, B, vocab] (or log-probs)."""
        if features.ndim != 3:
            raise ValueError(f"Expected [B, T, mel], got shape {tuple(features.shape)}.")
        if features.shape[-1] != self.num_mel_bins:
            raise ValueError(
                f"Expected {self.num_mel_bins} mel bins, got {features.shape[-1]}."
            )

        b, t, _ = features.shape
        # [B, mel, T] for Conv1d
        x = features.transpose(1, 2)
        x = self.conv_stack(x)
        x = x.transpose(1, 2)  # [B, T, conv_channels]

        x, _ = self.rnn(x)
        x = self.dropout(x)
        logits = self.projection(x)  # [B, T, vocab]
        logits = logits.transpose(0, 1)  # [T, B, vocab] for torch CTC

        if log_probs:
            return torch.log_softmax(logits, dim=-1)
        return logits

    def output_length(self, n_frames: int) -> int:
        """CTC input length in model-output frames (identity here)."""
        return n_frames


# ---------------------------------------------------------------------------
# Whisper encoder backend
# ---------------------------------------------------------------------------
class _StubBlock(nn.Module):
    """Minimal pre-norm transformer block (stands in for WhisperEncoderLayer)."""

    def __init__(self, d_model: int, heads: int) -> None:
        super().__init__()
        self.self_attn = nn.MultiheadAttention(
            d_model, heads, batch_first=True, dropout=0.0
        )
        self.self_attn_layer_norm = nn.LayerNorm(d_model)
        self.fc1 = nn.Linear(d_model, d_model * 4)
        self.fc2 = nn.Linear(d_model * 4, d_model)
        self.final_layer_norm = nn.LayerNorm(d_model)

    def forward(
        self, hidden_states: torch.Tensor, attention_mask=None
    ) -> torch.Tensor:
        residual = hidden_states
        hidden_states = self.self_attn_layer_norm(hidden_states)
        attn_out, _ = self.self_attn(
            hidden_states, hidden_states, hidden_states, need_weights=False
        )
        hidden_states = residual + attn_out

        residual = hidden_states
        hidden_states = self.final_layer_norm(hidden_states)
        hidden_states = nn.functional.gelu(self.fc1(hidden_states))
        hidden_states = self.fc2(hidden_states)
        return residual + hidden_states


class _StubWhisperEncoder(nn.Module):
    """Dependency-free stand-in for a Whisper encoder (used by tests).

    Mirrors the structure the real frontend drives (conv1 -> GELU -> conv2
    stride 2 -> GELU -> positional embeddings -> transformer layers -> final
    LayerNorm) so the wrapper can be exercised without downloading a
    checkpoint.
    """

    def __init__(
        self,
        num_mel_bins: int = WHISPER_ENCODER_MEL_BINS,
        d_model: int = 64,
        layers: int = 2,
        heads: int = 4,
    ) -> None:
        super().__init__()
        self.d_model = d_model
        self.dropout = 0.0
        self.conv1 = nn.Conv1d(num_mel_bins, d_model, kernel_size=3, padding=1)
        self.conv2 = nn.Conv1d(d_model, d_model, kernel_size=3, stride=2, padding=1)
        self.embed_positions = nn.Embedding(1500, d_model)
        self.layers = nn.ModuleList([_StubBlock(d_model, heads) for _ in range(layers)])
        self.layer_norm = nn.LayerNorm(d_model)
        self.num_mel_bins = num_mel_bins

    def forward(self, features: torch.Tensor) -> torch.Tensor:
        """features: [B, T, 128] -> [B, ceil(T / 2), d_model]."""
        hidden = features.transpose(1, 2)  # [B, 128, T]
        hidden = nn.functional.gelu(self.conv1(hidden))
        hidden = nn.functional.gelu(self.conv2(hidden))
        hidden = hidden.transpose(1, 2)  # [B, T', d_model]
        positions = torch.arange(hidden.size(1), device=hidden.device)
        hidden = hidden + self.embed_positions(positions).unsqueeze(0)
        hidden = nn.functional.dropout(hidden, p=self.dropout, training=self.training)
        for layer in self.layers:
            hidden = layer(hidden, None)
        return self.layer_norm(hidden)


def _dropout_of(encoder: nn.Module):
    """The encoder's dropout config: an `nn.Dropout` (older transformers) or
    a plain float (newer transformers)."""
    dropout = getattr(encoder, "dropout", 0.0)
    return dropout if isinstance(dropout, nn.Module) else float(dropout)


class _WhisperEncoderFrontend(nn.Module):
    """Runs a loaded transformers Whisper encoder at variable length.

    The stock ``WhisperEncoder`` pads every input up to the full 30 s window
    (3000 frames / 1500 tokens) and raises on shorter inputs. We instead
    drive its submodules directly (conv1, conv2, embed_positions, layers,
    layer_norm) so the output length tracks the real input: ``ceil(T / 2)``
    tokens. This keeps the exported ONNX model variable-length and matches
    the app's 8 s / 800-frame feature contract.
    """

    def __init__(self, encoder) -> None:
        super().__init__()
        self.encoder = encoder

    @property
    def num_mel_bins(self) -> int:
        """The encoder's native mel-bin width (80 for whisper-tiny, 128 for v3)."""
        return self.encoder.conv1.in_channels

    @property
    def layers(self):
        """Exposes the wrapped encoder's transformer blocks (for unfreezing)."""
        return self.encoder.layers

    def forward(self, features: torch.Tensor) -> torch.Tensor:
        """features: [B, T, 128] -> [B, ceil(T / 2), d_model]."""
        hidden = features.transpose(1, 2)  # [B, 128, T]
        hidden = nn.functional.gelu(self.encoder.conv1(hidden))
        hidden = nn.functional.gelu(self.encoder.conv2(hidden))
        hidden = hidden.transpose(1, 2)  # [B, T', d_model]
        positions = torch.arange(hidden.size(1), device=hidden.device)
        hidden = hidden + self.encoder.embed_positions(positions).unsqueeze(0)
        hidden = nn.functional.dropout(
            hidden, p=_dropout_of(self.encoder), training=self.training
        )
        for layer in self.encoder.layers:
            hidden = layer(hidden, None)
        return self.encoder.layer_norm(hidden)


class WhisperAcousticModel(nn.Module):
    """Whisper encoder (frozen) + trainable input projection + CTC head."""

    model_type = "whisper"

    def __init__(
        self,
        encoder,
        num_mel_bins: int = 80,
        vocab_size: int = 35,
    ) -> None:
        super().__init__()
        self.encoder = encoder
        self.num_mel_bins = num_mel_bins
        self.vocab_size = vocab_size

        d_model = getattr(encoder, "d_model", None)
        if d_model is None:
            inner = getattr(encoder, "encoder", encoder)
            d_model = inner.embed_positions.weight.size(1)

        # Lifts the feature-contract mel width up to the encoder's native
        # width (80 for whisper-tiny, 128 for whisper-large-v3).
        encoder_mel_bins = getattr(encoder, "num_mel_bins", None)
        if encoder_mel_bins is None:
            inner = getattr(encoder, "encoder", encoder)
            encoder_mel_bins = inner.conv1.in_channels
        self.input_proj = nn.Sequential(
            nn.Conv1d(
                num_mel_bins, encoder_mel_bins, kernel_size=3, padding=1
            ),
            nn.GELU(),
        )
        self.head = nn.Linear(d_model, vocab_size)
        self.dropout = nn.Dropout(0.1)

    def forward(
        self, features: torch.Tensor, log_probs: bool = False
    ) -> torch.Tensor:
        """features: [B, T, mel] -> [T', B, vocab] (or log-probs)."""
        if features.ndim != 3:
            raise ValueError(f"Expected [B, T, mel], got shape {tuple(features.shape)}.")
        if features.shape[-1] != self.num_mel_bins:
            raise ValueError(
                f"Expected {self.num_mel_bins} mel bins, got {features.shape[-1]}."
            )

        # [B, mel, T] for Conv1d, then back to [B, T, 128].
        x = self.input_proj(features.transpose(1, 2)).transpose(1, 2)
        hidden = self.encoder(x)
        if isinstance(hidden, (tuple, list)):
            hidden = hidden[0]
        elif hasattr(hidden, "last_hidden_state"):
            hidden = hidden.last_hidden_state

        hidden = self.dropout(hidden)
        logits = self.head(hidden)  # [B, T', vocab]
        logits = logits.transpose(0, 1)  # [T', B, vocab] for torch CTC

        if log_probs:
            return torch.log_softmax(logits, dim=-1)
        return logits

    def output_length(self, n_frames):
        """CTC input length in encoder-output frames: ceil(n / 2)."""
        return (n_frames + 1) // 2


def _quantize_dynamic(model: nn.Module) -> nn.Module:
    """Applies torch int8 dynamic quantization to Linear layers (CPU only)."""
    try:
        from torch.ao.quantization import quantize_dynamic
    except ImportError:  # torch < 2.0
        from torch.quantization import quantize_dynamic
    return quantize_dynamic(model, {nn.Linear}, dtype=torch.qint8)


def build_whisper_model(
    num_mel_bins: int = 80,
    vocab_size: int = 35,
    whisper_model_id: str = "openai/whisper-tiny.en",
    freeze_encoder: bool = True,
    unfreeze_last: int = 0,
    quantize: str = "none",
    device: str = "cpu",
) -> WhisperAcousticModel:
    """Builds the Whisper-encoder model.

    ``whisper_model_id`` is a Hugging Face Hub id, a local directory with a
    saved Whisper model, or the literal ``"stub"`` used by tests. Distilled
    and quantized checkpoints work through the same argument (e.g.
    ``distil-whisper/distil-small.en`` or a saved int8 ONNX/HF export).

    ``freeze_encoder`` freezes all encoder weights; ``unfreeze_last`` then
    re-enables the final ``N`` encoder blocks for fine-tuning. ``quantize``
    supports ``"int8"`` (torch dynamic quantization, CPU only).
    """
    if whisper_model_id == "stub":
        encoder = _StubWhisperEncoder()
    else:
        from transformers import WhisperConfig, WhisperModel

        try:
            whisper = WhisperModel.from_pretrained(
                whisper_model_id, attn_implementation="eager"
            )
        except (TypeError, ValueError):  # transformers >= 5: set it on the config
            config = WhisperConfig.from_pretrained(whisper_model_id)
            config._attn_implementation = "eager"
            whisper = WhisperModel.from_pretrained(
                whisper_model_id, config=config
            )
        encoder = _WhisperEncoderFrontend(whisper.encoder)

    if freeze_encoder:
        for param in encoder.parameters():
            param.requires_grad_(False)
        layers = getattr(encoder, "layers", None)
        if unfreeze_last and layers is not None and len(layers) > 0:
            for layer in layers[-unfreeze_last:]:
                for param in layer.parameters():
                    param.requires_grad_(True)

    if quantize == "int8":
        encoder = _quantize_dynamic(encoder)

    model = WhisperAcousticModel(
        encoder, num_mel_bins=num_mel_bins, vocab_size=vocab_size
    )
    model.whisper_model_id = whisper_model_id
    model.freeze_encoder = bool(freeze_encoder)
    model.unfreeze_last = int(unfreeze_last)
    model.quantize = quantize
    return model


def greedy_decode(
    log_probs_or_logits: torch.Tensor, blank_index: int = BLANK_INDEX
) -> List[List[int]]:
    """CTC greedy decoding.

    Collapses consecutive repeats of the same symbol and drops blanks.
    Accepts [T, B, vocab] (torch CTC format) and returns a list of phoneme
    index sequences, one per batch element.
    """
    if log_probs_or_logits.ndim == 2:
        probs = torch.softmax(log_probs_or_logits, dim=-1)
    elif log_probs_or_logits.ndim == 3:
        probs = torch.softmax(log_probs_or_logits.transpose(0, 1), dim=-1)
    else:
        raise ValueError(f"Unexpected logits shape {tuple(log_probs_or_logits.shape)}.")

    best = probs.argmax(dim=-1)  # [B, T]
    sequences: List[List[int]] = []
    for row in best:
        decoded: List[int] = []
        prev = blank_index
        for idx in row.tolist():
            if idx != prev and idx != blank_index:
                decoded.append(int(idx))
            prev = int(idx)
        sequences.append(decoded)
    return sequences


def build_model(
    num_mel_bins: int = 80,
    vocab_size: Optional[int] = None,
    encoder: str = "gru",
    whisper_model_id: str = "openai/whisper-tiny.en",
    freeze_encoder: bool = True,
    unfreeze_last: int = 0,
    quantize: str = "none",
    conv_channels: int = 64,
    rnn_hidden: int = 128,
    rnn_layers: int = 2,
    dropout: float = 0.2,
    device: str = "cpu",
):
    """Model factory. ``encoder`` selects the backend ("gru" or "whisper").

    vocab_size defaults to phonemes + blank.
    """
    if vocab_size is None:
        from .phoneme_map import PhonemeMap

        vocab_size = PhonemeMap().vocab_size

    if encoder == "gru":
        return AcousticModel(
            num_mel_bins=num_mel_bins,
            vocab_size=vocab_size,
            conv_channels=conv_channels,
            rnn_hidden=rnn_hidden,
            rnn_layers=rnn_layers,
            dropout=dropout,
        )
    if encoder in ("whisper", "stub"):
        return build_whisper_model(
            num_mel_bins=num_mel_bins,
            vocab_size=vocab_size,
            whisper_model_id=whisper_model_id,
            freeze_encoder=freeze_encoder,
            unfreeze_last=unfreeze_last,
            quantize=quantize,
            device=device,
        )
    raise ValueError(f"Unknown encoder {encoder!r} (expected 'gru' or 'whisper').")
