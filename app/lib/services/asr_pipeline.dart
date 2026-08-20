import 'dart:convert';
import 'dart:math' as math;
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

/// Feature contract shared with `backend/echovoice_ml/features.py`. These
/// constants reproduce the exact STFT + mel-filterbank math on-device so
/// TFLite results and server-side results are computed over identical inputs.
const int kEchoVoiceFrameLength = 400; // 25 ms at 16 kHz
const int kEchoVoiceHopLength = 160; // 10 ms at 16 kHz
const int kEchoVoiceFftSize = 512;
const int kEchoVoiceNumMelBins = 80;
const double kEchoVoiceMelFminHz = 80.0;
const double kEchoVoiceMelFmaxHz = 7600.0;
const double kEchoVoiceLogOffset = 1e-6;
const int kEchoVoiceMaxFrames = 800; // 8 s at 10 ms/frame

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

  /// Converts [pcm] (16-bit little-endian PCM) into a fixed-shape
  /// [kEchoVoiceMaxFrames] x [kEchoVoiceNumMelBins] log-mel spectrogram,
  /// returned flat (row-major) as the float32 input tensor for the model.
  ///
  /// Mirrors `features.extract_to_buffer` in `backend/echovoice_ml/features.py`
  /// (via `features.wav_to_mel` for the resampling step) so on-device features
  /// match server-side features bit-for-bit in math. Audio captured at a rate
  /// other than 16 kHz is linearly resampled to the feature contract rate
  /// before STFT, exactly like `features._resample_linear`.
  Float32List _computeMelSpectrogram(Uint8List pcm, int sampleRateHz) {
    var samples = _pcmToSamples(pcm);
    if (sampleRateHz != kEchoVoiceSampleRateHz) {
      samples = _resampleLinear(samples, sampleRateHz, kEchoVoiceSampleRateHz);
    }
    final magnitude = _stftMagnitude(
      samples,
      frameLength: kEchoVoiceFrameLength,
      hopLength: kEchoVoiceHopLength,
      nFft: kEchoVoiceFftSize,
      window: _hannWindow(kEchoVoiceFrameLength),
    );
    const numBins = kEchoVoiceFftSize ~/ 2 + 1;
    final numFrames = magnitude.length ~/ numBins;
    final filterbank = _melFilterbank();

    final out = Float32List(kEchoVoiceMaxFrames * kEchoVoiceNumMelBins);
    for (var t = 0; t < numFrames && t < kEchoVoiceMaxFrames; t++) {
      for (var m = 0; m < kEchoVoiceNumMelBins; m++) {
        var energy = 0.0;
        for (var k = 0; k < numBins; k++) {
          final mag = magnitude[t * numBins + k];
          energy += mag * mag * filterbank[m * numBins + k];
        }
        out[t * kEchoVoiceNumMelBins + m] =
            math.log(energy + kEchoVoiceLogOffset);
      }
    }
    return out;
  }

  /// Decodes 16-bit little-endian PCM bytes into float64 samples in [-1, 1],
  /// matching `features.read_wav` (divide by 32768.0).
  Float64List _pcmToSamples(Uint8List pcm) {
    final data = ByteData.view(pcm.buffer, pcm.offsetInBytes, pcm.length);
    final samples = Float64List(pcm.length ~/ 2);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }

  /// Crude linear resampler mirroring `features._resample_linear` (which in
  /// turn mirrors `np.interp` over a [0, 1] normalized time axis). Used to
  /// bring non-16 kHz capture audio up/down to the feature contract rate.
  Float64List _resampleLinear(Float64List samples, int srcRate, int dstRate) {
    final n = _roundHalfEven(samples.length * dstRate / srcRate);
    final xOld = _linspace(0.0, 1.0, samples.length);
    final xNew = _linspace(0.0, 1.0, n);
    final out = Float64List(n);
    for (var i = 0; i < n; i++) {
      out[i] = _interpLinear(xOld, samples, xNew[i]);
    }
    return out;
  }

  /// Linear interpolation matching `np.interp` for an input clamped to the
  /// range of [xOld] (both axes span [0, 1], so no clamping is needed here).
  double _interpLinear(Float64List xOld, Float64List yOld, double x) {
    if (x <= xOld[0]) return yOld[0];
    if (x >= xOld[xOld.length - 1]) return yOld[yOld.length - 1];
    var lo = 0;
    var hi = xOld.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (xOld[mid] <= x) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final span = xOld[hi] - xOld[lo];
    final frac = span == 0 ? 0.0 : (x - xOld[lo]) / span;
    return yOld[lo] + (yOld[hi] - yOld[lo]) * frac;
  }

  /// Round-half-to-even, matching Python's built-in `round` so the resampled
  /// length is identical to `features._resample_linear`.
  int _roundHalfEven(double x) {
    final f = x.floorToDouble();
    final diff = x - f;
    if (diff < 0.5) return f.toInt();
    if (diff > 0.5) return (f + 1).toInt();
    return f.toInt().isEven ? f.toInt() : f.toInt() + 1;
  }

  /// DFT-symmetric Hann window (window[0] == window[n - 1] == 0), matching
  /// `features.hann_window`.
  Float64List _hannWindow(int length) {
    final window = Float64List(length);
    for (var i = 0; i < length; i++) {
      window[i] = 0.5 * (1.0 - math.cos(2.0 * math.pi * i / (length - 1)));
    }
    return window;
  }

  /// STFT magnitude spectrum of shape [numFrames, nFft // 2 + 1], flattened
  /// row-major, matching `features.stft`.
  Float64List _stftMagnitude(
    Float64List samples, {
    required int frameLength,
    required int hopLength,
    required int nFft,
    required Float64List window,
  }) {
    if (samples.length < frameLength) {
      return Float64List(0);
    }
    final numFrames = (samples.length - frameLength) ~/ hopLength + 1;
    final numBins = nFft ~/ 2 + 1;
    final magnitude = Float64List(numFrames * numBins);
    final re = Float64List(nFft);
    final im = Float64List(nFft);
    for (var t = 0; t < numFrames; t++) {
      final start = t * hopLength;
      re.fillRange(0, nFft, 0.0);
      im.fillRange(0, nFft, 0.0);
      for (var i = 0; i < frameLength; i++) {
        re[i] = samples[start + i] * window[i];
      }
      _fftRadix2(re, im, nFft);
      for (var k = 0; k < numBins; k++) {
        magnitude[t * numBins + k] = math.sqrt(re[k] * re[k] + im[k] * im[k]);
      }
    }
    return magnitude;
  }

  /// In-place iterative radix-2 FFT (Cooley-Tukey, bit-reversal first).
  /// Unnormalized, matching numpy's `np.fft.rfft`.
  void _fftRadix2(Float64List re, Float64List im, int n) {
    for (var i = 1, j = 0; i < n; i++) {
      var bit = n >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        var tmp = re[i];
        re[i] = re[j];
        re[j] = tmp;
        tmp = im[i];
        im[i] = im[j];
        im[j] = tmp;
      }
    }
    for (var len = 2; len <= n; len <<= 1) {
      final ang = -2.0 * math.pi / len;
      final wRe = math.cos(ang);
      final wIm = math.sin(ang);
      for (var i = 0; i < n; i += len) {
        var curRe = 1.0;
        var curIm = 0.0;
        for (var k = 0; k < len ~/ 2; k++) {
          final uRe = re[i + k];
          final uIm = im[i + k];
          final vRe =
              re[i + k + len ~/ 2] * curRe - im[i + k + len ~/ 2] * curIm;
          final vIm =
              re[i + k + len ~/ 2] * curIm + im[i + k + len ~/ 2] * curRe;
          re[i + k] = uRe + vRe;
          im[i + k] = uIm + vIm;
          re[i + k + len ~/ 2] = uRe - vRe;
          im[i + k + len ~/ 2] = uIm - vIm;
          final nextRe = curRe * wRe - curIm * wIm;
          curIm = curRe * wIm + curIm * wRe;
          curRe = nextRe;
        }
      }
    }
  }

  /// Triangular mel-scale filterbank of shape
  /// [kEchoVoiceNumMelBins, nFft // 2 + 1], flattened row-major, matching
  /// `features.mel_filterbank`.
  Float64List _melFilterbank() {
    const numBins = kEchoVoiceFftSize ~/ 2 + 1;
    final filterbank = Float64List(kEchoVoiceNumMelBins * numBins);
    final fftFreqs = _linspace(0.0, kEchoVoiceSampleRateHz / 2.0, numBins);
    final melPoints = _linspace(
      _hzToMel(kEchoVoiceMelFminHz),
      _hzToMel(kEchoVoiceMelFmaxHz),
      kEchoVoiceNumMelBins + 2,
    );
    final hzPoints = [for (final m in melPoints) _melToHz(m)];

    for (var m = 0; m < kEchoVoiceNumMelBins; m++) {
      final left = hzPoints[m];
      final center = hzPoints[m + 1];
      final right = hzPoints[m + 2];
      if (right - left <= 0) continue;
      for (var k = 0; k < numBins; k++) {
        final f = fftFreqs[k];
        final rising = (f - left) / (center - left + 1e-12);
        final falling = (right - f) / (right - center + 1e-12);
        final triangle = math.min(rising, falling);
        if (triangle > 0) filterbank[m * numBins + k] = triangle;
      }
    }
    return filterbank;
  }

  static double _hzToMel(double hz) => 1127.0 * math.log(1.0 + hz / 700.0);

  static double _melToHz(double mel) => 700.0 * (math.exp(mel / 1127.0) - 1.0);

  /// Inclusive linspace matching numpy's `np.linspace`.
  Float64List _linspace(double start, double end, int count) {
    final out = Float64List(count);
    if (count == 1) {
      out[0] = start;
      return out;
    }
    final step = (end - start) / (count - 1);
    for (var i = 0; i < count; i++) {
      out[i] = start + i * step;
    }
    return out;
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

/// Serializes an alignment as JSON for storage in the
/// `phoneme_error_matrix` column of the Progress Database.
/// Each op is `{"predicted_index": int|null, "target_index": int,
/// "op_type": "match"|"substitution"|"insertion"|"deletion"}`.
String serializeAlignment(List<AlignmentOp> alignment) {
  return jsonEncode([
    for (final op in alignment)
      {
        'predicted_index': op.predictedIndex,
        'target_index': op.targetIndex,
        'op_type': op.opType.name,
      },
  ]);
}

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
