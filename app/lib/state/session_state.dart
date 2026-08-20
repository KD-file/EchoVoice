import 'package:flutter/foundation.dart';

import '../data/categories.dart';
import '../data/exercise_library.dart';
import '../db/database_helper.dart';
import '../models/attempt_outcome.dart';
import '../models/category.dart';
import '../models/phoneme_target.dart';
import '../services/asr_pipeline.dart';
import '../services/feedback_generator.dart';
import '../services/progress_monitor.dart';

/// Where the learner is inside the Practice tab.
enum PracticeView { home, category, exercise }

/// Holds the app-wide session state: the learner's profile and role, the
/// current category / word they are practicing, earned stars, the
/// caregiver's assigned practice, and the in-memory record of attempts
/// (mirrored into SQLite when available).
///
/// Exposes the existing service layer (FeedbackGenerator, ProgressMonitor,
/// DatabaseHelper) to the UI through one listenable, so the screens stay
/// thin and everything else can be tested without widgets.
class SessionState extends ChangeNotifier {
  SessionState({
    List<Exercise>? exercises,
    List<SoundCategory>? categories,
    bool persistToDatabase = true,
    DatabaseHelper? database,
  })  : _library = exercises ?? defaultExerciseLibrary(),
        _persistToDatabase = persistToDatabase,
        _database = database ?? DatabaseHelper(),
        categories = categories ??
            buildCategories(exercises ?? defaultExerciseLibrary()) {
    _exerciseById = {
      for (final exercise in _library) exercise.exerciseId: exercise
    };
    for (final category in this.categories) {
      for (final word in category.words) {
        _categoryByExercise[word.exerciseId] = category;
      }
    }
  }

  final List<Exercise> _library;
  final bool _persistToDatabase;
  final DatabaseHelper _database;
  late final Map<String, Exercise> _exerciseById;
  final Map<String, SoundCategory> _categoryByExercise = {};

  /// The five sound families the learner can practice.
  final List<SoundCategory> categories;

  /// Caregiver-facing feedback state (streak, last message).
  final FeedbackGenerator feedback = FeedbackGenerator();

  /// Summary statistics over all attempts in this session.
  final ProgressMonitor progress = ProgressMonitor();

  /// Every attempt recorded this session, most recent last.
  final List<AssessmentRecord> records = [];

  /// Profile and role set during onboarding.
  UserRole role = UserRole.learner;
  String? name;
  int? age;

  /// Navigation state within the Practice tab.
  PracticeView practiceView = PracticeView.home;
  String? selectedCategoryId;
  String? selectedExerciseId;

  /// Sound families the caregiver has assigned the child to practice.
  Set<String> assignedCategoryIds = {};

  /// Whether the background music track is enabled. Stored so the UI can
  /// restore the child's preference across sessions.
  bool musicEnabled = true;

  /// Whether sound effects (prompts, chimes) are enabled.
  bool soundEnabled = true;

  String? _lastFeedbackMessage;
  double? _lastScore;

  bool get isOnboarded => name != null && name!.trim().isNotEmpty;

  int get streak => feedback.streak;

  String? get lastFeedbackMessage => _lastFeedbackMessage;

  double? get lastScore => _lastScore;

  /// Exercises for the currently selected category.
  List<Exercise> get currentCategoryExercises {
    final category = currentCategory;
    if (category == null) {
      return const [];
    }
    return [
      for (final word in category.words)
        if (_exerciseById.containsKey(word.exerciseId))
          _exerciseById[word.exerciseId]!,
    ];
  }

  SoundCategory? get currentCategory {
    final id = selectedCategoryId;
    if (id == null) {
      return null;
    }
    for (final category in categories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  Exercise? get currentExercise {
    final id = selectedExerciseId;
    if (id == null) {
      return null;
    }
    return _exerciseById[id];
  }

  /// Total stars earned across every practiced word.
  int get totalStars => categories.fold(
      0, (sum, category) => sum + starsForCategory(category.id));

  /// Number of words that have been practiced at least once.
  int get practicedWords => categories.fold(
      0, (sum, category) => sum + practicedWordCount(category.id));

  double? get averageAccuracy {
    if (records.isEmpty) {
      return null;
    }
    var total = 0.0;
    for (final record in records) {
      total += record.accuracyScore;
    }
    return total / records.length;
  }

  /// Sets the learner's profile from the onboarding screen.
  void setProfile({
    required String name,
    required int age,
    required UserRole role,
  }) {
    this.name = name.trim();
    this.age = age;
    this.role = role;
    practiceView = PracticeView.home;
    notifyListeners();
  }

  /// Edits profile fields without resetting navigation (used from the
  /// profile sheet).
  void updateProfile({required String name, required int age}) {
    this.name = name.trim();
    this.age = age;
    notifyListeners();
  }

  void setRole(UserRole value) {
    role = value;
    notifyListeners();
  }

  void openCategory(String id) {
    selectedCategoryId = id;
    selectedExerciseId = null;
    practiceView = PracticeView.category;
    notifyListeners();
  }

  void openExercise(String exerciseId) {
    final category = _categoryByExercise[exerciseId];
    if (category != null) {
      selectedCategoryId = category.id;
    }
    selectedExerciseId = exerciseId;
    practiceView = PracticeView.exercise;
    notifyListeners();
  }

  void back() {
    practiceView = switch (practiceView) {
      PracticeView.exercise => PracticeView.category,
      _ => PracticeView.home,
    };
    notifyListeners();
  }

  void goHome() {
    selectedCategoryId = null;
    selectedExerciseId = null;
    practiceView = PracticeView.home;
    notifyListeners();
  }

  void nextExercise() {
    final exercises = currentCategoryExercises;
    if (exercises.isEmpty) {
      return;
    }
    final index =
        exercises.indexWhere((e) => e.exerciseId == selectedExerciseId);
    final next = exercises[(index + 1) % exercises.length];
    selectedExerciseId = next.exerciseId;
    notifyListeners();
  }

  void assignCategories(Set<String> ids) {
    assignedCategoryIds = {...ids};
    notifyListeners();
  }

  /// Turns background music on or off. Music is a global preference that
  /// applies to every screen (a real build would drive an audio player).
  void setMusicEnabled(bool enabled) {
    if (musicEnabled == enabled) {
      return;
    }
    musicEnabled = enabled;
    notifyListeners();
  }

  /// Turns sound effects on or off. When off, prompt and reward sounds are
  /// muted so the child can practice quietly.
  void setSoundEnabled(bool enabled) {
    if (soundEnabled == enabled) {
      return;
    }
    soundEnabled = enabled;
    notifyListeners();
  }

  bool isAssigned(String categoryId) =>
      assignedCategoryIds.contains(categoryId);

  SoundCategory? categoryFor(String categoryId) {
    for (final category in categories) {
      if (category.id == categoryId) {
        return category;
      }
    }
    return null;
  }

  /// Stars (0-3) for a word, from its most recent attempt.
  int starsForExercise(String exerciseId) {
    for (final record in records.reversed) {
      if (record.exerciseId == exerciseId) {
        return starsForAccuracy(record.accuracyScore);
      }
    }
    return 0;
  }

  /// Number of times a word has been attempted this session. Used by the UI
  /// to show how much a child has practiced each word (interactive feedback).
  int attemptCountFor(String exerciseId) {
    var count = 0;
    for (final record in records) {
      if (record.exerciseId == exerciseId) {
        count++;
      }
    }
    return count;
  }

  static int starsForAccuracy(double accuracy) {
    if (accuracy >= 0.9) {
      return 3;
    }
    if (accuracy >= 0.7) {
      return 2;
    }
    if (accuracy >= 0.5) {
      return 1;
    }
    return 0;
  }

  /// Number of words in a category that have at least one star.
  int practicedWordCount(String categoryId) {
    final category = categoryFor(categoryId);
    if (category == null) {
      return 0;
    }
    var count = 0;
    for (final word in category.words) {
      if (starsForExercise(word.exerciseId) > 0) {
        count++;
      }
    }
    return count;
  }

  int starsForCategory(String categoryId) {
    final category = categoryFor(categoryId);
    if (category == null) {
      return 0;
    }
    var stars = 0;
    for (final word in category.words) {
      stars += starsForExercise(word.exerciseId);
    }
    return stars;
  }

  /// Average accuracy across all attempts for a category (null if none).
  double? accuracyForCategory(String categoryId) {
    var total = 0.0;
    var count = 0;
    for (final record in records) {
      final category = _categoryByExercise[record.exerciseId];
      if (category != null && category.id == categoryId) {
        total += record.accuracyScore;
        count++;
      }
    }
    return count == 0 ? null : total / count;
  }

  /// Records a scored attempt: updates feedback/streak, appends to the
  /// in-memory history, and (when persistence is enabled) writes to SQLite.
  /// Database failures are swallowed so the demo keeps working on desktop.
  Future<AttemptOutcome> recordAttempt({
    required AssessmentResult result,
    required Exercise exercise,
  }) async {
    final accuracy = result.accuracyScore;
    final message = feedback.generateMessage(accuracy, exercise.displayWord);
    _lastFeedbackMessage = message;
    _lastScore = accuracy;

    final record = AssessmentRecord(
      attemptId: '${DateTime.now().microsecondsSinceEpoch}',
      exerciseId: exercise.exerciseId,
      recordedAt: DateTime.now(),
      predictedPhonemes: result.predicted,
      accuracyScore: accuracy,
      phonemeErrorRate: result.phonemeErrorRate,
      phonemeErrorMatrix: serializeAlignment(result.alignment),
    );
    records.add(record);
    progress.addRecord({
      'score': accuracy,
      'attempt_id': record.attemptId,
      'exercise_id': exercise.exerciseId,
      'word': exercise.displayWord,
    });

    if (_persistToDatabase) {
      try {
        await _database.saveAssessmentRecord(record);
      } on Exception {
        // SQLite is not available on every platform (e.g. desktop demo);
        // the in-memory history above remains authoritative for the session.
      }
    }

    notifyListeners();
    return AttemptOutcome(
      exercise: exercise,
      result: result,
      feedbackMessage: message,
    );
  }
}
