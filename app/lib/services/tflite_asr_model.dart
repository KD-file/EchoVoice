import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/phoneme_target.dart';
import '../utils/exceptions.dart';
import 'asr_pipeline.dart';
import 'demo_pipeline.dart';

/// Asset paths for the exported model artifacts. The model file itself is
/// intentionally *not* declared in `pubspec.yaml` until it is produced by
/// `backend/export.py`; [TfliteAsrModelRunner.create] returns null when the
/// asset is absent and the caller falls back to the demo runtime.
const String kModelAssetPath = 'assets/models/echovoice_asr.tflite';
const String kPhonemeSetAssetPath = 'assets/phonemes/phoneme_set.json';

/// Vocabulary + blank-token bookkeeping parsed from the
/// `phoneme_set.json` artifact produced by `backend/export.py`.
class PhonemeSet {
  const PhonemeSet({
    required this.phonemes,
    required this.blankToken,
    required this.blankIndex,
  });

  factory PhonemeSet.fromJson(Map<String, dynamic> json) {
    final phonemes = (json['phonemes'] as List<dynamic>).cast<String>();
    final blankIndex = json['blank_index'] as int;
    if (blankIndex != phonemes.length) {
      throw FormatException(
        'blank_index must equal phonemes.length because the blank is the '
        'final model output channel; got blank_index=$blankIndex, '
        'phonemes.length=${phonemes.length}.',
      );
    }
    return PhonemeSet(
      phonemes: phonemes,
      blankToken: json['blank_token'] as String,
      blankIndex: blankIndex,
    );
  }

  final List<String> phonemes;
  final String blankToken;
  final int blankIndex;

  /// Total model output channels: one per phoneme plus the blank channel.
  int get vocabSize => phonemes.length + 1;

  /// Index-to-symbol map of length [vocabSize] covering every output
  /// channel, with the blank token at [blankIndex].
  List<String> get fullSymbols => [...phonemes, blankToken];
}

/// Step 3.2 — Real on-device ASR runtime behind [AsrModelRunner].
///
/// Loads the exported EchoVoice TFLite model (`assets/models/echovoice_asr
/// .tflite`, produced by `backend/export.py`) plus its phoneme set, runs the
/// fixed 800-frame mel-spectrogram through it, and applies CTC greedy
/// decoding to produce the predicted phoneme sequence.
///
/// The model input is `[1, 800, 80]` (max frames x mel bins, matching
/// [AcousticFeatureExtractor]) and the output is a logit tensor whose last
/// dimension is the vocabulary size, from which blank-removed, repeat
/// collapsed phonemes are read in [decodeCtcLogits].
class TfliteAsrModelRunner implements AsrModelRunner {
  TfliteAsrModelRunner._({
    required Interpreter interpreter,
    required PhonemeSet phonemeSet,
  })  : _interpreter = interpreter,
        _phonemeSet = phonemeSet;

  /// Number of expected input values: one per (max frame, mel bin) pair.
  static const int _inputLength =
      kEchoVoiceMaxFrames * kEchoVoiceNumMelBins;

  final Interpreter _interpreter;
  final PhonemeSet _phonemeSet;

  /// Builds the runner by loading the bundled assets.
  ///
  /// Returns null (rather than throwing) when the TFLite model is not
  /// bundled, the platform has no native TFLite support, or the phoneme set
  /// is unreadable, so callers can fall back to [DemoAsrModelRunner]. The
  /// phoneme set is bundled in `pubspec.yaml`; the model asset is only
  /// present once `backend/export.py` has been run.
  static Future<TfliteAsrModelRunner?> create() async {
    try {
      if (kIsWeb) {
        return null; // tflite_flutter requires native FFI.
      }
      final phonemeSet = PhonemeSet.fromJson(
        jsonDecode(await rootBundle.loadString(kPhonemeSetAssetPath))
            as Map<String, dynamic>,
      );
      final modelData = await rootBundle.load(kModelAssetPath);
      final modelBytes = modelData.buffer.asUint8List(
        modelData.offsetInBytes,
        modelData.lengthInBytes,
      );
      final options = InterpreterOptions()..threads = 2;
      final interpreter = Interpreter.fromBuffer(modelBytes, options: options);
      return TfliteAsrModelRunner._(
        interpreter: interpreter,
        phonemeSet: phonemeSet,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  List<String> predictPhonemes(Float32List melSpectrogram) {
    if (melSpectrogram.length != _inputLength) {
      throw ModelInferenceException(
        'Mel-spectrogram has ${melSpectrogram.length} values; '
        'expected $_inputLength (800 frames x 80 mel bins).',
      );
    }

    final outputSize = _outputElementCount();
    final output = Float32List(outputSize);
    try {
      _interpreter.run(melSpectrogram, output);
    } catch (error) {
      throw ModelInferenceException(
        'TFLite inference failed: $error',
      );
    }

    final vocabSize = _phonemeSet.vocabSize;
    final numFrames = outputSize ~/ vocabSize;
    return decodeCtcLogits(
      output,
      numFrames: numFrames,
      vocabSize: vocabSize,
      blankIndex: _phonemeSet.blankIndex,
      vocab: _phonemeSet.fullSymbols,
    );
  }

  int _outputElementCount() {
    var count = 1;
    for (final dim in _interpreter.getOutputTensor(0).shape) {
      count *= dim;
    }
    return count;
  }
}

/// CTC greedy decoding over [logits] of shape `[numFrames, vocabSize]`.
///
/// Mirrors `torch.argmax` + blank removal + repeat collapsing from the
/// training/export code so on-device results match server-side decoding:
///   * per frame, pick the argmax class;
///   * skip blank frames;
///   * collapse consecutive repeats of the same symbol *unless* a blank
///     frame separates them (CTC semantics: 's s _ s' decodes to "s s").
///
/// [vocab] is the full index-to-symbol map of length [vocabSize] (the blank
/// token sits at [blankIndex]); [blankIndex] must index [vocab].
List<String> decodeCtcLogits(
  Float32List logits, {
  required int numFrames,
  required int vocabSize,
  required int blankIndex,
  required List<String> vocab,
}) {
  if (vocab.length != vocabSize) {
    throw ArgumentError(
      'vocab must have exactly $vocabSize entries, '
      'got ${vocab.length}.',
    );
  }
  if (blankIndex < 0 || blankIndex >= vocabSize) {
    throw ArgumentError('blankIndex $blankIndex is out of range.');
  }

  final predicted = <String>[];
  var previous = -1;
  for (var frame = 0; frame < numFrames; frame++) {
    final offset = frame * vocabSize;
    var best = blankIndex;
    var bestScore = double.negativeInfinity;
    for (var classIndex = 0; classIndex < vocabSize; classIndex++) {
      final score = logits[offset + classIndex];
      if (score > bestScore) {
        bestScore = score;
        best = classIndex;
      }
    }
    if (best == blankIndex) {
      previous = -1; // blank separates repeats.
      continue;
    }
    if (best == previous) {
      continue; // collapse runs of the same symbol.
    }
    predicted.add(vocab[best]);
    previous = best;
  }
  return predicted;
}

/// Builds the ASR runtime for the app: the real TFLite model when it is
/// bundled, otherwise the deterministic [DemoAsrModelRunner] so the app
/// stays fully runnable in development and CI.
Future<AsrModelRunner> createAsrModelRunner(List<PhonemeTarget> targets) async {
  final tflite = await TfliteAsrModelRunner.create();
  if (tflite != null) {
    return tflite;
  }
  return DemoAsrModelRunner(targets: targets);
}

/// Signature for the function that builds the ASR runtime for an exercise.
typedef AsrModelLoader = Future<AsrModelRunner> Function(
  List<PhonemeTarget> targets,
);

/// The active model loader. Defaults to [createAsrModelRunner], which probes
/// the bundled TFLite model via `rootBundle`; widget tests replace this with
/// a demo-only loader so no asset I/O happens inside the fake-async test
/// zone (see `test/ui_smoke_test.dart`).
AsrModelLoader asrModelLoader = createAsrModelRunner;
