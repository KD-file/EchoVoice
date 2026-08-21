EchoVoice — Design Documentation

# EchoVoice — HIPO: IPO Charts

*Aligned with Chapter 1 & 2, the Structure Chart, and the DFD control flags. Goal configuration and progress review are Caregiver inputs; the Speech-Language Pathologist is an **external** clinical validator only.*

# Hierarchy Chart (VTOC)

*On-Device Speech Recognition and Pronunciation Assessment App for Listen-and-Repeat Speech Therapy*

# 0.0 EchoVoice Application (Overview)

*Top-level module — corresponds to the Level 0 context DFD, with the Learner and Caregiver as external entities.*

| **INPUT** | **PROCESS** | **OUTPUT** | **CONTROL** |
| --- | --- | --- | --- |
| Speech Input (Learner) Exercise Selection (Caregiver) Goal Configuration (Caregiver) Report-Request Flag (Caregiver) | Coordinate exercise delivery, speech capture, on-device assessment, and reporting across all sub-modules | Visual & Auditory Prompts → Learner Session Progress Summary → Caregiver Longitudinal Progress Report (Exportable) → Caregiver | Update-Status Flag → Caregiver |

# Level 1 Modules

## 1.0 Manage Exercise

| **INPUT** | **PROCESS** | **OUTPUT** | **CONTROL** |
| --- | --- | --- | --- |
| Exercise Selection (Caregiver) Active Goals (D2 Goal Config Store) | Match caregiver selection against active therapy goals Retrieve corresponding target word | Target Word/Prompts → 2.0 | — |

## 2.0 Capture Speech

*Start-Recording Flag and Recording-Complete Flag are shown as explicit control flow, matching the Structure Chart.*

| **INPUT** | **PROCESS** | **OUTPUT** | **CONTROL** |
| --- | --- | --- | --- |
| Speech Input (Learner) Target Word/Prompts (1.0) | Capture microphone audio Encode as raw audio file | Raw Audio File (.wav) → 3.0 (shown as Recorded Speech (raw audio) on the DFD) | Start-Recording Flag (in, from 1.0) Recording-Complete Flag (out, to 3.0) |

## 3.0 Speech Recognition & Assessment

| **INPUT** | **PROCESS** | **OUTPUT** | **CONTROL** |
| --- | --- | --- | --- |
| Recorded Speech (raw audio) (2.0) | Extract features → infer phonemes → align → score (Decomposed into 3.1–3.4) | Assessment Result → 4.0 Assessment Record → D1 | — |

## 4.0 Generate Feedback

| **INPUT** | **PROCESS** | **OUTPUT** | **CONTROL** |
| --- | --- | --- | --- |
| Assessment Result (3.0) | Compose real-time visual/auditory feedback for the learner's attempt | Visual & Auditory Prompts → Learner | — |

## 5.0 Monitor Progress

*Report generation is gated by the Report-Request Flag, matching the "IF report requested" condition on the Structure Chart.*

| **INPUT** | **PROCESS** | **OUTPUT** | **CONTROL** |
| --- | --- | --- | --- |
| Stored Progress (D1 Progress Database) | Compile trends across sessions Build session-level recap for the Caregiver IF report requested, build exportable longitudinal report for the Caregiver (to share with an external clinician) | Session Progress Summary → Caregiver Longitudinal Progress Report (Exportable) → Caregiver | Report-Request Flag (in, from Caregiver) |

## 6.0 Configure Goals & Review Assessment

*Goal writes return an explicit Update-Status Flag, matching the "IF goal update submitted" condition on the Structure Chart. Input is from the Caregiver.*

| **INPUT** | **PROCESS** | **OUTPUT** | **CONTROL** |
| --- | --- | --- | --- |
| Goal Configuration & Progress Review (Caregiver) | Validate and record updated therapy goals Present stored assessment data for progress review (no store update) | Store Goal Configuration → D2 | Update-Status Flag (out, to Caregiver) |

# Level 2 Modules — Decomposition of 3.0

*Each stage feeds the next in sequence: 3.1 → 3.2 → 3.3 → 3.4.*

## 3.1 Extract Acoustic Features

| **INPUT** | **PROCESS** | **OUTPUT** | **CONTROL** |
| --- | --- | --- | --- |
| Raw Audio File (.wav) (2.0) | Convert waveform to spectrogram Encode as model-ready tensors | Spectrogram Tensors → 3.2 | — |

## 3.2 Run Model Inference

*Inference Status Flag is shown as an explicit control-flow output, matching the Structure Chart.*

| **INPUT** | **PROCESS** | **OUTPUT** | **CONTROL** |
| --- | --- | --- | --- |
| Spectrogram Tensors (3.1) | Run on-device speech recognition model | Predicted Phoneme Sequence → 3.3 | Inference Status Flag (out, to 3.3 / Main Control) |

## 3.3 Align Phonemes

| **INPUT** | **PROCESS** | **OUTPUT** | **CONTROL** |
| --- | --- | --- | --- |
| Predicted Phoneme Sequence (3.2) Target Phoneme Template (D3) | Align predicted vs. target phoneme sequences | Phoneme Error Matrix → 3.4 | — |

## 3.4 Compute Pronunciation Score

| **INPUT** | **PROCESS** | **OUTPUT** | **CONTROL** |
| --- | --- | --- | --- |
| Phoneme Error Matrix (3.3) | Score pronunciation accuracy from error matrix | Assessment Result → 4.0 Assessment Record → D1 | — |
