# Configuration Management Plan

## Header

| Field | Detail |
|---|---|
| **Project Name** | EchoVoice: Self-Supervised Acoustic Modeling for Phoneme-Level Error Detection in Children's Speech |
| **Team Members** | Kurt Daryl M. Nievera (Leader), Kate Ann H. Cerezo, Maica Jenish M. Doctolero, Rolando Jr. T. Gonzales, Jefferson S. Paglingayen |
| **Repository URL** | https://github.com/KD-file/EchoVoice |

---

## 1. Configuration Items

Configuration items (CIs) are grouped into five categories: Source Code, Documentation, Dependencies/Environment, Data/Schema, and Build/Config Scripts. The file paths below refer to the organized project layout.

| Name | Category | File Path | Owner | Version | Status |
|---|---|---|---|---|---|
| System Analysis & Design README | Documentation | `Documentation/README.md` | Maica Jenish Doctolero | v1.0.0 | Done |
| Backend Setup README | Documentation | `Documentation/README_backend.md` | Maica Jenish Doctolero | v1.0.0 | Done |
| DFD Diagrams (Context/Level 1/Level 2) | Documentation | `Documentation/01_DFD.md` | Kurt Daryl Nievera | v1.0.0 | Done |
| Structured Chart | Documentation | `Documentation/02_structured_chart.md` | Kate Ann Cerezo | v1.0.0 | Done |
| HIPO Diagrams | Documentation | `Documentation/03_hipo.md` | Kate Ann Cerezo | v1.0.0 | Done |
| Structured English | Documentation | `Documentation/04_structured_english.md` | Maica Jenish Doctolero | v1.0.0 | Done |
| Pseudocode | Documentation | `Documentation/05_pseudocode.md` | Rolando Jr. Gonzales | v1.0.0 | Done |
| ERD | Documentation | `Documentation/06_erd.md` | Maica Jenish Doctolero | v1.0.0 | Done |
| Data Dictionary | Documentation | `Documentation/07_data_dictionary.md` | Jefferson Paglingayen | v1.0.0 | Done |
| Configuration Management Plan | Documentation | `Documentation/08_configuration_management_plan.md` | Kurt Daryl Nievera | v1.0.0 | Done |
| Frontend Application | Source Code | `Source_Code/index.html` | Maica Jenish Doctolero | v1.0.0 | Done |
| ASR Backend (FastAPI service) | Source Code | `Source_Code/app.py` | Maica Jenish Doctolero | v1.0.0 | Done |
| Model Fine-Tuning Notebook Script | Source Code | `Source_Code/hubert_percept_final (1).py` | Rolando Jr. Gonzales | v1.0.0 | Under changes/ongoing |
| Python Dependencies | Dependencies/Environment | `Dependencies_Environment/requirements.txt` | Maica Jenish Doctolero | v1.0.0 | Done |
| Logical Database Schema | Data/Schema | `Data_Schema/schema.sql` | Maica Jenish Doctolero | v1.0.0 | Done |
| Target Word Bank | Data/Schema | `Data_Schema/word_bank.json` | Maica Jenish Doctolero | v1.0.0 | Done |
| Sample Attempt Record | Data/Schema | `Data_Schema/sample_attempt.json` | Maica Jenish Doctolero | v1.0.0 | Done |
| API Payload Samples | Data/Schema | `Data_Schema/api_payloads.json` | Maica Jenish Doctolero | v1.0.0 | Done |
| Environment Setup Script | Build/Config Scripts | `Build_Config_Scripts/setup_env.ps1` | Maica Jenish Doctolero | v1.0.0 | Done |
| Backend Runner Script | Build/Config Scripts | `Build_Config_Scripts/run_backend.ps1` | Maica Jenish Doctolero | v1.0.0 | Done |
| ffmpeg Install Script | Build/Config Scripts | `Build_Config_Scripts/install_ffmpeg.ps1` | Maica Jenish Doctolero | v1.0.0 | Done |
| Checkpoint Export Snippet | Build/Config Scripts | `Build_Config_Scripts/export_checkpoint.py` | Rolando Jr. Gonzales | v1.0.0 | Done |
| Backend Environment Template | Build/Config Scripts | `Build_Config_Scripts/echovoice.env.example` | Maica Jenish Doctolero | v1.0.0 | Done |
| Backend Environment Configuration | Build/Config Scripts | `Build_Config_Scripts/echovoice.env` | Maica Jenish Doctolero | v1.0.0 | Done |

---

## 2. Baseline

The **baseline** for this project is defined as the state of the repository at the point this Configuration Management Plan was drafted: the finalized, organized folder layout (Documentation, Source_Code, Dependencies_Environment, Data_Schema, Build_Config_Scripts) containing the EchoVoice web application, ASR backend, and model training pipeline. All configuration items listed above are versioned relative to this baseline as **v1.0.0**. Any future modification to a CI is measured as a change against this reference point.

---

## 3. Version Conventions

This project follows **Semantic Versioning (SemVer)**: `MAJOR.MINOR.PATCH`

- **MAJOR** — incremented for breaking changes (e.g., a redesigned data schema, a rewritten ASR decoding pipeline architecture)
- **MINOR** — incremented for new features that do not break existing functionality (e.g., adding a new word category, a new API endpoint, a new UI screen)
- **PATCH** — incremented for bug fixes and small internal corrections (e.g., fixing a scoring calculation, correcting documentation wording)

All configuration items currently start at **v1.0.0** as the initial baseline version.

---

## 4. Status Accounting

Each configuration item is assigned one of the following statuses:

| Status | Meaning |
|---|---|
| **Done / Completed** | The item is complete at its baseline version and no longer under active revision. |
| **Under changes/ongoing** | The item is actively being developed or revised. |
| **Suspended** | Work on the item has been paused. |
| **Superseded** | The item has been replaced by a newer version or approach and is no longer in active use. |

The majority of configuration items are **Done / Completed**, standing at the
v1.0.0 baseline. Only the **Model Fine-Tuning Notebook Script** (`hubert_percept_final (1).py`)
remains **Under changes/ongoing**, as training and evaluation are still being iterated.

---

## 5. Traceability

Every change to a configuration item follows this traceability flow:

**Reason for Change → Approval → Implementation → Update Record**

1. **Reason for Change** — A team member identifies a need (bug, new requirement, adviser feedback, SLP consultation input, manuscript alignment) and documents it.
2. **Approval** — The change is reviewed and approved by the team lead (Kurt Daryl Nievera).
3. **Implementation** — The approved change is made, committed to the repository with a clear commit message referencing the reason.
4. **Update Record** — The configuration item table's Version and Status fields are updated accordingly to reflect the new state.