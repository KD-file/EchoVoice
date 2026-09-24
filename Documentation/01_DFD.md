# Data Flow Diagrams (DFD) — EchoVoice

Gane–Sarson notation:

- **External entity** — a rectangle: `Child / Examinee`, `Examiner / Parent / SLP`
- **Process** — a rounded (stadium) shape, numbered `n.0`
- **Data store** — an open-ended bar, numbered `Dn`

The diagrams are **leveled** (balanced decomposition): Level 0 shows the whole
system as one process, Level 1 decomposes it into the app's main processes,
and Level 2 decomposes process 2.0 — the only process that crosses the network
to the EchoVoice ASR backend.

> **Phoneme notation.** Pronunciation is scored at the phoneme level, so the
> system needs a canonical phoneme symbol set. The lower-case symbols in the
> word bank (e.g. `k æ t` for "cat") are a simplified CMU-style **IPA subset**;
> they are the reference sequence `phonemes[]` used for PER/Sacc scoring. The
> `ipa` string (e.g. `/kæt/`) is the human-readable transcription shown on the
> word cards. Both come from `WORD_BANK` in `Source_Code/index.html`.

---

## Level 0 — Context Diagram

```mermaid
flowchart LR
    CHILD[["Child / Examinee"]]
    EXAM[["Examiner / Parent / SLP"]]
    SYS(("EchoVoice"))

    CHILD -- "spoken word attempt (audio)" --> SYS
    SYS -- "target word + IPA + TTS audio" --> CHILD
    SYS -- "Sacc / WER / PER feedback" --> CHILD

    EXAM -- "child profile (name, age)" --> SYS
    EXAM -- "session control (select word, view history)" --> SYS
    SYS -- "assessment report (PDF)" --> EXAM
    SYS -- "session history view" --> EXAM
```

| # | Flow | From → To | Description |
|---|------|-----------|--------------|
| 1 | Spoken word attempt | Child → System | Raw audio captured by the browser microphone for one target word |
| 2 | Target word prompt | System → Child | Target word, IPA transcription, and TTS pronunciation |
| 3 | Live feedback | System → Child | Sacc, WER, PER, and phoneme alignment chips for the attempt just made |
| 4 | Child profile | Examiner → System | Name and age entered before/while testing, used on the report |
| 5 | Session control | Examiner → System | Word/category selection, tab navigation, "clear history" |
| 6 | Assessment report | System → Examiner | Downloadable PDF summarizing the session |
| 7 | Session history view | System → Examiner | On-screen list of all attempts in the current browser session |

---

## Level 1 — System Decomposition

```mermaid
flowchart TB
    CHILD[["Child / Examinee"]]
    EXAM[["Examiner / Parent / SLP"]]

    P1(("1.0 Manage Practice Session"))
    P2(("2.0 Capture & Transcribe"))
    P3(("3.0 Compute Metrics"))
    P4(("4.0 Manage History"))
    P5(("5.0 Generate Report"))

    D1[("D1 Word Bank (word / IPA / phonemes)")]
    D2[("D2 Session History (localStorage)")]
    D3[("D3 Fine-tuned HuBERT")]

    CHILD -- "category / word selection" --> P1
    D1 -- "word, IPA, phonemes" --> P1
    P1 -- "target word + TTS audio" --> CHILD

    CHILD -- "recorded audio (webm)" --> P2
    P2 <-- "acoustic frames / logits" --> D3
    P2 -- "transcript text" --> P3

    P3 -- "Sacc, WER, PER, S/D/I, alignment" --> CHILD
    P3 -- "attempt record" --> P4

    P4 <-- "read / write attempts" --> D2
    EXAM -- "view / clear history" --> P4
    P4 -- "attempt list" --> EXAM

    P4 -- "all attempts" --> P5
    EXAM -- "child name/age + generate request" --> P5
    P5 -- "PDF report" --> EXAM
```

| Process | Name | Summary |
|---------|------|---------|
| 1.0 | Manage Practice Session | Renders word categories/grid from D1, handles word selection, plays TTS |
| 2.0 | Capture & Transcribe Speech Attempt | Records audio in-browser, sends it to the EchoVoice ASR backend, gets back a transcript (decomposed in Level 2) |
| 3.0 | Compute Assessment Metrics | Converts transcript to phonemes, runs Levenshtein alignment, computes Sacc/WER/PER |
| 4.0 | Manage Session History | Persists and retrieves attempt records in the browser |
| 5.0 | Generate Assessment Report | Aggregates history into a formatted PDF via jsPDF |

**Data stores**

| Store | Contents | Physical implementation |
|-------|----------|--------------------------|
| D1 Word Bank | Static list of target words, IPA strings, phoneme arrays, grouped by category | JS object `WORD_BANK` embedded in `index.html` |
| D2 Session History | Every scored attempt in the current session | Browser `localStorage`, key `echovoice_history` |
| D3 Fine-tuned Model | HuBERT-Large weights fine-tuned on PERCEPT-GFTA (BCS) | Files under the `ECHOVOICE_MODEL_DIR` folder, loaded by `app.py` at startup |

The trust boundary sits between processes **1.0/3.0/4.0/5.0** (all run in the
browser) and **2.0**, whose inner steps cross the network to the EchoVoice ASR
backend — see Level 2.

---

## Level 2 — Decomposition of Process 2.0 (Capture & Transcribe)

```mermaid
flowchart TB
    CHILD[["Child / Examinee"]]
    P3(("3.0 Compute Metrics"))
    D3[("D3 Fine-tuned HuBERT")]

    subgraph BROWSER["Browser (index.html)"]
        P21(("2.1 Record Audio (MediaRecorder)"))
        P22(("2.2 Transmit Audio (POST /api/transcribe)"))
        P27(("2.7 Return Transcript"))
    end

    subgraph BACKEND["EchoVoice ASR Backend (app.py)"]
        P23(("2.3 Decode & Resample to 16 kHz mono"))
        P24(("2.4 Extract Acoustic Features"))
        P25(("2.5 Run CTC Inference (HuBERT)"))
        P26(("2.6 Greedy CTC Decode"))
    end

    CHILD -- "microphone stream" --> P21
    P21 -- "audio blob (webm/opus)" --> P22
    P22 -- "multipart upload" --> P23
    P23 -- "waveform (float32, 16 kHz)" --> P24
    P24 -- "input_values tensor" --> P25
    P25 <-- "model weights" --> D3
    P25 -- "logits (frame x vocab)" --> P26
    P26 -- "transcript string" --> P27
    P27 -- "JSON {transcript}" --> P22
    P22 -- "spoken text" --> P3
```

| Process | Name | Where it runs | Implementation |
|---------|------|----------------|----------------|
| 2.1 | Record Audio | Browser | `navigator.mediaDevices.getUserMedia` + `MediaRecorder` capture the child's attempt |
| 2.2 | Transmit Audio | Browser → Backend | `transcribeWithBackend()` `fetch()`-POSTs the blob as multipart form data to `/api/transcribe` |
| 2.3 | Decode & Resample Audio | Backend | `_decode_audio()`: `soundfile`/`librosa` decode the container and resample to 16 kHz mono |
| 2.4 | Extract Acoustic Features | Backend | `AutoProcessor` normalizes the waveform into `input_values` |
| 2.5 | Run CTC Inference | Backend | Fine-tuned `AutoModelForCTC` (HuBERT) forward pass produces per-frame logits |
| 2.6 | Greedy CTC Decode | Backend | `argmax` over logits, then `processor.batch_decode` collapses repeats/blanks into text |
| 2.7 | Return Transcript | Backend → Browser | `handleRecordedAudio()` unpacks the JSON response and hands it to Process 3.0 |

This is the only network hop in the system; every other process (1.0, 3.0, 4.0,
5.0) executes entirely client-side in `index.html`.