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
import tempfile

import librosa
import numpy as np
import soundfile as sf
import torch
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
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


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app:app", host="0.0.0.0", port=int(os.environ.get("PORT", 8000)), reload=False)
