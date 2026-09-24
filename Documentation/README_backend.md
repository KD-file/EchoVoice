# EchoVoice ASR Backend

A small FastAPI service that puts the HuBERT model fine-tuned in
`hubert_percept_final.py` (PERCEPT-GFTA children's speech) behind an HTTP API,
so `index.html` can send a recorded audio clip and get back a transcript
instead of relying on the browser's built-in Web Speech API.

```
Browser (index.html)  --MediaRecorder audio-->  POST /api/transcribe  -->  HuBERT (fine-tuned)  -->  {"transcript": "..."}
```

Everything downstream of the transcript — WER, PER, phoneme alignment,
history, the PDF report — still runs client-side in `index.html`, exactly as
before. This backend's only job is turning audio into text with the
child-speech model instead of a generic browser ASR.

## 1. Get the fine-tuned checkpoint out of the notebook

`hubert_percept_final.py` trains with:

```python
training_args = TrainingArguments(output_dir="./hubert-bcs", ...)
trainer = Trainer(model=model, args=training_args, ...)
trainer.train()
```

`load_best_model_at_end=True` means the best checkpoint is already loaded
into `trainer.model` after `trainer.train()` finishes. Add this once, at the
end of the notebook (before/after evaluation), to save a clean, loadable
checkpoint:

```python
trainer.save_model("./hubert-bcs")       # weights + config
processor.save_pretrained("./hubert-bcs")  # tokenizer/feature extractor
```

Then download the whole `./hubert-bcs` folder from Colab (zip it, or copy it
to Google Drive) onto the machine that will run this backend.

## 2. Install dependencies

```bash
cd Source_Code                              # app.py lives in Source_Code/
python -m venv ../.venv && source ../.venv/bin/activate   # optional but recommended
pip install -r ../Dependencies_Environment/requirements.txt
```

You'll also need `ffmpeg` on the system PATH (used to decode the
webm/opus audio the browser records):

```bash
# Debian/Ubuntu
sudo apt-get install -y ffmpeg
# macOS
brew install ffmpeg
```

## 3. Run the server

```bash
export ECHOVOICE_MODEL_DIR=/absolute/path/to/hubert-bcs   # the folder from step 1
export ECHOVOICE_CORS_ORIGINS="*"   # or e.g. "https://your-frontend-domain.com"
uvicorn app:app --host 0.0.0.0 --port 8000   # run from inside Source_Code/
```

If `ECHOVOICE_MODEL_DIR` isn't set or doesn't contain a checkpoint, the
server logs a warning and falls back to the public
`facebook/hubert-large-ls960-ft` weights so it still starts up — but those
weights were **not** trained on children's speech, so transcripts will be
noticeably worse. Always point it at your fine-tuned checkpoint for real use.

Check it's up:

```bash
curl http://localhost:8000/api/health
# {"status":"ok","device":"cuda","model_source":"/abs/path/hubert-bcs","fine_tuned":true}
```

## 4. Point the frontend at it

`index.html` has been updated to call this API. Near the top of its
`<script>` block:

```js
const ECHOVOICE_BACKEND_URL = 'http://localhost:8000';
```

Change this to wherever you deploy the backend (e.g. an EC2/Render/Fly.io
URL). If the frontend is served from a different origin than the backend,
make sure `ECHOVOICE_CORS_ORIGINS` on the server includes that origin.

## 5. Deploying

- **GPU strongly recommended** for low-latency inference with HuBERT-Large;
  CPU works but each transcription can take a few seconds.
- Put this behind HTTPS (e.g. via a reverse proxy like nginx/Caddy, or a
  managed host) before using it outside `localhost`, since the manuscript's
  data-handling requirements call for TLS in transit.
- The service is stateless — no audio or transcripts are persisted server
  side. All session history stays in the browser's `localStorage`, as in the
  original app.

## API reference

### `GET /api/health`
Returns service status, inference device, which model is loaded, and whether
it's the fine-tuned checkpoint or the fallback base model.

### `POST /api/transcribe`
Multipart form upload, field name `audio` (any format ffmpeg/soundfile can
decode — webm, ogg, wav, m4a, ...).

Response:
```json
{
  "transcript": "kaet",
  "model_source": "/abs/path/hubert-bcs",
  "fine_tuned": true
}
```

Errors return `400` with a `detail` message (e.g. empty upload, undecodable
audio).
