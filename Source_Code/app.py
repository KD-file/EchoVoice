# -*- coding: utf-8 -*-
"""
EchoVoice ASR Backend
======================
Serves the HuBERT acoustic model fine-tuned on pediatric speech
(PERCEPT-GFTA, see hubert_percept_final.py) behind a small HTTP API that the
EchoVoice frontend (index.html) calls to transcribe a child's spoken attempt
at a target word.

Endpoints
---------
GET  /api/health       -> service + model status
POST /api/transcribe    -> multipart "audio" file  ->  {"transcript": "..."}

Run
---
    pip install -r requirements.txt
    export ECHOVOICE_MODEL_DIR=./hubert-bcs   # path saved by trainer.save_model()
    uvicorn app:app --host 0.0.0.0 --port 8000

See README.md for full setup instructions, including how to export the
fine-tuned checkpoint from the Colab training notebook.
"""

import io
import json
import logging
import os
import re
import sqlite3
import tempfile
import uuid
from typing import List, Optional

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("echovoice-backend")

# --------------------------------------------------------------------------
# Grapheme-to-phoneme (single source of truth for PER)
# --------------------------------------------------------------------------
# The trainer (hubert_percept_final.py) derives reference/hypothesis phonemes
# with g2p_en -> ARPAbet, stripping stress digits. Scoring MUST use the same
# inventory, otherwise app PER is not comparable to the validated PER and the
# ICC against SLP ratings measures G2P noise instead of pronunciation ability.
#
# So phonemization lives here, not in the browser:
#   1. bundled dictionary (generated from g2p_en/CMUdict) - deterministic,
#      offline, no nltk needed at runtime
#   2. g2p_en library - used for any word outside the bundled dictionary
# Both paths emit the same ARPAbet symbols, so train/serve parity holds.
_BUNDLED_PHONEMES_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "phonemes.json"
)

try:
    with open(_BUNDLED_PHONEMES_PATH, encoding="utf-8") as _fh:
        _BUNDLED = json.load(_fh)
    BUNDLED_PHONEMES: dict = {
        w.lower(): list(p) for w, p in _BUNDLED.get("words", {}).items()
    }
except Exception as exc:  # pragma: no cover - depends on deployment
    logger.warning("Bundled phoneme dictionary unavailable: %s", exc)
    BUNDLED_PHONEMES = {}

try:
    from g2p_en import G2p as _G2p

    _G2P_ENGINE = _G2p()
    G2P_AVAILABLE = True
except Exception as exc:  # pragma: no cover - depends on environment
    _G2P_ENGINE = None
    G2P_AVAILABLE = False
    logger.warning(
        "g2p_en unavailable (%s); phonemization limited to the %d bundled words",
        exc,
        len(BUNDLED_PHONEMES),
    )

# Punctuation/stress that must never appear in a scored phoneme sequence.
_PHONE_STRIP_RE = re.compile(r"^[.,!?;:'\"\-]+$")


def phonemize(text: str) -> tuple[List[str], str]:
    """Convert text to ARPAbet phonemes.

    Returns (phonemes, source) where source is "bundled" or "g2p_en".
    Raises ValueError when the text cannot be phonemized at all.
    """
    cleaned = (text or "").strip().lower()
    if not cleaned:
        return [], "bundled"

    hit = BUNDLED_PHONEMES.get(cleaned)
    if hit:
        return list(hit), "bundled"

    if _G2P_ENGINE is not None:
        phones = [
            re.sub(r"\d", "", p)
            for p in _G2P_ENGINE(cleaned)
            if p.strip() and not _PHONE_STRIP_RE.match(p.strip())
        ]
        if phones:
            return phones, "g2p_en"

    raise ValueError(
        f"No phonemizer available for '{text}'. Install g2p_en or add the word "
        "to phonemes.json."
    )


def phonemizer_status() -> dict:
    return {
        "g2p_available": G2P_AVAILABLE,
        "bundled_words": len(BUNDLED_PHONEMES),
        "phonemizer_inventory": "ARPAbet (g2p_en / CMUdict), stress stripped",
    }

# --------------------------------------------------------------------------
# Optional machine-learning stack
# --------------------------------------------------------------------------
# The acoustic model is optional and off by default: the frontend transcribes
# with the browser's Web Speech API, so the backend only has to phonemize and
# serve profiles. When ECHOVOICE_ENABLE_ASR is not set we never import
# torch/transformers, which keeps a fresh install light and startup instant.
# The profile/session APIs must keep working even when the model cannot be
# loaded (checkpoint missing, no network, or torch/transformers not installed),
# so every import stays guarded and /api/transcribe reports 503 instead.
ASR_ENABLED = os.environ.get("ECHOVOICE_ENABLE_ASR", "0").strip().lower() in (
    "1",
    "true",
    "yes",
    "on",
)

ML_DEPS_OK = False
librosa = np = sf = torch = AutoModelForCTC = AutoProcessor = None

if ASR_ENABLED:
    try:
        import librosa
        import numpy as np
        import soundfile as sf
        import torch
        from transformers import AutoModelForCTC, AutoProcessor
        ML_DEPS_OK = True
    except Exception as exc:  # pragma: no cover - depends on environment
        logger.warning("ML dependencies unavailable; running without the ASR model: %s", exc)

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------
# The acoustic model is OPTIONAL and disabled by default. The frontend
# transcribes with the browser's Web Speech API, so the only backend work that
# is genuinely required is phonemization (g2p_en) plus the profile/session
# APIs. Set ECHOVOICE_ENABLE_ASR=1 to additionally serve /api/transcribe from a
# HuBERT checkpoint; without it torch/transformers are never imported and the
# service starts instantly with no multi-gigabyte download.
#
# Directory where trainer.save_model()/trainer.save_pretrained() wrote the
# fine-tuned checkpoint (this is training_args.output_dir, "./hubert-bcs",
# in hubert_percept_final.py). Override with the ECHOVOICE_MODEL_DIR env var.
FINE_TUNED_MODEL_DIR = os.environ.get("ECHOVOICE_MODEL_DIR", "./hubert-bcs")

# Used only if no fine-tuned checkpoint is found, so the API still starts
# during development. Real deployments should always point
# ECHOVOICE_MODEL_DIR at the child-speech fine-tuned weights.
BASE_MODEL_ID = "facebook/hubert-large-ls960-ft"

TARGET_SAMPLE_RATE = 16000

# Comma-separated list of allowed origins, e.g. "https://myapp.com,http://localhost:5500"
ALLOWED_ORIGINS = [o.strip() for o in os.environ.get("ECHOVOICE_CORS_ORIGINS", "*").split(",")]

device = torch.device("cuda" if torch.cuda.is_available() else "cpu") if torch is not None else None

# SQLite database that stores child profiles (and, going forward, sessions and
# attempts per Data_Schema/schema.sql). Override with the ECHOVOICE_DB_PATH
# env var to keep the file elsewhere.
DB_PATH = os.environ.get(
    "ECHOVOICE_DB_PATH",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "echovoice.db"),
)


def _get_db_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def _init_db():
    """Create profile/session tables (subset of Data_Schema/schema.sql)."""
    with _get_db_conn() as conn:
        conn.execute("PRAGMA foreign_keys = ON")
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS child (
                child_id  TEXT PRIMARY KEY,
                name      TEXT DEFAULT 'Unknown',
                age_years INTEGER
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS session (
                session_id   TEXT PRIMARY KEY,
                child_id     TEXT NOT NULL REFERENCES child(child_id),
                session_date TEXT DEFAULT (date('now')),
                created_at   TEXT NOT NULL DEFAULT (datetime('now'))
            )
            """
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_session_child ON session(child_id)"
        )


_init_db()


def _load_model():
    """Load the fine-tuned checkpoint (preferred) or the base HuBERT model.

    Returns (processor, model, model_source, using_fine_tuned). Returns
    (None, None, source, False) whenever the model is not being served -- ASR
    disabled, ML stack missing, or weights unavailable -- so phonemization and
    the profile APIs keep working and /api/transcribe answers 503.
    """
    if not ASR_ENABLED:
        logger.info(
            "ECHOVOICE_ENABLE_ASR is not set; skipping the acoustic model "
            "entirely. The frontend uses the browser Web Speech API instead."
        )
        return None, None, "disabled", False

    if not ML_DEPS_OK:
        return None, None, BASE_MODEL_ID, False

    has_checkpoint = os.path.isdir(FINE_TUNED_MODEL_DIR) and bool(os.listdir(FINE_TUNED_MODEL_DIR))
    model_source = FINE_TUNED_MODEL_DIR if has_checkpoint else BASE_MODEL_ID

    if has_checkpoint:
        logger.info("Loading fine-tuned EchoVoice/HuBERT checkpoint from '%s'", model_source)
    else:
        logger.warning(
            "No fine-tuned checkpoint found at '%s'. Falling back to the base "
            "pretrained model '%s', which was NOT trained on children's speech. "
            "Run hubert_percept_final.py, then set ECHOVOICE_MODEL_DIR to its "
            "saved output directory before deploying.",
            FINE_TUNED_MODEL_DIR,
            BASE_MODEL_ID,
        )

    processor = AutoProcessor.from_pretrained(model_source)
    model = AutoModelForCTC.from_pretrained(model_source)
    model.to(device)
    model.eval()
    return processor, model, model_source, has_checkpoint


try:
    processor, model, MODEL_SOURCE, USING_FINE_TUNED = _load_model()
    # Only advertise the model when weights are actually resident. Previously
    # this was unconditionally True, so /api/health claimed a working ASR even
    # when the ML stack was missing and _load_model returned None.
    MODEL_AVAILABLE = processor is not None and model is not None
except Exception as exc:
    logger.exception("Failed to load the acoustic model; transcription disabled")
    processor = model = None
    MODEL_SOURCE = BASE_MODEL_ID
    USING_FINE_TUNED = False
    MODEL_AVAILABLE = False

app = FastAPI(title="EchoVoice ASR Backend", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class TranscribeResponse(BaseModel):
    transcript: str
    model_source: str
    fine_tuned: bool


class HealthResponse(BaseModel):
    status: str
    device: str
    model_source: str
    fine_tuned: bool
    model_available: bool
    asr_enabled: bool
    g2p_available: bool
    bundled_words: int
    phonemizer_inventory: str


class PhonemizeRequest(BaseModel):
    text: str


class PhonemizeResponse(BaseModel):
    text: str
    phonemes: List[str]
    source: str


class ProfileSaveRequest(BaseModel):
    child_id: Optional[str] = None
    name: str
    age_years: Optional[int] = Field(None, ge=0, le=20)
    session_date: Optional[str] = None


class ProfileResponse(BaseModel):
    child_id: str
    name: str
    age_years: Optional[int] = None
    session_id: Optional[str] = None
    session_date: Optional[str] = None


def _decode_audio(raw_bytes: bytes):
    """Decode browser-recorded audio (webm/ogg/wav/etc.) into a mono
    float32 waveform resampled to TARGET_SAMPLE_RATE.

    soundfile handles wav/flac directly; MediaRecorder in the browser
    typically produces webm/opus, which soundfile can't read, so we fall
    back to librosa (via audioread/ffmpeg) for those containers.
    """
    try:
        with io.BytesIO(raw_bytes) as buf:
            waveform, sr = sf.read(buf, dtype="float32")
    except Exception:
        with tempfile.NamedTemporaryFile(suffix=".webm", delete=True) as tmp:
            tmp.write(raw_bytes)
            tmp.flush()
            waveform, sr = librosa.load(tmp.name, sr=None, mono=True)

    if waveform.ndim > 1:
        waveform = np.mean(waveform, axis=1)

    if sr != TARGET_SAMPLE_RATE:
        waveform = librosa.resample(waveform, orig_sr=sr, target_sr=TARGET_SAMPLE_RATE)

    return waveform.astype(np.float32)


@app.get("/api/health", response_model=HealthResponse)
def health():
    # "ok" means the service can do its job. Phonemization and the profile
    # APIs are the required half; the acoustic model is an optional extra, so
    # its absence is reported but is not a degraded service.
    return HealthResponse(
        status="ok",
        device=str(device) if torch is not None else "not used",
        model_source=MODEL_SOURCE,
        fine_tuned=USING_FINE_TUNED,
        model_available=MODEL_AVAILABLE,
        asr_enabled=ASR_ENABLED,
        **phonemizer_status(),
    )


@app.post("/api/phonemize", response_model=PhonemizeResponse)
def phonemize_endpoint(req: PhonemizeRequest):
    """Convert text to ARPAbet phonemes using the training-time inventory.

    The frontend calls this for BOTH the target word and the ASR hypothesis so
    that PER is always computed against the same reference phonemes the trainer
    used (g2p_en / CMUdict, stress digits stripped).
    """
    try:
        phonemes, source = phonemize(req.text)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return PhonemizeResponse(text=req.text.strip().lower(), phonemes=phonemes, source=source)


@app.post("/api/transcribe", response_model=TranscribeResponse)
async def transcribe(audio: UploadFile = File(...)):
    if not MODEL_AVAILABLE:
        raise HTTPException(
            status_code=503,
            detail=(
                "ASR is disabled (ECHOVOICE_ENABLE_ASR=0) or the model failed to "
                "load. The frontend falls back to the browser Web Speech API, or "
                "to a clearly labelled simulation if that is unavailable too."
            ),
        )

    raw_bytes = await audio.read()
    if not raw_bytes:
        raise HTTPException(status_code=400, detail="Empty audio upload.")

    try:
        waveform = _decode_audio(raw_bytes)
    except Exception as exc:
        logger.exception("Failed to decode uploaded audio")
        raise HTTPException(status_code=400, detail=f"Could not decode audio: {exc}") from exc

    if waveform.size == 0:
        raise HTTPException(status_code=400, detail="Decoded audio was empty.")

    inputs = processor(waveform, sampling_rate=TARGET_SAMPLE_RATE, return_tensors="pt", padding=True)
    input_values = inputs.input_values.to(device)

    with torch.no_grad():
        logits = model(input_values).logits

    predicted_ids = torch.argmax(logits, dim=-1)
    transcript = processor.batch_decode(predicted_ids)[0].strip().lower()

    return TranscribeResponse(
        transcript=transcript,
        model_source=MODEL_SOURCE,
        fine_tuned=USING_FINE_TUNED,
    )


@app.post("/api/profile", response_model=ProfileResponse)
def save_profile(req: ProfileSaveRequest):
    """Create or update a child profile and (optionally) record a session."""
    name = (req.name or "").strip()
    if not name:
        raise HTTPException(status_code=400, detail="Profile name is required.")

    conn = _get_db_conn()
    try:
        with conn:
            if req.child_id:
                row = conn.execute(
                    "SELECT child_id FROM child WHERE child_id = ?",
                    (req.child_id,),
                ).fetchone()
                if row is None:
                    raise HTTPException(
                        status_code=404,
                        detail=f"Child '{req.child_id}' not found.",
                    )
                child_id = req.child_id
                conn.execute(
                    "UPDATE child SET name = ?, age_years = ? WHERE child_id = ?",
                    (name, req.age_years, child_id),
                )
            else:
                child_id = uuid.uuid4().hex
                conn.execute(
                    "INSERT INTO child (child_id, name, age_years) VALUES (?, ?, ?)",
                    (child_id, name, req.age_years),
                )

            session_id = None
            if req.session_date:
                row = conn.execute(
                    "SELECT session_id FROM session WHERE child_id = ? AND session_date = ? "
                    "ORDER BY created_at DESC LIMIT 1",
                    (child_id, req.session_date),
                ).fetchone()
                if row:
                    session_id = row["session_id"]
                else:
                    session_id = uuid.uuid4().hex
                    conn.execute(
                        "INSERT INTO session (session_id, child_id, session_date) VALUES (?, ?, ?)",
                        (session_id, child_id, req.session_date),
                    )
    finally:
        conn.close()

    return ProfileResponse(
        child_id=child_id,
        name=name,
        age_years=req.age_years,
        session_id=session_id,
        session_date=req.session_date,
    )


@app.get("/api/profile", response_model=ProfileResponse)
def get_profile():
    """Return the most recently created child profile plus latest session."""
    conn = _get_db_conn()
    try:
        row = conn.execute("SELECT * FROM child ORDER BY rowid DESC LIMIT 1").fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="No profile saved yet.")

        sess = conn.execute(
            "SELECT session_id, session_date FROM session WHERE child_id = ? "
            "ORDER BY created_at DESC LIMIT 1",
            (row["child_id"],),
        ).fetchone()

        return ProfileResponse(
            child_id=row["child_id"],
            name=row["name"],
            age_years=row["age_years"],
            session_id=sess["session_id"] if sess else None,
            session_date=sess["session_date"] if sess else None,
        )
    finally:
        conn.close()


@app.get("/api/profiles")
def list_profiles():
    """List all saved child profiles (id, name, age)."""
    conn = _get_db_conn()
    try:
        rows = conn.execute(
            "SELECT child_id, name, age_years FROM child ORDER BY rowid DESC"
        ).fetchall()
        return {"profiles": [dict(r) for r in rows]}
    finally:
        conn.close()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app:app", host="0.0.0.0", port=int(os.environ.get("PORT", 8000)), reload=False)
