import 'dart:math' as math;
import 'dart:typed_data';

import '../models/phoneme_target.dart';
import 'asr_pipeline.dart';

/// Error rate (per target phoneme) used by [DemoAsrModelRunner] so the demo
/// produces a mix of correct and incorrect sounds instead of always being
/// perfect.
const double kDemoErrorRate = 0.35;

/// A stand-in ASR model for exercising the app end-to-end without a real
/// TFLite model on device. It deliberately ignores the mel-spectrogram input
/// and "predicts" phonemes that resemble the expected targets with some
/// probability of substitution, insertion, and deletion.
///
/// Replace this with a real runtime (e.g. tflite_flutter loading
/// assets/models/echovoice_asr.tflite) behind the [AsrModelRunner] interface;
/// the rest of the app does not change.
class DemoAsrModelRunner implements AsrModelRunner {
  DemoAsrModelRunner({
    required List<PhonemeTarget> targets,
    double errorRate = kDemoErrorRate,
    math.Random? random,
  })  : _targets = targets,
        _errorRate = errorRate.clamp(0.0, 1.0),
        _random = random ?? math.Random();

  final List<PhonemeTarget> _targets;
  final double _errorRate;
  final math.Random _random;

  /// Acoustically confusable substitutes per target symbol.
  static const Map<String, List<String>> _confusions = {
    's': ['ʃ', 'θ'],
    'z': ['s', 'ð'],
    'ʃ': ['s', 'tʃ'],
    'tʃ': ['ʃ', 't'],
    'dʒ': ['ʒ', 'd'],
    'f': ['θ', 'v'],
    'v': ['f', 'b'],
    'θ': ['f', 's'],
    'ð': ['z', 'd'],
    'h': ['f', 's'],
    'p': ['b', 't'],
    'b': ['p', 'd'],
    't': ['k', 'd'],
    'd': ['t', 'b'],
    'k': ['t', 'g'],
    'g': ['k', 'd'],
    'm': ['n', 'b'],
    'n': ['m', 'd'],
    'l': ['w', 'r'],
    'r': ['w', 'l'],
    'w': ['l', 'r'],
    'j': ['l', 'i'],
    'i': ['ɪ', 'e'],
    'ɪ': ['i', 'e'],
    'e': ['ɪ', 'æ'],
    'æ': ['ʌ', 'e'],
    'ʌ': ['ɑ', 'æ'],
    'ɑ': ['ʌ', 'ɔ'],
    'ɔ': ['ɑ', 'o'],
    'o': ['ɔ', 'u'],
    'u': ['ʊ', 'o'],
    'ʊ': ['u', 'ʌ'],
  };

  static const List<String> _fallbackSymbols = [
    's',
    't',
    'k',
    'ʃ',
    'f',
    'p',
    'b',
    'd',
    'n',
    'm',
    'i',
    'æ',
    'ʌ',
    'o',
    'u',
  ];

  @override
  List<String> predictPhonemes(Float32List melSpectrogram) {
    final predicted = <String>[];
    for (final target in _targets) {
      if (_random.nextDouble() < _errorRate) {
        predicted.add(_confuse(target.ipaSymbol));
      } else {
        predicted.add(target.ipaSymbol);
      }
    }

    // Occasionally insert an extra sound the child "said".
    if (_targets.isNotEmpty && _random.nextDouble() < _errorRate * 0.5) {
      final index = _random.nextInt(predicted.length + 1);
      predicted.insert(index, _randomSymbol());
    }

    // Occasionally drop one sound the child "missed".
    if (predicted.length > 1 && _random.nextDouble() < _errorRate * 0.4) {
      predicted.removeAt(_random.nextInt(predicted.length));
    }

    return predicted;
  }

  String _confuse(String symbol) {
    final options = _confusions[symbol];
    if (options == null || options.isEmpty) {
      return _randomSymbol();
    }
    return options[_random.nextInt(options.length)];
  }

  String _randomSymbol() {
    return _fallbackSymbols[_random.nextInt(_fallbackSymbols.length)];
  }
}

/// Produces synthetic 16-bit PCM audio so recording works in the demo
/// without a microphone or platform plugin. Generates roughly 1.2 s of a
/// banded tone with light noise, within the extractor's accepted window
/// (300 ms - 8 s at 16 kHz).
///
/// Swap for a real mic implementation (e.g. the `record` plugin) behind the
/// same `capture()` contract.
class SyntheticPcmRecorder {
  static const int _sampleRate = kEchoVoiceSampleRateHz;
  static const double _seconds = 1.2;

  Uint8List capture() {
    final n = (_sampleRate * _seconds).round();
    final rng = math.Random(42);
    final samples = Float64List(n);
    final ramp = (0.02 * _sampleRate).round();

    for (var i = 0; i < n; i++) {
      final t = i / _sampleRate;
      final env = math.min(
        1.0,
        math.min(i / ramp, (n - i) / ramp),
      );
      final tone = 0.6 * math.sin(2 * math.pi * 220 * t);
      final noise = 0.02 * (rng.nextDouble() * 2 - 1);
      samples[i] = (tone + noise) * env;
    }

    final out = Uint8List(n * 2);
    final data = ByteData.view(out.buffer);
    for (var i = 0; i < n; i++) {
      var value = (samples[i] * 32767).round();
      if (value < -32768) value = -32768;
      if (value > 32767) value = 32767;
      data.setInt16(i * 2, value, Endian.little);
    }
    return out;
  }
}
