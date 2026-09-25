# EchoVoice

Self-Supervised Acoustic Modeling for Phoneme-Level Error Detection in Children's Speech

EchoVoice is a phoneme-level speech assessment web app for children. A child
practices a target word from a curated word bank, records their attempt, and
the app transcribes it with a fine-tuned **HuBERT** acoustic model and scores
pronunciation using Levenshtein alignment — reporting a pronunciation accuracy
score (`Sacc`), **Word Error Rate (WER)**, **Phoneme Error Rate (PER)**, and a
phoneme-by-phoneme breakdown — then aggregates everything into a downloadable
PDF report.

- Frontend: single-page app (`Source_Code/index.html`)
- Backend: FastAPI service (`Source_Code/app.py`) exposing an ASR API backed by
  a HuBERT model fine-tuned on pediatric speech (PERCEPT-GFTA corpus)
- Training: `Source_Code/hubert_percept_final (1).py` (runs in Google Colab)

## Repository layout

| Folder | Contents |
|---|---|
| `Source_Code/` | Frontend (`index.html`), ASR backend (`app.py`), model training script |
| `Documentation/` | SAD docs (DFD, structured chart, HIPO, structured English, pseudocode, ERD, data dictionary) + config management plan |
| `Data_Schema/` | `schema.sql`, `word_bank.json`, sample attempt + API payload examples |
| `Dependencies_Environment/` | `requirements.txt` |
| `Build_Config_Scripts/` | PowerShell setup/run scripts, ffmpeg installer, checkpoint export snippet, env templates |

## Quick start (Windows)

1. **Install dependencies**

   ```powershell
   .\Build_Config_Scripts\setup_env.ps1
   ```

2. **Place the fine-tuned checkpoint** (exported via
   `Build_Config_Scripts/export_checkpoint.py` from the Colab notebook) at the
   root as `hubert-bcs\`. If present, the backend loads it; otherwise it falls
   back to the base `facebook/hubert-large-ls960-ft` weights (worse accuracy —
   not trained on children's speech).

3. **Configure** (optional)

   Copy `Build_Config_Scripts/echovoice.env.example` to
   `Build_Config_Scripts/echovoice.env` and adjust the model path, CORS
   origins, and port. `run_backend.ps1` loads this file automatically.

4. **Run the backend**

   ```powershell
   .\Build_Config_Scripts\run_backend.ps1
   ```

5. **Open the frontend** — serve `Source_Code/index.html` (e.g. VS Code Live
   Server on `http://localhost:5500`) and press the mic button.

## API

| Endpoint | Description |
|---|---|
| `GET /api/health` | Service + model status (`device`, `model_source`, `fine_tuned`) |
| `POST /api/transcribe` | Multipart `audio` upload → `{ "transcript", "model_source", "fine_tuned" }` |

## Configuration

All settings are environment variables (see `Build_Config_Scripts/echovoice.env`):

| Variable | Default | Purpose |
|---|---|---|
| `ECHOVOICE_MODEL_DIR` | `./hubert-bcs` | Fine-tuned checkpoint path |
| `ECHOVOICE_CORS_ORIGINS` | `*` | Allowed frontend origins |
| `PORT` | `8000` | Backend listen port |

## Documentation

- `Documentation/README.md` — system analysis & design overview
- `Documentation/README_backend.md` — backend setup and ASR API details
- `Documentation/01_DFD.md` … `08_configuration_management_plan.md` — full SAD
  documentation set

## Team

Kurt Daryl M. Nievera &bull; Kate Ann H. Cerezo &bull; Maica Jenish M. Doctolero &bull;
Rolando Jr. T. Gonzales &bull; Jefferson S. Paglingayen