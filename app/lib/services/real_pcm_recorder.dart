import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_recorder/flutter_recorder.dart';

import 'asr_pipeline.dart';
import 'demo_pipeline.dart';

/// Real microphone recorder that captures 16-bit PCM audio at 16 kHz,
/// matching the contract of [SyntheticPcmRecorder] but using the device's
/// actual microphone via the `flutter_recorder` plugin.
class RealPcmRecorder {
  RealPcmRecorder();

  bool _isRecording = false;
  bool _isInitialized = false;
  String? _lastPath;

  bool get isRecording => _isRecording;

  Future<bool> startRecording() async {
    if (_isRecording) return true;

    try {
      if (!_isInitialized) {
        await Recorder.instance.init(
          sampleRate: kEchoVoiceSampleRateHz,
          channels: RecorderChannels.mono,
          format: PCMFormat.s16le,
        );
        _isInitialized = true;
      }

      Recorder.instance.start();

      final tempDir = Directory.systemTemp;
      _lastPath =
          '${tempDir.path}/echovoice_recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      Recorder.instance.startRecording(completeFilePath: _lastPath!);
      _isRecording = true;
      return true;
    } catch (_) {
      _isRecording = false;
      return false;
    }
  }

  Future<Uint8List?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;

    try {
      Recorder.instance.stopRecording();
      Recorder.instance.stop();

      final path = _lastPath;
      if (path == null) return null;

      // Give the native side a moment to flush the file.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final file = File(path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      await file.delete();

      // WAV header is 44 bytes; skip it to get raw PCM.
      if (bytes.length <= 44) return null;
      return bytes.sublist(44);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    if (_isRecording) {
      Recorder.instance.stopRecording();
      Recorder.instance.stop();
      _isRecording = false;
    }
    if (_isInitialized) {
      Recorder.instance.deinit();
      _isInitialized = false;
    }
  }
}
