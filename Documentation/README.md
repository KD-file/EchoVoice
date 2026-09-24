# EchoVoice — System Analysis & Design Documentation

This folder is the structured-analysis-and-design (SAD) documentation set for
**EchoVoice**, the phoneme-level speech assessment app for children
(`index.html` frontend + `Source_Code/app.py` FastAPI service running a HuBERT
model fine-tuned on the PERCEPT-GFTA corpus). It's meant to sit alongside the
implementation and the manuscript as the formal design record — each diagram
type answers a different question about the same system, using the classic
structured-methods toolkit (De Marco/Gane–Sarson DFDs, Yourdon structure
charts, IBM HIPO, structured English, pseudocode, and an ERD/data dictionary).

## What's in this folder

| File | Diagram / Artifact | Answers the question |
|---|---|---|
| [`01_DFD.md`](01_DFD.md) | Data Flow Diagrams — Context (Level 0), Level 1, Level 2 | Where does data come from, where does it go, and what transforms it? |
| [`02_structured_chart.md`](02_structured_chart.md) | Structured (Structure) Chart | Which module calls which, and what does each call pass? |
| [`03_hipo.md`](03_hipo.md) | HIPO Diagram (VTOC + IPO charts) | For each module: what goes in, what happens, what comes out? |
| [`04_structured_english.md`](04_structured_english.md) | Structured English | What is each process's exact decision logic, in controlled natural language? |
| [`05_pseudocode.md`](05_pseudocode.md) | Pseudocode | How is each algorithm actually implemented, language-neutral but code-level? |
| [`06_erd.md`](06_erd.md) | Entity Relationship Diagram | What data entities exist, and how do they relate? |
| [`07_data_dictionary.md`](07_data_dictionary.md) | Data Dictionary | What is the exact shape, type, and meaning of every field? |
| [`08_configuration_management_plan.md`](08_configuration_management_plan.md) | Configuration Management Plan | What files are controlled, who owns each, and how changes/versions/traceability work? |

## How the pieces fit together

They form one traceable chain, from "what does the system do" down to "what
does each field mean":

```
DFD (process view)          →  Structured Chart / HIPO  →  Structured English / Pseudocode
   "what happens where"        "which module, what I/O"     "exact logic per process"

DFD's data stores            →  ERD                       →  Data Dictionary
   "what data exists"            "how entities relate"        "exact field-level shape"
```

Concretely:

- **DFD (`01_DFD.md`)** is the top-down process map. Level 0 is the whole
  system as a black box between the **Child** and the **Examiner/SLP**.
  Level 1 breaks it into the five processes visible in the app's five tabs
  and background logic (practice, capture & transcribe, assess, history,
  report). Level 2 zooms into **process 2.0**, because that's the one process
  that leaves the browser and crosses into the backend's HuBERT model — the
  part of the system this documentation set was written to make explicit.
- **Structured Chart (`02_structured_chart.md`)** takes each Level‑1/Level‑2
  process and turns it into the actual callable module hierarchy used in
  `index.html`/`app.py`, annotated with the data (d) and control (c) couples
  passed between modules — i.e., it's the DFD redrawn as "who calls whom,"
  which is what a developer needs to navigate or modify the code.
- **HIPO (`03_hipo.md`)** restates the same hierarchy as a Visual Table of
  Contents, then gives each significant module a one-page Input‑Process‑Output
  spec — the level of detail a new contributor needs before touching a
  specific module, without reading the whole DFD narrative first.
- **Structured English (`04_structured_english.md`)** writes out the exact
  branching/looping logic behind the busiest processes (recording, scoring,
  reporting) in constrained natural language — a specification a
  non-programmer reviewer (e.g. the adviser or an SLP consultant) can audit
  line by line.
- **Pseudocode (`05_pseudocode.md`)** is the same logic one level lower,
  close enough to the real JavaScript/Python that it doubles as an
  implementation reference — useful when porting the client-side scoring
  logic to another language/platform, or reviewing the backend's audio
  decode → inference → decode pipeline in isolation.
- **ERD (`06_erd.md`)** documents the data model implied by the app's
  attempt records — normalized into `CHILD`, `SESSION`, `WORD`, `ATTEMPT`,
  `PHONEME_ALIGNMENT`, `ASR_MODEL`, and `ASSESSMENT_REPORT` entities — which
  is the schema a future multi-device or clinician-dashboard version (with a
  real database instead of `localStorage`) would implement.
- **Data Dictionary (`07_data_dictionary.md`)** grounds the ERD in reality:
  it gives the exact field names/types both for the *logical* entities and
  for the app's *actual* current storage (the `WORD_BANK` object and the
  `echovoice_history` `localStorage` array), plus the `/api/health` and
  `/api/transcribe` request/response payloads exchanged with the backend —
  so nothing in the ERD is left unmapped to real code.

## Scope note

These diagrams describe the **deployed application** (child practices a
word → records an attempt → gets scored → session is reported), not the
offline **model training pipeline** (`hubert_percept_final.py`), which is a
separate batch process that produces the `D3` model-weights data store
consumed by DFD Level 2, process 2.5.

## Rendering

All diagrams are written in [Mermaid](https://mermaid.js.org/) syntax inside
fenced ```` ```mermaid ```` code blocks, which render automatically on GitHub,
in most Markdown editors (VS Code, Obsidian, etc. with the Mermaid
extension), and in any Mermaid live-preview tool.
