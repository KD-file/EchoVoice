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
import logging
import os
import sqlite3
import tempfile
import uuid
from typing import Optional

import librosa
import numpy as np
import soundfile as sf
import torch
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from transformers import AutoModelForCTC, AutoProcessor

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("echovoice-backend")

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------
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

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

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


processor, model, MODEL_SOURCE, USING_FINE_TUNED = _load_model()

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


def _decode_audio(raw_bytes: bytes) -> np.ndarray:
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
    return HealthResponse(
        status="ok",
        device=str(device),
        model_source=MODEL_SOURCE,
        fine_tuned=USING_FINE_TUNED,
    )


@app.post("/api/transcribe", response_model=TranscribeResponse)
async def transcribe(audio: UploadFile = File(...)):
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
