# EchoVoice — Diagram & Chart Explanations and Flows

*This file explains each diagram in this folder (`.mmd` sources). All diagrams follow one actor model: at Level 0 the system has exactly two external entities — the **Learner** and the **Caregiver**. The **Speech-Language Pathologist (SLP)** is an **external** clinical validator, not a user of the app; the Caregiver exports progress reports and shares them with an external clinician through their own preferred channels (the app is fully offline).*

Each section gives: **what it shows**, **notation**, and a step-by-step **flow**.

---

## 1. DFD Level 0 — Context Diagram (`DFD_Level0.mmd`)

### What it shows
The whole EchoVoice application as a single black box (process **0**) and its two external entities: the **Learner** and the **Caregiver**.

### Notation (Yourdon/DeMarco)
- Process: circle
- External entity: rectangle
- Data flow: arrow with a single arrowhead

### Flow
1. The **Learner** provides **Speech Input** (repeats the prompted word) into the app.
2. The app returns **Visual & Auditory Prompts** (the prompt and real-time feedback) to the Learner.
3. The **Caregiver** sends **Exercise Selection** (which exercise to practice) and **Goal configuration** (therapy targets) into the app.
4. The app returns a **Session Progress Summary** and, on request, the **Longitudinal Progress Report (Exportable)** to the Caregiver.
5. The SLP is *outside* the system: the Caregiver may share the exported report with an external clinician, but no data flows directly to or from the SLP.

---

## 2. DFD Level 1 (`DFD_Level1.mmd`)

### What it shows
The six main processes of the app, the two external entities, and two data stores (**D1 Progress Database**, **D2 Goal Config Store**).

### Processes
1.0 Manage Exercise · 2.0 Capture Speech · 3.0 Speech Recognition & Assessment · 4.0 Generate Feedback · 5.0 Monitor Progress · 6.0 Configure Goals & Review Assessment

### Flow
1. **Caregiver** sends **Exercise Selection** to **1.0 Manage Exercise**, which matches it against **Active Goals** from **D2** and sends the **Target Word** to **2.0 Capture Speech**.
2. **2.0** prompts the **Learner**, who responds with **Speech Input**; the recorded attempt is sent as **Recorded Speech** to **3.0 Speech Recognition & Assessment**.
3. **3.0** runs the on-device recognition and assessment pipeline (see Level 2), writes the **Assessment Record** to **D1**, and sends the **Assessment Result** to **4.0 Generate Feedback**.
4. **4.0** sends **Visual & Auditory Prompts** back to the **Learner**.
5. **5.0 Monitor Progress** reads **Stored Progress** from **D1** and sends the **Session Progress Summary** to the Caregiver; when the Caregiver requests the **Longitudinal Progress Report (Exportable)**, it is also sent to the Caregiver.
6. **6.0 Configure Goals & Review Assessment** receives **Goal Configuration** from the Caregiver, validates it, and writes the **Store Goal Configuration** to **D2**.

*Note: the Report-Request Flag, Update-Status Flag, and other control flags are shown explicitly in the Structure Chart rather than as data flows here.*

---

## 3. DFD Level 2 — Decomposition of Process 3.0 (`DFD_Level2.mmd`)

### What it shows
The internal pipeline of **3.0 Speech Recognition & Assessment**, split into **3.1 → 3.2 → 3.3 → 3.4**, with store **D3 Phoneme Target Dictionary** (answer key) and **D1 Progress Database** (output).

### Flow
1. **2.0 Capture Speech (Level 1)** hands the **Raw audio file (.wav)** to **3.1 Extract Acoustic Features**, which produces **Spectrogram Tensors**.
2. **3.2 Run Model Inference** runs the on-device speech recognition model and produces a **Predicted Phoneme Sequence**.
3. **3.3 Align Phonemes** reads the **Target Phoneme Template** from **D3** and compares it with the prediction, producing a **Phoneme Error Matrix**.
4. **3.4 Compute Pronunciation Score** turns the matrix into an **Assessment Result** (sent to **4.0 Generate Feedback**, Level 1) and writes the **Assessment Record** to **D1**.

---

## 4. Structure Chart (`StructureChart.mmd`)

### What it shows
The module hierarchy and the call/control relationships between modules: **0.0 EchoVoice Application** calls **1.0–6.0**, and **3.0** is decomposed into **3.1–3.4**. It also shows data flow, control flow (flags), conditions, the loop, and data-store access.

### Notation (from the chart legend)
- Data flow — direct arrow, open circle at origin
- Control flow — filled circle at origin
- Condition — diamond at the base of the module
- Loop — curved arrow
- Rounded rectangle — module; open parallel-line shapes — data stores

### Flow
1. **0.0** starts a session loop that repeats once per practice attempt. It sends **Exercise Selection** to **1.0 Manage Exercise**, which reads **Active Goals** from **D2**.
2. **1.0** passes the target to **2.0 Capture Speech**; the **Start-Recording Flag** (control, 1.0 → 2.0) gates recording. **2.0** sends **Recorded Speech (raw audio)** plus the **Recording-Complete Flag** (control, 2.0 → 3.0) to **3.0**.
3. **3.0** runs **3.1 → 3.2 → 3.3 → 3.4** (Spectrogram Tensors → Predicted Phoneme Sequence → Phoneme Error Matrix), with the **Inference Status Flag** (control, 3.2 → 3.3). The **Assessment Result** returns to **3.0**, which sends it to **4.0 Generate Feedback**.
4. **4.0** produces the feedback for the Learner.
5. **5.0 Monitor Progress** reads **Stored Progress** from **D1**; the diamond **IF report requested** gates the **Longitudinal Progress Report (Exportable)** (Report-Request Flag from the Caregiver).
6. **6.0 Configure Goals & Review Assessment** receives **Goal Configuration**; the diamond **IF goal update submitted** gates the write of **Goal Configuration** to **D2**, and the **Update-Status Flag** (control, 6.0 → 0.0) confirms success.
7. Store access is dashed: **D2** Active Goals (1.0) and Goal Configuration write (6.0); **D1** Stored Progress read (5.0) and Assessment Record write (3.4); **D3** Target Phoneme Template read (3.3).

---

## 5. HIPO Hierarchy Chart (VTOC) (`HIPO_Hierarchy.mmd`)

### What it shows
The top-down module tree (Visual Table of Contents) that maps to the Structure Chart: **0.0 EchoVoice Application** at the top, the six Level 1 modules, and the Level 2 decomposition of **3.0** into **3.1–3.4**.

### Flow (module responsibilities)
- **0.0** — coordinates exercise delivery, speech capture, on-device assessment, and reporting.
- **1.0 Manage Exercise** — matches the Caregiver's selection to active goals (D2) and retrieves the target word.
- **2.0 Capture Speech** — captures and encodes the Learner's audio.
- **3.0 Speech Recognition & Assessment** — feature extraction → inference → alignment → scoring (3.1–3.4).
- **4.0 Generate Feedback** — composes real-time visual/auditory feedback.
- **5.0 Monitor Progress** — builds the session recap and the exportable longitudinal report for the Caregiver.
- **6.0 Configure Goals & Review Assessment** — records caregiver-configured goals (D2) and presents assessment history.

*The detailed Input–Process–Output tables for every module are in `EchoVoice_HIPO.md`.*

---

## 6. Entity-Relationship Diagram (`ERD.mmd`)

### What it shows
The logical data model in Crow's Foot notation: 9 entities and the cardinality/participation rules between them. **There is no SLP entity** — the SLP is external.

### Entities
CAREGIVER, LEARNER, GOAL_CONFIGURATION, EXERCISE, PHONEME_TARGET, PRACTICE_SESSION, ATTEMPT, ASSESSMENT_RECORD, PROGRESS_REPORT

### Crow's Foot symbols
- `|` — one (mandatory)
- `O` — optional (zero participation)
- `<` — many (crow's foot)
- `o{` — zero-or-many; `||` — exactly one

### Flow / business rules
1. **CAREGIVER** `has` **LEARNER**, `sets` **GOAL_CONFIGURATION**, and `initiates` **PRACTICE_SESSION** (1 : 0..M each).
2. **LEARNER** `has` **GOAL_CONFIGURATION**, `participates_in` **PRACTICE_SESSION**, and `compiled_for` **PROGRESS_REPORT** (1 : 0..M each).
3. **EXERCISE** `contains` **PHONEME_TARGET** and `assigned_to` **ATTEMPT** (1 : 0..M each).
4. **PRACTICE_SESSION** `contains` **ATTEMPT** (1 : 0..M).
5. **ATTEMPT** `generates` **ASSESSMENT_RECORD** — strict 1 : 1 (an attempt gets exactly one automated score).
6. The **GOAL_CONFIGURATION** and **PRACTICE_SESSION** entities are the persistence of the DFD's **D2 Goal Config Store** and the session/progress records of **D1 Progress Database**.

*Full field-level detail and a plain-English dictionary are in `EchoVoice_Data_Dictionary.md`.*
