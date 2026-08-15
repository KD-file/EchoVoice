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
cd EchoVoice
```

## 3. Install dependencies

```bash
flutter pub get
```

## 4. Open the project in your IDE

### Android Studio

1. `File → Open…` and select the `EchoVoice` folder (the folder that contains `pubspec.yaml`).
2. Wait for the Gradle sync to finish (may take a few minutes the first time).
3. The run target is `lib/main.dart` — confirm it appears in the run configuration dropdown.

### VS Code

1. `File → Open Folder…` and select the `EchoVoice` folder.
2. Install the **Flutter** and **Dart** extensions if you haven't.
3. Press `F5` (or `Run → Start Debugging`) with `lib/main.dart` open.

## 5. Start an emulator

**Android Studio:** open *Device Manager* (`Tools → Device Manager`) and press the ▶ button on an AVD.

**Command line:**

```bash
flutter emulators            # list available AVDs
flutter emulators --launch <id>   # start one, e.g. --launch Medium_Phone
```

> Tip: if the emulator window appears off-screen, move it back by dragging it, or
> right-click its taskbar entry → "Restore".

## 6. Run the app

```bash
flutter run
```

Or press the green **Run** button in your IDE.

Once running:
- `r` — hot reload
- `R` — hot restart
- `q` — quit

### Troubleshooting

| Problem | Fix |
|---------|-----|
| `device 'emulator-5554' not found` | The emulator isn't running. Start it first (step 5). |
| Gradle build takes long / fails | Make sure you have a stable internet connection for the first build (it downloads dependencies). |
| App closes after a few seconds | Unlock the emulator screen and keep it on: `adb shell svc power stayon true`. |
| `flutter: command not found` | Add Flutter's `bin` folder to your system `PATH`. |

## 7. Run the tests

```bash
flutter test
```

## 8. Backend (optional — Python ML)

The `backend/` folder is the Python training/export side and is **not** required to run the app.

```bash
cd backend
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
```

See `backend/README.md` for the training and model-export pipeline.
