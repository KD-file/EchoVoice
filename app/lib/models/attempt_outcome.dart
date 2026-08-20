import '../services/asr_pipeline.dart';
import 'phoneme_target.dart';

/// The result of running one recording through the on-device assessment
/// pipeline (feature extraction -> inference -> alignment -> scoring).
class AssessmentResult {
  const AssessmentResult({
    required this.predicted,
    required this.alignment,
    required this.accuracyScore,
    required this.phonemeErrorRate,
  });

  /// Phoneme sequence produced by the ASR model for this attempt.
  final List<String> predicted;

  /// Per-position alignment of [predicted] against the exercise targets.
  final List<AlignmentOp> alignment;

  /// Fraction of aligned positions that were matches, in [0.0, 1.0].
  final double accuracyScore;

  /// Fraction of aligned positions that were errors, in [0.0, 1.0].
  final double phonemeErrorRate;
}

/// A fully-scored attempt plus the caregiver-facing feedback message,
/// ready to hand to the feedback screen.
class AttemptOutcome {
  const AttemptOutcome({
    required this.exercise,
    required this.result,
    required this.feedbackMessage,
  });

  final Exercise exercise;
  final AssessmentResult result;
  final String feedbackMessage;
}
