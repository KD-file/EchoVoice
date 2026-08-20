import '../utils/exceptions.dart';

/// Represents a single target phoneme within an [Exercise], corresponding
/// to the PHONEME_TARGET entity in the study's Entity-Relationship Diagram.
///
/// Instances are immutable: once constructed, a [PhonemeTarget] cannot be
/// mutated. This avoids an entire class of bugs where shared state is
/// modified unexpectedly from a different part of the app.
class PhonemeTarget {
  /// IPA symbol for the target phoneme, e.g. "/s/", "/tʃ/".
  final String ipaSymbol;

  /// Zero-based index of this phoneme's expected position within the
  /// parent word's phoneme sequence.
  final int expectedPosition;

  /// Relative difficulty weight (0.0-1.0) used when computing a weighted
  /// pronunciation score; harder phonemes can be weighted more heavily.
  final double difficultyWeight;

  PhonemeTarget({
    required this.ipaSymbol,
    required this.expectedPosition,
    required this.difficultyWeight,
  }) {
    // Defensive programming: validate invariants at construction time so
    // that an invalid PhonemeTarget can never exist in the system. Failing
    // fast here, rather than downstream during scoring, makes the source
    // of a bad value immediately obvious.
    if (ipaSymbol.trim().isEmpty) {
      throw const ValidationException(
        'PhonemeTarget.ipaSymbol must not be empty.',
      );
    }
    if (expectedPosition < 0) {
      throw ValidationException(
        'PhonemeTarget.expectedPosition must be >= 0, got $expectedPosition.',
      );
    }
    if (difficultyWeight < 0.0 || difficultyWeight > 1.0) {
      throw ValidationException(
        'PhonemeTarget.difficultyWeight must be within [0.0, 1.0], '
        'got $difficultyWeight.',
      );
    }
  }

  @override
  String toString() =>
      'PhonemeTarget(ipaSymbol: $ipaSymbol, position: $expectedPosition, '
      'weight: $difficultyWeight)';
}

/// Represents a practice exercise (a target word or phrase built from one
/// or more [PhonemeTarget]s), corresponding to the EXERCISE entity.
class Exercise {
  final String exerciseId;
  final String displayWord;
  final List<PhonemeTarget> targets;

  Exercise({
    required this.exerciseId,
    required this.displayWord,
    required this.targets,
  }) {
    if (exerciseId.trim().isEmpty) {
      throw const ValidationException('Exercise.exerciseId must not be empty.');
    }
    if (targets.isEmpty) {
      throw ValidationException(
        'Exercise "$exerciseId" must have at least one PhonemeTarget.',
      );
    }
  }
}

/// The outcome of scoring one recorded attempt against an [Exercise]'s
/// target phonemes, corresponding to the ASSESSMENT_RECORD entity.
class AssessmentRecord {
  final String attemptId;
  final String exerciseId;
  final DateTime recordedAt;
  final List<String> predictedPhonemes;
  final double accuracyScore;
  final double phonemeErrorRate;

  /// Per-phoneme error breakdown serialized as JSON, matching the
  /// `phoneme_error_matrix` column in the Progress Database. Each element is
  /// an op record from [AlignmentOp] (predicted index, target index, and
  /// operation type). Defaults to an empty matrix `'[]'`.
  final String phonemeErrorMatrix;

  AssessmentRecord({
    required this.attemptId,
    required this.exerciseId,
    required this.recordedAt,
    required this.predictedPhonemes,
    required this.accuracyScore,
    required this.phonemeErrorRate,
    this.phonemeErrorMatrix = '[]',
  }) {
    if (accuracyScore < 0.0 || accuracyScore > 1.0) {
      throw ValidationException(
        'AssessmentRecord.accuracyScore must be within [0.0, 1.0], '
        'got $accuracyScore.',
      );
    }
    if (phonemeErrorRate < 0.0) {
      throw ValidationException(
        'AssessmentRecord.phonemeErrorRate must be >= 0.0, '
        'got $phonemeErrorRate.',
      );
    }
  }
}
