import 'dart:typed_data';

import '../models/attempt_outcome.dart';
import '../models/phoneme_target.dart';
import 'asr_pipeline.dart';

/// Orchestrates one assessment attempt: PCM audio in, scores out. It chains
/// the existing pipeline stages (extraction -> inference -> alignment ->
/// scoring) so the UI only deals with a single, high-level call.
class OnDeviceAssessor {
  OnDeviceAssessor({required AsrModelRunner model}) : _model = model;

  final AsrModelRunner _model;
  final AcousticFeatureExtractor _extractor = AcousticFeatureExtractor();
  final PhonemeAligner _aligner = PhonemeAligner();
  final PronunciationScorer _scorer = PronunciationScorer();

  AssessmentResult assess({
    required Uint8List pcm,
    required Exercise exercise,
  }) {
    final features = _extractor.extractMelSpectrogram(
      pcm,
      sampleRateHz: kEchoVoiceSampleRateHz,
    );
    final predicted = _model.predictPhonemes(features);
    final alignment = _aligner.align(predicted, exercise.targets);
    return AssessmentResult(
      predicted: predicted,
      alignment: alignment,
      accuracyScore: _scorer.computeAccuracyScore(alignment),
      phonemeErrorRate: _scorer.computePhonemeErrorRate(alignment),
    );
  }
}
