# Running EchoVoice

Step-by-step guide to get the EchoVoice Flutter app running on your own machine.

## 1. Prerequisites

- **Flutter SDK** (3.x) with the Android toolchain — check with `flutter doctor`
- **Android Studio** (or VS Code with the Flutter & Dart extensions)
- **Android emulator (AVD)** or a physical Android device with USB debugging enabled
- **Git**

## 2. Get the code

```bash
git clone https://github.com/KD-file/EchoVoice.git
cd EchoVoice/app
```

## 3. Install dependencies

All Flutter commands need to be run from inside the `app` folder, not the repo root.

```bash
cd app
flutter pub get
```

## 4. Open the project in your IDE

### Android Studio

1. `File → Open…` and select the `EchoVoice/app` folder (the folder that contains `pubspec.yaml`).
2. Wait for the Gradle sync to finish (may take a few minutes the first time).
3. The run target is `lib/main.dart` — confirm it appears in the run configuration dropdown.

### VS Code

1. `File → Open Folder…` and select the `EchoVoice/app` folder.
2. Install the **Flutter** and **Dart** extensions if you haven't.
3. Press `F5` (or `Run → Start Debugging`) with `lib/main.dart` open.

## 5. Start an emulator

**Android Studio:** open _Device Manager_ (`Tools → Device Manager`) and press the ▶ button on an AVD.

**Command line:**

```bash
cd app
flutter emulators            # list available AVDs
flutter emulators --launch <id>   # start one, e.g. --launch Medium_Phone
```

> Tip: if the emulator window appears off-screen, move it back by dragging it, or
> right-click its taskbar entry → "Restore".

## 6. Run the app

```bash
cd app
flutter run
```

Or press the green **Run** button in your IDE.

Once running:

- `r` — hot reload
- `R` — hot restart
- `q` — quit

### Troubleshooting

| Problem                            | Fix                                                                                              |
| ---------------------------------- | ------------------------------------------------------------------------------------------------ |
| `device 'emulator-5554' not found` | The emulator isn't running. Start it first (step 5).                                             |
| Gradle build takes long / fails    | Make sure you have a stable internet connection for the first build (it downloads dependencies). |
| App closes after a few seconds     | Unlock the emulator screen and keep it on: `adb shell svc power stayon true`.                    |
| `flutter: command not found`       | Add Flutter's `bin` folder to your system `PATH`.                                                |

## 7. Run the tests

```bash
cd app
flutter test
```

## 8. On-device ASR model

Out of the box the app scores attempts with a **demo runtime** that ignores the
audio and fabricates plausible phonemes, so the full flow (record → score →
feedback) works without any model on disk.

To use the **real** exported model:

1. Export it (requires `onnx2tf`; see `backend/README.md`):

   ```bash
   cd backend
   .\.venv\Scripts\activate
   python scripts/export_tflite.py --checkpoint runs/run1/checkpoint.pt --out runs/run1 --tflite
   ```

2. Copy the artifact into the app:

   ```bash
   Copy-Item backend\runs\run1\tflite\echovoice_asr.tflite app\assets\models\echovoice_asr.tflite
   ```

3. Declare it in `pubspec.yaml` under `flutter: assets`:

   ```yaml
   - assets/models/
   ```

`TfliteAsrModelRunner` (in `lib/services/tflite_asr_model.dart`) then loads the
model plus `assets/phonemes/phoneme_set.json` and runs CTC greedy decoding on
device. If the model asset is absent it silently falls back to the demo
runtime, so the app never breaks.

## 9. Backend (optional — Python ML)

The `backend/` folder is the Python training/export side and is **not** required to run the app.

```bash
cd backend
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
```

See `backend/README.md` for the training and model-export pipeline.
