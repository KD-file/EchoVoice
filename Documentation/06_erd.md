# Entity Relationship Diagram (ERD) — EchoVoice

The running app persists data only in the browser (`localStorage`), not in a
relational database — see `07_data_dictionary.md` for the exact physical JSON
shapes. This ERD is the **logical** data model those JSON structures
implement, and the model a future multi-device/clinician-facing backend
(with a real database) would use. It normalizes the current flat attempt
records into proper entities.

```mermaid
erDiagram
    CATEGORY ||--o{ WORD : "groups"
    CHILD ||--o{ SESSION : "practices in"
    SESSION ||--o{ ATTEMPT : "contains"
    WORD ||--o{ ATTEMPT : "is target of"
    ASR_MODEL ||--o{ ATTEMPT : "transcribes"
    ATTEMPT ||--o{ PHONEME_ALIGNMENT : "aligns to"
    SESSION ||--o| ASSESSMENT_REPORT : "summarized by"

    CATEGORY {
        string category_id PK
        string name
    }

    WORD {
        string word_id PK
        string category_id FK
        string text
        string ipa
        string phonemes_json
    }

    CHILD {
        string child_id PK
        string name
        int    age_years
    }

    SESSION {
        string session_id PK
        string child_id FK
        datetime session_date
        datetime created_at
    }

    ASR_MODEL {
        string model_id PK
        string model_source
        boolean fine_tuned
        string version_label
    }

    ATTEMPT {
        string attempt_id PK
        string session_id FK
        string word_id FK
        string model_id FK
        datetime timestamp
        string spoken_text
        float  wer_percent
        float  per_percent
        float  accuracy_sacc
        int    substitutions
        int    deletions
        int    insertions
    }

    PHONEME_ALIGNMENT {
        string alignment_id PK
        string attempt_id FK
        int    position
        string ref_phoneme
        string hyp_phoneme
        string alignment_type
    }

    ASSESSMENT_REPORT {
        string report_id PK
        string session_id FK
        datetime generated_at
        string file_name
        float  avg_wer
        float  avg_per
    }
```

## Cardinality notes

| Relationship | Cardinality | Meaning |
|---|---|---|
| CATEGORY → WORD | 1 to many | Each word belongs to exactly one practice category (e.g. "Animals") |
| CHILD → SESSION | 1 to many | A child can have multiple practice sessions over time |
| SESSION → ATTEMPT | 1 to many | Each attempt (one recorded word) belongs to exactly one session |
| WORD → ATTEMPT | 1 to many | The same target word can be attempted multiple times, in the same or different sessions |
| ASR_MODEL → ATTEMPT | 1 to many | Every attempt records which model/checkpoint produced its transcript, for reproducibility/versioning |
| ATTEMPT → PHONEME_ALIGNMENT | 1 to many | The phoneme-by-phoneme alignment (correct/substitution/deletion/insertion) for one attempt |
| SESSION → ASSESSMENT_REPORT | 1 to 0-or-1 | A report is generated on demand from a session's attempts; a session may have no report yet |

## Why ASR_MODEL is modeled explicitly

Because EchoVoice's scoring depends on which model produced the transcript
(the fine-tuned child-speech HuBERT vs. the base fallback — see
`Source_Code/app.py`), each `ATTEMPT` is tied to a specific `ASR_MODEL` record.
This keeps historical scores interpretable if the model is later retrained or
the backend temporarily falls back to the base checkpoint.
