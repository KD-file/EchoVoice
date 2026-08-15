import '../models/phoneme_target.dart';
import '../utils/exceptions.dart';

/// Module 1.0 Manage Exercise.
///
/// Matches a caregiver's requested exercise against the child's currently
/// active SLP-configured goals, and exposes the resulting exercise queue
/// to the rest of the app. Kept separate from capture, scoring, and
/// feedback (single responsibility) so exercise-selection logic can be
/// tested and changed independently of those concerns.
class ExerciseManager {
  final List<Exercise> _availableExercises;
  final Set<String> _activeGoalPhonemes;

  ExerciseManager({
    required List<Exercise> availableExercises,
    required Set<String> activeGoalPhonemes,
  })  : _availableExercises = List.unmodifiable(availableExercises),
        _activeGoalPhonemes = Set.unmodifiable(activeGoalPhonemes) {
    if (_availableExercises.isEmpty) {
      throw const ValidationException(
        'ExerciseManager requires a non-empty exercise library.',
      );
    }
  }

  /// Returns exercises whose target phonemes overlap with the child's
  /// currently active SLP goals, ordered by how many active-goal
  /// phonemes each exercise covers (most relevant first).
  ///
  /// Returns an empty list — never null — if nothing matches, so callers
  /// can safely check `.isEmpty` rather than null-checking.
  List<Exercise> exercisesForActiveGoals() {
    if (_activeGoalPhonemes.isEmpty) {
      // Not an error: a child may not yet have SLP-configured goals.
      // The caller (UI layer) decides how to prompt for goal setup.
      return const [];
    }

    final matches = _availableExercises.where((exercise) {
      return exercise.targets
          .any((t) => _activeGoalPhonemes.contains(t.ipaSymbol));
    }).toList();

    matches.sort((a, b) {
      final aMatches = a.targets
          .where((t) => _activeGoalPhonemes.contains(t.ipaSymbol))
          .length;
      final bMatches = b.targets
          .where((t) => _activeGoalPhonemes.contains(t.ipaSymbol))
          .length;
      return bMatches.compareTo(aMatches);
    });

    return matches;
  }

  /// Looks up a specific exercise by id.
  ///
  /// Throws [ValidationException] if no exercise with [exerciseId] exists,
  /// rather than returning null and pushing the null-check obligation onto
  /// every caller.
  Exercise getExerciseById(String exerciseId) {
    final match =
        _availableExercises.where((e) => e.exerciseId == exerciseId).toList();
    if (match.isEmpty) {
      throw ValidationException(
        'No exercise found with id "$exerciseId".',
      );
    }
    return match.first;
  }
}
