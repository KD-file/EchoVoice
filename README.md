# EchoVoice
Machine Learning mobile application for voice imitation and pronunciation assessment.
## Members

- Nievera, Kurt Daryl M. (Leader)
- Cerezo, Kate Ann H.
- Doctolero, Maica Jenish M.
- Gonzales, Rolando Jr. T.
- Paglingayen, Jefferson S.

## Adviser

Ezekiel Ordoña Bacungan

## Subject

Software Engineering

## Repository

This is the group repository. All members can clone it and run the project on their own machine.

```
git clone https://github.com/KD-file/EchoVoice.git
cd EchoVoice
```

## Getting Started

1. Install the **Flutter SDK** (3.x) with the Android toolchain — check with `flutter doctor`.
2. Clone the repository (above).
3. Install dependencies: `flutter pub get`
4. Run the app: `flutter run` (on an Android emulator or a physical device).
5. Run the tests: `flutter test`

The app runs out of the box with a demo ASR runtime, so no model or
backend is required to explore the full flow (record -> score -> feedback).
Full step-by-step instructions, troubleshooting, and the optional Python
ML/backend setup are in [RUNNING.md](RUNNING.md).

## Project structure

- `lib/` — Flutter application (data, db, models, services, state, ui, utils)
- `test/` — Unit and widget tests (run with `flutter test`)
- `backend/` — Python ML training and model-export pipeline (optional)
- `docs/` — Design documents and the quality-assessment report
- `assets/` — Images and the exported phoneme set for the on-device model
