import 'dart:typed_data';

import '../models/phoneme_target.dart';
import '../utils/exceptions.dart';

/// Minimum audio length, in milliseconds, accepted for feature extraction.
/// Anything shorter is almost certainly a truncated or failed recording
/// rather than real speech, so it is rejected before it reaches the model.
const int kMinimumAudioDurationMs = 300;

/// Maximum audio length, in milliseconds, accepted for a single attempt.
/// Bounds memory use and keeps inference latency predictable on
/// consumer-grade hardware, per Objective 3's feasibility requirement.
const int kMaximumAudioDurationMs = 8000;

/// Default capture/feature sample rate shared by the recorder, feature
/// extractor, and model input. Matches the ML feature contract
/// (ml/config/model_config.yaml: sample_rate 16000).
const int kEchoVoiceSampleRateHz = 16000;

/// Step 3.1 — Extract Acoustic Features.
///
/// Converts raw PCM audio into a mel-spectrogram tensor suitable for the
/// on-device ASR model. This class has a single responsibility (feature
/// extraction) and does not know about inference, alignment, or scoring,
/// which keeps each stage of the pipeline independently testable.
class AcousticFeatureExtractor {
  /// Normalizes and converts [rawAudioPcm] into a mel-spectrogram tensor.
  ///
  /// Throws [AudioCaptureException] if [rawAudioPcm] is empty or falls
  /// outside the accepted duration range, and [ArgumentError] if
  /// [sampleRateHz] is not a supported rate.
  Float32List extractMelSpectrogram(
    Uint8List rawAudioPcm, {
    required int sampleRateHz,
  }) {
    // Defensive checks: never hand malformed input further down the
    // pipeline. Failing here with a specific, typed exception makes the
    // failure easy to diagnose and keeps invalid state out of the model.
    if (rawAudioPcm.isEmpty) {
      throw const AudioCaptureException(
        'Cannot extract features from an empty audio buffer.',
      );
    }

    const supportedSampleRates = {8000, 16000, 44100, 48000};
    if (!supportedSampleRates.contains(sampleRateHz)) {
      throw ArgumentError.value(
        sampleRateHz,
        'sampleRateHz',
        'Unsupported sample rate. Supported rates: $supportedSampleRates',
      );
    }

    final durationMs = (rawAudioPcm.length / (sampleRateHz * 2 / 1000)).round();
    if (durationMs < kMinimumAudioDurationMs) {
      throw AudioCaptureException(
        'Recording too short ($durationMs ms); likely an incomplete '
        'capture. Minimum accepted duration is $kMinimumAudioDurationMs ms.',
      );
    }
    if (durationMs > kMaximumAudioDurationMs) {
      throw AudioCaptureException(
        'Recording too long ($durationMs ms). Maximum accepted duration '
        'is $kMaximumAudioDurationMs ms.',
      );
    }

    return _computeMelSpectrogram(rawAudioPcm, sampleRateHz);
  }

  /// Placeholder for the actual DSP work (windowing, FFT, mel filterbank
  /// application). Kept private since callers only need the public,
  /// validated entry point above.
  Float32List _computeMelSpectrogram(Uint8List pcm, int sampleRateHz) {
    // Real implementation would use an FFT + mel-filterbank library
    // (e.g., via a native plugin). Returning a correctly-shaped zero
    // tensor here so the rest of the pipeline is exercisable/testable.
    const numMelBins = 80;
    const numFrames = 100;
    return Float32List(numMelBins * numFrames);
  }
}

/// Step 3.2 — Run Model Inference.
///
/// Wraps the on-device ASR runtime (TFLite/ONNX). Isolating this behind
/// an interface means the concrete runtime can be swapped or mocked in
/// tests without touching the rest of the pipeline (dependency inversion).
abstract class AsrModelRunner {
  /// Runs inference on [melSpectrogram] and returns a predicted phoneme
  /// sequence. Implementations must throw [ModelInferenceException] on
  /// failure rather than returning a null or empty result silently.
  List<String> predictPhonemes(Float32List melSpectrogram);
}

/// Step 3.3 — Align Phonemes.
///
/// Aligns the model's [predicted] phoneme sequence against the exercise's
/// [target] phoneme sequence using edit-distance dynamic programming, so
/// that substitutions, insertions, and deletions can be identified
/// individually rather than only producing a single pass/fail result.
///
/// Operation types:
///   * [AlignmentOpType.match]        — predicted[i] aligns with target[j],
///                                      symbols equal
///   * [AlignmentOpType.substitution] — predicted[i] aligns with target[j],
///                                      symbols differ
///   * [AlignmentOpType.deletion]     — predicted symbol has no counterpart
///                                      in the target
///   * [AlignmentOpType.insertion]    — target symbol has no counterpart in
///                                      the prediction
///
/// Mirrors `echovoice_ml.alignment.align` so on-device and server-side
/// scoring agree on identical inputs.
class PhonemeAligner {
  /// Returns an alignment as a list of (predictedIndex, targetIndex, opType)
  /// records. `opType` is one of 'match', 'substitution', 'insertion',
  /// 'deletion'.
  List<AlignmentOp> align(
    List<String> predicted,
    List<PhonemeTarget> target,
  ) {
    if (target.isEmpty) {
      // An exercise with no target phonemes is a data error further up
      // the system (see PhonemeTarget/Exercise validation), not something
      // this method should silently tolerate.
      throw const PhonemeAlignmentException(
        'Cannot align against an empty target phoneme sequence.',
      );
    }
    if (predicted.isEmpty) {
      // A legitimate outcome (e.g. the child said nothing intelligible),
      // not an error — every target phoneme has no counterpart in the
      // prediction, so each is scored as an insertion rather than throwing.
      return List<AlignmentOp>.generate(
        target.length,
        (j) => AlignmentOp(
          predictedIndex: null,
          targetIndex: j,
          opType: AlignmentOpType.insertion,
        ),
      );
    }

    return _computeEditDistanceAlignment(predicted, target);
  }

  List<AlignmentOp> _computeEditDistanceAlignment(
    List<String> predicted,
    List<PhonemeTarget> target,
  ) {
    final m = predicted.length;
    final n = target.length;
    // dp[i][j] = edit distance between predicted[:i] and target[:j].
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

    for (var i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      dp[0][j] = j;
    }

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = predicted[i - 1] == target[j - 1].ipaSymbol ? 0 : 1;
        dp[i][j] = _min3(
          dp[i - 1][j] + 1, // delete predicted[i-1]
          dp[i][j - 1] + 1, // insert target[j-1]
          dp[i - 1][j - 1] + cost, // match / substitution
        );
      }
    }

    // Backtrack from the bottom-right cell, preferring diagonal
    // (match/substitution) over delete and insert, to recover a minimal
    // edit script.
    final ops = <AlignmentOp>[];
    var i = m;
    var j = n;
    while (i > 0 || j > 0) {
      final sameSymbol =
          i > 0 && j > 0 && predicted[i - 1] == target[j - 1].ipaSymbol;
      if (sameSymbol && dp[i][j] == dp[i - 1][j - 1]) {
        ops.add(AlignmentOp(
          predictedIndex: i - 1,
          targetIndex: j - 1,
          opType: AlignmentOpType.match,
        ));
        i -= 1;
        j -= 1;
      } else if (i > 0 && j > 0 && dp[i][j] == dp[i - 1][j - 1] + 1) {
        ops.add(AlignmentOp(
          predictedIndex: i - 1,
          targetIndex: j - 1,
          opType: AlignmentOpType.substitution,
        ));
        i -= 1;
        j -= 1;
      } else if (i > 0 && dp[i][j] == dp[i - 1][j] + 1) {
        ops.add(AlignmentOp(
          predictedIndex: i - 1,
          targetIndex: j,
          opType: AlignmentOpType.deletion,
        ));
        i -= 1;
      } else {
        ops.add(AlignmentOp(
          predictedIndex: null,
          targetIndex: j - 1,
          opType: AlignmentOpType.insertion,
        ));
        j -= 1;
      }
    }
    return ops.reversed.toList();
  }

  static int _min3(int a, int b, int c) {
    if (a <= b && a <= c) return a;
    if (b <= a && b <= c) return b;
    return c;
  }
}

class AlignmentOp {
  final int? predictedIndex;
  final int targetIndex;
  final AlignmentOpType opType;

  AlignmentOp({
    required this.predictedIndex,
    required this.targetIndex,
    required this.opType,
  });
}

enum AlignmentOpType { match, substitution, insertion, deletion }

/// Step 3.4 — Compute Pronunciation Score.
///
/// Converts an alignment into the accuracy score and phoneme error rate
/// that get written to the Progress Database as part of an
/// [AssessmentRecord].
class PronunciationScorer {
  double computeAccuracyScore(List<AlignmentOp> alignment) {
    if (alignment.isEmpty) {
      // No target phonemes to score against is a caller error — the
      // aligner should never return an empty list for a non-empty target.
      throw const PhonemeAlignmentException(
        'computeAccuracyScore received an empty alignment.',
      );
    }
    final matches =
        alignment.where((op) => op.opType == AlignmentOpType.match).length;
    return matches / alignment.length;
  }

  double computePhonemeErrorRate(List<AlignmentOp> alignment) {
    if (alignment.isEmpty) {
      throw const PhonemeAlignmentException(
        'computePhonemeErrorRate received an empty alignment.',
      );
    }
    final errors =
        alignment.where((op) => op.opType != AlignmentOpType.match).length;
    return errors / alignment.length;
  }
}
