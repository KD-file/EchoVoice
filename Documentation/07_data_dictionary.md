# Data Dictionary — EchoVoice

Covers the entities in `06_erd.md`, how they are stored (SQLite and localStorage, as in the manuscript and `01_DFD.md`), and the backend API in `Source_Code/app.py`.

---

## 1. Logical Entities (ERD)

### CATEGORY

| Field | Type | Description | Constraints |
|---|---|---|---|
| category_id | string | Unique identifier | PK |
| name | string | Display name, e.g. "Animals" | Not null |

### WORD

| Field | Type | Description | Constraints |
|---|---|---|---|
| word_id | string | Unique identifier | PK |
| category_id | string | Owning category | FK to CATEGORY |
| text | string | Target word, e.g. "cat" | Not null |
| ipa | string | IPA transcription, e.g. "/kæt/" | Not null |
| phonemes_json | string (JSON array) | Ordered phonemes, e.g. `["k","æ","t"]` | Not null |

### PARTICIPANT

| Field | Type | Description | Constraints |
|---|---|---|---|
| participant_id | string | Unique identifier | PK |
| participant_code | string | Anonymous code for the child. No name is stored | Not null, unique |

### SESSION

| Field | Type | Description | Constraints |
|---|---|---|---|
| session_id | string | Unique identifier | PK |
| participant_id | string | Child who practiced | FK to PARTICIPANT |
| session_code | string | Anonymized session identifier shown on reports | Not null, unique |
| started_at | datetime | When the caregiver started the session | Not null |

### ASR_MODEL

| Field | Type | Description | Constraints |
|---|---|---|---|
| model_id | string | Unique identifier | PK |
| model_source | string | Folder or hub ID the backend loaded, e.g. `./hubert-bcs` | Not null |
| fine_tuned | boolean | `true` for the child-speech checkpoint, `false` for the base fallback | Not null |
| version_label | string | Optional label, e.g. checkpoint date | Optional |

### ATTEMPT

| Field | Type | Description | Constraints |
|---|---|---|---|
| attempt_id | string | Unique identifier | PK |
| session_id | string | Owning session | FK to SESSION |
| word_id | string | Target word | FK to WORD |
| model_id | string | Model that made the transcript | FK to ASR_MODEL |
| timestamp | datetime | When the attempt was scored | Not null |
| spoken_text | string | Lowercase transcript | Not null (may be empty) |
| wer_percent | float | Word Error Rate, (Sw + Dw + Iw) / Nw × 100 | 0 or more |
| per_percent | float | Phoneme Error Rate, (Sp + Dp + Ip) / Np × 100 | 0 or more |
| accuracy_sacc | float | max(0, (Np − (Sp + Dp + Ip)) / Np) × 100 | 0 to 100 |
| substitutions | int | Phoneme substitutions (Sp) | 0 or more |
| deletions | int | Phoneme deletions (Dp) | 0 or more |
| insertions | int | Phoneme insertions (Ip) | 0 or more |

### PHONEME_ALIGNMENT

| Field | Type | Description | Constraints |
|---|---|---|---|
| alignment_id | string | Unique identifier | PK |
| attempt_id | string | Owning attempt | FK to ATTEMPT |
| position | int | Order in the alignment | 0 or more |
| ref_phoneme | string, nullable | Target phoneme. Null for an insertion | — |
| hyp_phoneme | string, nullable | Spoken phoneme. Null for a deletion | — |
| alignment_type | enum | `correct`, `substitution`, `deletion`, or `insertion` | Not null |

### REPORT

| Field | Type | Description | Constraints |
|---|---|---|---|
| report_id | string | Unique identifier | PK |
| session_id | string | Session it summarizes | FK to SESSION |
| report_type | enum | `child` or `clinician` | Not null |
| file_format | enum | `pdf` or `csv` | Not null |
| generated_at | datetime | When the file was built | Not null |

---

## 2. Physical Storage

### D1 Target Word Metadata

Words, IPA, and phonemes. Mapping:

| Field | Maps to ERD |
|---|---|
| category (key) | CATEGORY.name |
| word | WORD.text |
| ipa | WORD.ipa |
| phonemes | WORD.phonemes_json |

### D2 Session and Attempt Records (SQLite)

One table for each of PARTICIPANT, SESSION, ATTEMPT, and PHONEME_ALIGNMENT, using the fields in section 1. The phoneme error matrix for the Clinician Report is built from PHONEME_ALIGNMENT, so it is not stored separately.

### D3 Attempt History (`localStorage['echovoice_history']`)

A browser copy of each attempt, kept as a JSON array.

```json
{
  "id": 1732500000000,
  "timestamp": "2026-10-03T10:15:00.000Z",
  "participantCode": "P001",
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

| Field | Maps to ERD |
|---|---|
| id | ATTEMPT.attempt_id |
| timestamp | ATTEMPT.timestamp |
| participantCode | PARTICIPANT.participant_code |
| targetWord, targetIpa | WORD.text, WORD.ipa |
| spokenText | ATTEMPT.spoken_text |
| targetPhonemes, spokenPhonemes | Inputs to PHONEME_ALIGNMENT |
| wer, per, accuracy | ATTEMPT.wer_percent, per_percent, accuracy_sacc |
| subs, dels, ins | ATTEMPT.substitutions, deletions, insertions |
| alignment | PHONEME_ALIGNMENT rows |

Note: the older prototype stored `childName` and `childAge`. The manuscript uses an anonymized participant code and session identifier instead. Also, `model_source` and `fine_tuned` from `/api/transcribe` should be saved with each attempt so the ASR_MODEL link works.

---

## 3. API Payloads (`Source_Code/app.py`)

This is the backend as it exists now. The `/api/profile` endpoints persist participant/session records in SQLite (D2). Full per-attempt persistence (ATTEMPT, PHONEME_ALIGNMENT, REPORT) is not yet implemented in the backend.

### GET /api/health

| Field | Type | Description |
|---|---|---|
| status | string | `"ok"` if the process is running |
| device | string | `"cuda"` or `"cpu"` |
| model_source | string | Folder or hub ID currently loaded |
| fine_tuned | boolean | Whether the child-speech checkpoint is loaded |

### POST /api/transcribe

Request: `multipart/form-data`

| Field | Type | Description |
|---|---|---|
| audio | file | The recorded attempt (webm, ogg, wav, or m4a) |

Response 200

| Field | Type | Description |
|---|---|---|
| transcript | string | Lowercase grapheme transcript from greedy CTC decoding |
| model_source | string | Model that was used |
| fine_tuned | boolean | Whether it was the fine-tuned model |

Response 400

| Field | Type | Description |
|---|---|---|
| detail | string | Reason: empty upload, audio that cannot be decoded, or empty decoded audio |

### POST /api/profile

Creates or updates a participant record (upsert by `child_id`) and, if `session_date` is given, reuses or creates the session for that date.

Request: `application/json`

| Field | Type | Description |
|---|---|---|
| child_id | string, optional | Existing participant ID to update; omit to create a new one |
| name | string | Participant display name |
| age_years | int, optional (0–20) | Participant age |
| session_date | string, optional | `YYYY-MM-DD`; creates/reuses a SESSION row |

Response 200

| Field | Type | Description |
|---|---|---|
| child_id | string | Saved participant ID |
| name | string | Saved name |
| age_years | int, nullable | Saved age |
| session_id | string, nullable | Session row for the given date, if any |
| session_date | string, nullable | Date of that session |

### GET /api/profile

Returns the most recently created participant plus their latest session.

| Field | Type | Description |
|---|---|---|
| child_id | string | Participant ID |
| name | string | Participant name |
| age_years | int, nullable | Participant age |
| session_id | string, nullable | Latest session ID |
| session_date | string, nullable | Latest session date |

### GET /api/profiles

Lists all saved participants.

| Field | Type | Description |
|---|---|---|
| profiles | array | `{ child_id, name, age_years }` for each participant |
