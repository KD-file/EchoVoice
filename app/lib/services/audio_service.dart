import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

/// Centralised audio service for EchoVoice. Handles:
///   * Text-to-speech word pronunciation
///   * Sound-effect playback (prompts, chimes, celebration bursts)
///   * Background music looping
///
/// Sound effects are generated as short sine-wave WAVs at runtime so the
/// app works without any bundled audio files. Background music is a
/// gentle looping tone.
class AudioService {
  AudioService() {
    _bgPlayer.setLoopMode(LoopMode.all);
    _bgPlayer.setVolume(0.15);
    _initTts();
  }

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _bgPlayer = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  bool _bgPlaying = false;

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45); // slower for children
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.1); // slightly higher pitch
  }

  // ── Text-to-speech ─────────────────────────────────────────────────

  /// Speaks [word] aloud using the device TTS engine.
  Future<void> speakWord(String word) async {
    if (word.trim().isEmpty) return;
    await _tts.speak(word);
  }

  // ── Sound effects ──────────────────────────────────────────────────

  /// Plays a short chime for the "Listen" prompt.
  Future<void> playPrompt() => _playTone(660, 0.25, volume: 0.5);

  /// Plays a success chime (3-star / 90 %+ score).
  Future<void> playSuccess() async {
    await _playTone(523, 0.15, volume: 0.6); // C5
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await _playTone(659, 0.15, volume: 0.6); // E5
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await _playTone(784, 0.25, volume: 0.6); // G5
  }

  /// Plays a gentle encouragement tone (2-star / 70-89 %).
  Future<void> playEncourage() => _playTone(440, 0.3, volume: 0.4);

  /// Plays a retry tone (0-69 %).
  Future<void> playRetry() => _playTone(330, 0.35, volume: 0.35);

  /// Plays a generic named sound. Maps known names to specific tones so
  /// callers (e.g. [FeedbackGenerator.playSound]) don't need to know
  /// about frequencies.
  Future<void> playSound(String name) async {
    if (name.startsWith('prompt_')) {
      await playPrompt();
    } else if (name == 'success' || name == 'celebration') {
      await playSuccess();
    } else if (name == 'encourage') {
      await playEncourage();
    } else if (name == 'retry') {
      await playRetry();
    } else {
      await _playTone(440, 0.2, volume: 0.3);
    }
  }

  // ── Background music ───────────────────────────────────────────────

  /// Starts the looping background music if not already playing.
  void startMusic() {
    if (_bgPlaying) return;
    _bgPlaying = true;
    _bgPlayer.setVolume(0.15);
    _bgPlayer.setLoopMode(LoopMode.all);
    _playBackgroundTone();
  }

  /// Stops the background music.
  void stopMusic() {
    if (!_bgPlaying) return;
    _bgPlaying = false;
    _bgPlayer.stop();
  }

  bool get isMusicPlaying => _bgPlaying;

  Future<void> _playBackgroundTone() async {
    if (!_bgPlaying) return;
    try {
      final data = _generateWav(
        frequency: 220,
        durationSec: 4.0,
        volume: 0.12,
      );
      final file = await _writeTempWav(data, 'bg_music.wav');
      await _bgPlayer.setFilePath(file.path);
      await _bgPlayer.play();
      // Restart when finished to create a seamless loop.
      _bgPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed && _bgPlaying) {
          _playBackgroundTone();
        }
      });
    } catch (_) {
      // Silently ignore – music is cosmetic.
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────

  Future<void> _playTone(
    double frequency,
    double durationSec, {
    double volume = 0.4,
  }) async {
    try {
      final data = _generateWav(
        frequency: frequency,
        durationSec: durationSec,
        volume: volume,
      );
      final file = await _writeTempWav(data, 'sfx.wav');
      await _sfxPlayer.setFilePath(file.path);
      await _sfxPlayer.play();
    } catch (_) {
      // Silently ignore – sound effects are non-critical.
    }
  }

  /// Generates a simple sine-wave WAV file in memory.
  static Uint8List _generateWav({
    required double frequency,
    required double durationSec,
    required double volume,
    int sampleRate = 44100,
    int bitsPerSample = 16,
  }) {
    final numSamples = (sampleRate * durationSec).round();
    const numChannels = 1;
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = numSamples * blockAlign;
    final fileSize = 36 + dataSize;

    final out = ByteData(44 + dataSize);
    var offset = 0;

    // RIFF header
    out.setUint8(offset, 0x52); offset++; // R
    out.setUint8(offset, 0x49); offset++; // I
    out.setUint8(offset, 0x46); offset++; // F
    out.setUint8(offset, 0x46); offset++; // F
    out.setUint32(offset, fileSize, Endian.little); offset += 4;
    out.setUint8(offset, 0x57); offset++; // W
    out.setUint8(offset, 0x41); offset++; // A
    out.setUint8(offset, 0x56); offset++; // V
    out.setUint8(offset, 0x45); offset++; // E

    // fmt sub-chunk
    out.setUint8(offset, 0x66); offset++; // f
    out.setUint8(offset, 0x6D); offset++; // m
    out.setUint8(offset, 0x74); offset++; // t
    out.setUint8(offset, 0x20); offset++; // (space)
    out.setUint32(offset, 16, Endian.little); offset += 4; // chunk size
    out.setUint16(offset, 1, Endian.little); offset += 2; // PCM
    out.setUint16(offset, numChannels, Endian.little); offset += 2;
    out.setUint32(offset, sampleRate, Endian.little); offset += 4;
    out.setUint32(offset, byteRate, Endian.little); offset += 4;
    out.setUint16(offset, blockAlign, Endian.little); offset += 2;
    out.setUint16(offset, bitsPerSample, Endian.little); offset += 2;

    // data sub-chunk
    out.setUint8(offset, 0x64); offset++; // d
    out.setUint8(offset, 0x61); offset++; // a
    out.setUint8(offset, 0x74); offset++; // t
    out.setUint8(offset, 0x61); offset++; // a
    out.setUint32(offset, dataSize, Endian.little); offset += 4;

    // PCM samples with fade-in/out envelope
    final rng = math.Random(42);
    final rampSamples = (sampleRate * 0.02).round(); // 20 ms ramp
    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final envelope = math.min(
        1.0,
        math.min(i / rampSamples, (numSamples - i) / rampSamples),
      );
      final sample = volume *
          envelope *
          (math.sin(2 * math.pi * frequency * t) +
              0.02 * (rng.nextDouble() * 2 - 1));
      var value = (sample * 32767).round().clamp(-32768, 32767);
      out.setInt16(offset, value, Endian.little);
      offset += 2;
    }

    return out.buffer.asUint8List();
  }

  /// Writes WAV bytes to a platform temp directory and returns the file.
  static Future<File> _writeTempWav(Uint8List data, String name) async {
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/echovoice_$name');
    await file.writeAsBytes(data, flush: true);
    return file;
  }

  void dispose() {
    _tts.stop();
    _sfxPlayer.dispose();
    _bgPlayer.dispose();
  }
}
