# Data Dictionary — EchoVoice

Covers the logical entities from `06_erd.md`, the physical JSON structures
actually used by `index.html` today, and the API payloads exchanged with the
backend in `Source_Code/app.py`.

---

## 1. Logical Entities (ERD)

### CATEGORY

| Field | Type | Description | Constraints |
|---|---|---|---|
| category_id | string | Unique identifier | PK |
| name | string | Display name, e.g. "Animals", "Food" | Not null |

### WORD

| Field | Type | Description | Constraints |
|---|---|---|---|
| word_id | string | Unique identifier | PK |
| category_id | string | Owning category | FK → CATEGORY |
| text | string | Target word, e.g. "cat" | Not null |
| ipa | string | IPA transcription, e.g. "/kæt/" | Not null |
| phonemes_json | string (JSON array) | Ordered phoneme list, e.g. `["k","æ","t"]` | Not null |

### CHILD

| Field | Type | Description | Constraints |
|---|---|---|---|
| child_id | string | Unique identifier | PK |
| name | string | Child's name as entered by examiner | Optional (defaults to "Unknown") |
| age_years | int | Child's age | Optional (defaults to "—") |

### SESSION

| Field | Type | Description | Constraints |
|---|---|---|---|
| session_id | string | Unique identifier | PK |
| child_id | string | Owning child | FK → CHILD |
| session_date | date | Date selected on the Report tab (`#sessionDate`) | Defaults to today |
| created_at | datetime | When the session started | Not null |

### ASR_MODEL

| Field | Type | Description | Constraints |
|---|---|---|---|
| model_id | string | Unique identifier | PK |
| model_source | string | Path or hub ID the backend loaded, e.g. `./hubert-bcs` | Not null |
| fine_tuned | boolean | `true` if the child-speech checkpoint was used, `false` if the base fallback was used | Not null |
| version_label | string | Optional human label (e.g. checkpoint date) | Optional |

### ATTEMPT

| Field | Type | Description | Constraints |
|---|---|---|---|
| attempt_id | string | Unique identifier | PK |
| session_id | string | Owning session | FK → SESSION |
| word_id | string | Target word attempted | FK → WORD |
| model_id | string | Model that produced the transcript | FK → ASR_MODEL |
| timestamp | datetime | When the attempt was scored | Not null |
| spoken_text | string | Lowercased ASR transcript | Not null (may be empty string on failed attempts) |
| wer_percent | float | Word Error Rate, 0-100+ | ≥ 0 |
| per_percent | float | Phoneme Error Rate, 0-100+ | ≥ 0 |
| accuracy_sacc | float | Pronunciation accuracy score, 0-100 | 0 ≤ value ≤ 100 |
| substitutions | int | Phoneme substitutions (Sp) | ≥ 0 |
| deletions | int | Phoneme deletions (Dp) | ≥ 0 |
| insertions | int | Phoneme insertions (Ip) | ≥ 0 |

### PHONEME_ALIGNMENT

| Field | Type | Description | Constraints |
|---|---|---|---|
| alignment_id | string | Unique identifier | PK |
| attempt_id | string | Owning attempt | FK → ATTEMPT |
| position | int | Order within the alignment sequence | ≥ 0 |
| ref_phoneme | string, nullable | Reference (target) phoneme; null for a pure insertion | — |
| hyp_phoneme | string, nullable | Hypothesis (spoken) phoneme; null for a pure deletion | — |
| alignment_type | enum | One of `correct`, `substitution`, `deletion`, `insertion` | Not null |

### ASSESSMENT_REPORT

| Field | Type | Description | Constraints |
|---|---|---|---|
| report_id | string | Unique identifier | PK |
| session_id | string | Session it summarizes | FK → SESSION |
| generated_at | datetime | When the PDF was built | Not null |
| file_name | string | e.g. `EchoVoice_Report_Juan_2026-09-25.pdf` | Not null |
| avg_wer | float | Session-wide mean WER | ≥ 0 |
| avg_per | float | Session-wide mean PER | ≥ 0 |

---

## 2. Physical Storage (current implementation)

The deployed app has no database — `CHILD`/`SESSION`/`ATTEMPT`/`PHONEME_ALIGNMENT`
above are all flattened into a single JSON array in `localStorage`.

### `WORD_BANK` (constant, embedded in `index.html`)

```json
{
  "Animals": [
    { "word": "cat", "ipa": "/kæt/", "phonemes": ["k", "æ", "t"] }
  ]
}
```

| Field | Type | Maps to ERD |
|---|---|---|
| (top-level key) | string | CATEGORY.name |
| word | string | WORD.text |
| ipa | string | WORD.ipa |
| phonemes | string[] | WORD.phonemes_json |

### `localStorage['echovoice_history']` (array of attempt entries)

```json
{
  "id": 1732500000000,
  "timestamp": "2026-09-25T10:15:00.000Z",
  "childName": "Juan",
  "childAge": "6",
  "targetWord": "cat",
  "targetIpa": "/kæt/",
  "spokenText": "kaet",
  "targetPhonemes": ["k", "æ", "t"],
  "spokenPhonemes": ["k", "ae", "t"],
  "wer": 100,
  "per": 33.3,
  "accuracy": 66.7,
  "subs": 1,
  "dels": 0,
  "ins": 0,
  "alignment": [
    { "type": "correct", "ref": "k", "hyp": "k" },
    { "type": "substitution", "ref": "æ", "hyp": "ae" },
    { "type": "correct", "ref": "t", "hyp": "t" }
  ]
}
```

| Field | Type | Maps to ERD |
|---|---|---|
| id | number (epoch ms) | ATTEMPT.attempt_id (+ implicit SESSION grouping) |
| timestamp | ISO 8601 string | ATTEMPT.timestamp |
| childName, childAge | string | CHILD.name, CHILD.age_years |
| targetWord, targetIpa | string | WORD.text, WORD.ipa |
| spokenText | string | ATTEMPT.spoken_text |
| targetPhonemes, spokenPhonemes | string[] | reference/hypothesis inputs to PHONEME_ALIGNMENT |
| wer, per, accuracy | float | ATTEMPT.wer_percent, per_percent, accuracy_sacc |
| subs, dels, ins | int | ATTEMPT.substitutions, deletions, insertions |
| alignment | object[] | PHONEME_ALIGNMENT rows (one per array element) |

> Note: `model_id`/`fine_tuned` are **not yet** captured per attempt in the
> current frontend. Recommended addition: include `model_source` and
> `fine_tuned` from the `/api/transcribe` response in each history entry, to
> fully realize the ASR_MODEL relationship in `06_erd.md`.

---

## 3. API Payloads (`Source_Code/app.py`)

### `GET /api/health` → `HealthResponse`

| Field | Type | Description |
|---|---|---|
| status | string | Always `"ok"` if the process is alive |
| device | string | `"cuda"` or `"cpu"` — inference device in use |
| model_source | string | Directory or hub ID currently loaded |
| fine_tuned | boolean | Whether the loaded model is the child-speech checkpoint |

### `POST /api/transcribe`

**Request** — `multipart/form-data`

| Field | Type | Description |
|---|---|---|
| audio | file | Recorded attempt, any container ffmpeg/soundfile can decode (webm/ogg/wav/m4a) |

**Response 200** — `TranscribeResponse`

| Field | Type | Description |
|---|---|---|
| transcript | string | Lowercased greedy-CTC decoded text |
| model_source | string | Same as health check, echoed for traceability |
| fine_tuned | boolean | Same as health check, echoed for traceability |

**Response 400** — error

| Field | Type | Description |
|---|---|---|
| detail | string | Human-readable reason (empty upload, undecodable audio, empty decoded audio) |
