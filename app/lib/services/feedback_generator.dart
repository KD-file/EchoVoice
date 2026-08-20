import '../utils/exceptions.dart';
import 'audio_service.dart';

/// Generates caregiver-facing feedback messages and tracks session-level
/// performance state for the current feedback session.
class FeedbackGenerator {
  double lastScore = 0.0;
  int streak = 0;
  AudioService? _audio;

  FeedbackGenerator({AudioService? audio}) : _audio = audio;

  /// Injects or replaces the audio service used by [playSound].
  void setAudioService(AudioService audio) => _audio = audio;

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

  /// Plays an audio prompt or reward sound via the injected [AudioService].
  ///
  /// Falls back to a no-op when no audio service is available (e.g. in tests).
  Future<void> playSound(String name) async {
    if (name.trim().isEmpty) {
      throw const ValidationException('Audio asset name must not be empty.');
    }
    final audio = _audio;
    if (audio != null) {
      await audio.playSound(name);
    }
  }
}
