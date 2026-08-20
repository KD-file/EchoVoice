import '../utils/exceptions.dart';

/// Generates caregiver-facing feedback messages and tracks session-level
/// performance state for the current feedback session.
class FeedbackGenerator {
  double lastScore = 0.0;
  int streak = 0;

  FeedbackGenerator();

  /// Produces a feedback message for [word] based on the normalized [score].
  /// Scores are expected to be within [0.0, 1.0].
  String generateMessage(double score, String word) {
    if (word.trim().isEmpty) {
      throw const ValidationException('Word must not be empty.');
    }
    if (score < 0.0 || score > 1.0) {
      throw ValidationException(
        'Score must be within [0.0, 1.0], got $score.',
      );
    }

    lastScore = score;
    if (score >= 0.9) {
      streak += 1;
    } else {
      streak = 0;
    }

    if (score >= 0.9) {
      return 'Great! $word sounded perfect! \u{1F389}';
    }
    if (score >= 0.7) {
      return 'Good job on $word, almost there! \u{1F642}';
    }
    if (score >= 0.5) {
      return 'Nice try on $word, keep practicing! \u{1F4AA}';
    }
    return 'Keep going! Let\u2019s try $word again. \u{1F504}';
  }

  /// Plays an audio prompt or reward sound.
  ///
  /// This method is intentionally kept platform-agnostic to avoid binding
  /// the core logic to a specific audio playback implementation. A real
  /// platform integration can wrap this method in the UI layer.
  void playSound(String name) {
    if (name.trim().isEmpty) {
      throw const ValidationException('Audio asset name must not be empty.');
    }
    // Placeholder implementation. A platform-specific audio player should
    // supply the actual playback behavior in the application layer.
  }
}
