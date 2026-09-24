-- EchoVoice logical schema (SQLite-compatible DDL)
-- Implements the ERD in Documentation/06_erd.md. The deployed app currently
-- persists only in browser localStorage (see word_bank.json and
-- sample_attempt.json); this is the target schema for a future
-- multi-device / clinician-facing backend (e.g. the manuscript's clinical
-- validation phase with a real database instead of localStorage).

PRAGMA foreign_keys = ON;

CREATE TABLE category (
    category_id TEXT PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE
);

CREATE TABLE word (
    word_id       TEXT PRIMARY KEY,
    category_id   TEXT NOT NULL REFERENCES category(category_id),
    text          TEXT NOT NULL,
    ipa           TEXT NOT NULL,
    phonemes_json TEXT NOT NULL,          -- JSON array, e.g. ["k","æ","t"]
    UNIQUE (category_id, text)
);

CREATE TABLE child (
    child_id  TEXT PRIMARY KEY,
    name      TEXT DEFAULT 'Unknown',
    age_years INTEGER
);

CREATE TABLE session (
    session_id   TEXT PRIMARY KEY,
    child_id     TEXT NOT NULL REFERENCES child(child_id),
    session_date TEXT DEFAULT (date('now')),
    created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE asr_model (
    model_id      TEXT PRIMARY KEY,
    model_source  TEXT NOT NULL,
    fine_tuned    INTEGER NOT NULL CHECK (fine_tuned IN (0,1)),
    version_label TEXT
);

CREATE TABLE attempt (
    attempt_id    TEXT PRIMARY KEY,
    session_id    TEXT NOT NULL REFERENCES session(session_id),
    word_id       TEXT NOT NULL REFERENCES word(word_id),
    model_id      TEXT NOT NULL REFERENCES asr_model(model_id),
    timestamp     TEXT NOT NULL DEFAULT (datetime('now')),
    spoken_text   TEXT NOT NULL DEFAULT '',
    wer_percent   REAL NOT NULL CHECK (wer_percent >= 0),
    per_percent   REAL NOT NULL CHECK (per_percent >= 0),
    accuracy_sacc REAL NOT NULL CHECK (accuracy_sacc BETWEEN 0 AND 100),
    substitutions INTEGER NOT NULL DEFAULT 0 CHECK (substitutions >= 0),
    deletions     INTEGER NOT NULL DEFAULT 0 CHECK (deletions >= 0),
    insertions    INTEGER NOT NULL DEFAULT 0 CHECK (insertions >= 0)
);

CREATE TABLE phoneme_alignment (
    alignment_id   TEXT PRIMARY KEY,
    attempt_id     TEXT NOT NULL REFERENCES attempt(attempt_id),
    position       INTEGER NOT NULL CHECK (position >= 0),
    ref_phoneme    TEXT,
    hyp_phoneme    TEXT,
    alignment_type TEXT NOT NULL CHECK (alignment_type IN ('correct', 'substitution', 'deletion', 'insertion'))
);

CREATE TABLE assessment_report (
    report_id    TEXT PRIMARY KEY,
    session_id   TEXT NOT NULL REFERENCES session(session_id),
    generated_at TEXT NOT NULL DEFAULT (datetime('now')),
    file_name    TEXT NOT NULL,
    avg_wer      REAL NOT NULL,
    avg_per      REAL NOT NULL
);

-- Indexes that mirror the lookup patterns in index.html
CREATE INDEX idx_word_category ON word(category_id);
CREATE INDEX idx_attempt_session ON attempt(session_id);
CREATE INDEX idx_attempt_timestamp ON attempt(timestamp);
CREATE INDEX idx_alignment_attempt ON phoneme_alignment(attempt_id);
CREATE INDEX idx_report_session ON assessment_report(session_id);