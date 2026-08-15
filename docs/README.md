# EchoVoice — Documentation Package (Markdown + Diagram Source)

This package contains every EchoVoice design document as plain Markdown, and every diagram (DFD Level 0–2, Structure Chart, ERD, HIPO Hierarchy Chart) as editable **Mermaid** source code. Paste any `.mmd` file's contents into a Mermaid-compatible renderer (the Mermaid Live Editor at mermaid.live, GitHub/GitLab markdown, Notion, Obsidian, VS Code's Mermaid preview extension, etc.) to regenerate the diagram — and to edit it, just edit the text.

## Contents

### Diagrams (Mermaid source, `.mmd`)
| File | Diagram |
|---|---|
| `DFD_Level0.mmd` | Data Flow Diagram — Level 0 (context diagram) |
| `DFD_Level1.mmd` | Data Flow Diagram — Level 1 |
| `DFD_Level2.mmd` | Data Flow Diagram — Level 2 (decomposition of Process 3.0) |
| `StructureChart.mmd` | Structure Chart (modules, data/control flow, conditions, loop) |
| `ERD.mmd` | Entity Relationship Diagram |
| `HIPO_Hierarchy.mmd` | HIPO Hierarchy Chart (VTOC) |

### Documents (Markdown, `.md`)
| File | Source document |
|---|---|
| `Chapter1_2.md` | Chapter 1 & 2 (Introduction, Situational Analysis, etc.) |
| `Diagrams_Explained.md` | Explanation and step-by-step flow for every diagram/chart |
| `EchoVoice_HIPO.md` | HIPO IPO Charts |
| `EchoVoice_Data_Dictionary.md` | Data Dictionary |
| `EchoVoice_Pseudocode.md` | Pseudocode |
| `EchoVoice_StructuredEnglish.md` | Structured English |

---

## Consistency

All documents are aligned to a single actor model: at Level 0 the system has exactly two external entities — the **Learner** and the **Caregiver**.

- The **Caregiver** supplies Exercise Selection, Goal Configuration, and the Report-Request Flag, and receives the Session Progress Summary, the Exportable Longitudinal Progress Report, and the Update-Status Flag.
- The **Speech-Language Pathologist (SLP)** is an **external** clinical validator, **not** a user of the application. EchoVoice runs fully offline with no account or server; the Caregiver exports the progress report and shares it with an external clinician through their own preferred channels (matching Chapter 1 & 2).
- The Pseudocode, Structured English, HIPO, Data Dictionary, and ERD below all reflect this model consistently. There is no SLP entity or SLP data flow in any diagram.

---

## Diagram previews

*Each preview below is explained and walked through step-by-step in [`Diagrams_Explained.md`](Diagrams_Explained.md).*

### DFD Level 0
*Context diagram: the app (process 0) sits between the Learner (Speech Input in; Visual & Auditory Prompts out) and the Caregiver (Exercise Selection and Goal configuration in; Session Progress Summary and the Exportable Longitudinal Progress Report out). The SLP is external.*
```mermaid
flowchart LR
    Learner[Learner]
    Caregiver[Caregiver]
    App((0<br/>EchoVoice<br/>Application))

    Learner -->|Speech Input| App
    App -->|Visual and Auditory Prompts| Learner

    Caregiver -->|Exercise Selection| App
    Caregiver -->|Goal configuration| App
    App -->|Session Progress Summary| Caregiver
    App -->|Longitudinal Progress Report Exportable| Caregiver
```

### DFD Level 1
*The six processes (1.0–6.0), the D1 Progress Database and D2 Goal Config Store, and all Learner/Caregiver data flows.*
```mermaid
flowchart TD
    Learner[Learner]
    Caregiver[Caregiver]

    P1((1.0<br/>Manage<br/>Exercise))
    P2((2.0<br/>Capture<br/>Speech))
    P3((3.0<br/>Speech<br/>Recog. and<br/>Assessment))
    P4((4.0<br/>Generate<br/>Feedback))
    P5((5.0<br/>Monitor<br/>Progress))
    P6((6.0<br/>Configure<br/>Goals))

    D1[(D1  Progress Database)]
    D2[(D2  Goal Config. Storage)]

    Caregiver -->|Exercise Selection| P1
    D2 -->|Active Goals| P1
    P1 -->|Target Word| P2

    Learner -->|Speech Input| P2
    P2 -->|Recorded Speech| P3

    P3 -->|Assessment Record| D1
    P3 -->|Assessment Result| P4
    P4 -->|Visual and Auditory Prompts| Learner

    D1 -->|Stored Progress| P5
    P5 -->|Session Progress Summary| Caregiver
    P5 -->|Longitudinal Progress Report Exportable| Caregiver

    Caregiver -->|Goal Configuration| P6
    P6 -->|Store Goal Config.| D2
```

### DFD Level 2 (decomposition of 3.0)
*Internal pipeline of Process 3.0 (3.1 → 3.2 → 3.3 → 3.4), reading D3 Phoneme Target Dictionary and writing the Assessment Record to D1.*
```mermaid
flowchart LR
    P2((2.0<br/>Capture Speech<br/>Level 1))
    P31((3.1<br/>Extract<br/>Acoustic<br/>Features))
    P32((3.2<br/>Run<br/>Model<br/>Inference))
    P33((3.3<br/>Align<br/>Phonemes))
    P34((3.4<br/>Compute<br/>Pronunciation<br/>Score))
    P4((4.0<br/>Generate Feedback<br/>Level 1))

    D3[(D3  Phoneme Target Dictionary)]
    D1[(D1  Progress Database)]

    P2 -->|Raw audio file .wav| P31
    P31 -->|Spectrogram Tensors| P32
    P32 -->|Predicted Phoneme Sequence| P33
    D3 -->|Target Phoneme Template| P33
    P33 -->|Phoneme Error Matrix| P34
    P34 -->|Assessment Result| P4
    P34 -->|Assessment Record| D1
```

### Structure Chart
*Module tree 0.0 → 1.0–6.0 (with 3.0 → 3.1–3.4) showing data flow, control flags (Start-Recording, Recording-Complete, Inference Status, Update-Status, Report-Request), the IF conditions, the session loop, and D1/D2/D3 access.*
```mermaid
flowchart TD
    M0(("0.0<br/>EchoVoice Application"))

    M1["1.0<br/>Manage Exercise"]
    M2["2.0<br/>Capture Speech"]
    M3["3.0<br/>Speech Recognition and Assessment"]
    M4["4.0<br/>Generate Feedback"]
    M5["5.0<br/>Monitor Progress"]
    M6["6.0<br/>Configure Goals and Review Assessment"]

    M0 -->|Exercise Selection| M1
    M0 --> M2
    M2 -->|Recorded Speech raw audio| M3
    M3 -->|Assessment Result| M4
    M0 --> M5
    M0 -->|Goal Configuration| M6

    M1 -. "Start-Recording Flag" .-> M2
    M2 -. "Recording-Complete Flag" .-> M3
    M6 -. "Update-Status Flag" .-> M0
    M0 -. "Loop - repeats once per practice attempt" .-> M0

    P31["3.1<br/>Extract Acoustic Features"]
    P32["3.2<br/>Run Model Inference"]
    P33["3.3<br/>Align Phonemes"]
    P34["3.4<br/>Compute Pronunciation Score"]

    M3 --> P31
    P31 -->|Spectrogram Tensors| P32
    P32 -->|Predicted Phoneme Sequence| P33
    P33 -->|Phoneme Error Matrix| P34
    P34 -->|Assessment Result| M3
    P32 -. "Inference Status Flag" .-> P33

    COND1{"IF report requested"}
    COND2{"IF goal update submitted"}
    M5 --- COND1
    M6 --- COND2
    COND1 -->|Longitudinal Progress Report Exportable| M5
    COND2 -->|Goal Configuration| M6

    D1[(D1  Progress Database)]
    D2[(D2  Goal Config. Storage)]
    D3[(D3  Phoneme Target Dictionary)]

    M1 -. "Active Goals read" .-> D2
    M5 -. "Stored Progress read" .-> D1
    M6 -. "Store Goal Configuration write" .-> D2
    P33 -. "Target Phoneme Template read" .-> D3
    P34 -. "Assessment Record write" .-> D1
```

### ERD
*Nine entities in Crow's Foot notation, the caregiver-centric business rules, and the strict 1:1 Attempt → Assessment_Record; there is no SLP entity.*
```mermaid
erDiagram
    CAREGIVER ||--o{ LEARNER : has
    CAREGIVER ||--o{ GOAL_CONFIGURATION : sets
    LEARNER ||--o{ GOAL_CONFIGURATION : has
    LEARNER ||--o{ PRACTICE_SESSION : participates_in
    CAREGIVER ||--o{ PRACTICE_SESSION : initiates
    LEARNER ||--o{ PROGRESS_REPORT : compiled_for
    EXERCISE ||--o{ PHONEME_TARGET : contains
    EXERCISE ||--o{ ATTEMPT : assigned_to
    PRACTICE_SESSION ||--o{ ATTEMPT : contains
    ATTEMPT ||--|| ASSESSMENT_RECORD : generates

    CAREGIVER {
        int caregiver_id PK
        string full_name
        string contact_number
        string relationship_to_learner
    }
    LEARNER {
        int learner_id PK
        int caregiver_id FK
        string full_name
        date date_of_birth
        string diagnosis_notes
        date enrollment_date
    }
    GOAL_CONFIGURATION {
        int goal_id PK
        int learner_id FK
        int caregiver_id FK
        string target_phonemes
        date date_set
        string status
    }
    EXERCISE {
        int exercise_id PK
        string target_word
        string difficulty_level
        string category
    }
    PHONEME_TARGET {
        int phoneme_id PK
        int exercise_id FK
        string phoneme_symbol
        int position_index
    }
    PRACTICE_SESSION {
        int session_id PK
        int learner_id FK
        int caregiver_id FK
        datetime session_date
    }
    ATTEMPT {
        int attempt_id PK
        int session_id FK
        int exercise_id FK
        string audio_file_path
        datetime timestamp
    }
    ASSESSMENT_RECORD {
        int assessment_id PK
        int attempt_id FK
        string phoneme_error_matrix
        float pronunciation_score
        float wer
        float per
        datetime date_created
    }
    PROGRESS_REPORT {
        int report_id PK
        int learner_id FK
        string recipient_type
        date range_start
        date range_end
        string summary_text
    }
```

### HIPO Hierarchy Chart
*Top-down module tree (VTOC) matching the Structure Chart; the Input–Process–Output tables for each module are in `EchoVoice_HIPO.md`.*
```mermaid
flowchart TD
    M0["0.0<br/>EchoVoice Application"]
    M1["1.0<br/>Manage Exercise"]
    M2["2.0<br/>Capture Speech"]
    M3["3.0<br/>Speech Recognition and Assessment"]
    M4["4.0<br/>Generate Feedback"]
    M5["5.0<br/>Monitor Progress"]
    M6["6.0<br/>Configure Goals and Review Assessment"]

    M31["3.1<br/>Extract Acoustic Features"]
    M32["3.2<br/>Run Model Inference"]
    M33["3.3<br/>Align Phonemes"]
    M34["3.4<br/>Compute Pronunciation Score"]

    M0 --> M1
    M0 --> M2
    M0 --> M3
    M0 --> M4
    M0 --> M5
    M0 --> M6
    M3 --> M31
    M3 --> M32
    M3 --> M33
    M3 --> M34
```
