import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:echovoice/models/category.dart';
import 'package:echovoice/models/phoneme_target.dart';
import 'package:echovoice/services/asr_pipeline.dart';
import 'package:echovoice/services/assessment_pipeline.dart';
import 'package:echovoice/services/demo_pipeline.dart';
import 'package:echovoice/state/session_state.dart';

void main() {
  group('DemoAsrModelRunner', () {
    test('is perfect when error rate is zero', () {
      final targets = _targets(['s', 'ʌ', 'n']);
      final model = DemoAsrModelRunner(
        targets: targets,
        errorRate: 0.0,
        random: math.Random(1),
      );
      final predicted = model.predictPhonemes(Float32List(0));
      expect(predicted, ['s', 'ʌ', 'n']);
    });

    test('introduces errors with a high error rate', () {
      final targets = _targets(['s', 'ʌ', 'n']);
      final model = DemoAsrModelRunner(
        targets: targets,
        errorRate: 1.0,
        random: math.Random(2),
      );
      final predicted = model.predictPhonemes(Float32List(0));
      expect(
          predicted.any((p) => !targets.any((t) => t.ipaSymbol == p)), isTrue);
    });
  });

  group('SyntheticPcmRecorder', () {
    test('produces in-range 16-bit PCM at 16 kHz', () {
      final pcm = SyntheticPcmRecorder().capture();
      expect(pcm.length % 2, 0);
      expect(pcm.length, (16000 * 2 * 1.2).round()); // 1.2s -> above 300 ms min
      expect(
          () => AcousticFeatureExtractor().extractMelSpectrogram(
                pcm,
                sampleRateHz: kEchoVoiceSampleRateHz,
              ),
          returnsNormally);
    });
  });

  group('OnDeviceAssessor', () {
    test('scores a perfect prediction at 1.0', () {
      final exercise = _exercise(['s', 'ʌ', 'n']);
      final assessor = OnDeviceAssessor(
        model: DemoAsrModelRunner(
          targets: exercise.targets,
          errorRate: 0.0,
        ),
      );
      final result = assessor.assess(
        pcm: SyntheticPcmRecorder().capture(),
        exercise: exercise,
      );
      expect(result.predicted, ['s', 'ʌ', 'n']);
      expect(result.accuracyScore, 1.0);
      expect(result.phonemeErrorRate, 0.0);
    });

    test('scores stay within [0, 1] with errors', () {
      final exercise = _exercise(['tʃ', 'i', 'z']);
      final assessor = OnDeviceAssessor(
        model: DemoAsrModelRunner(
          targets: exercise.targets,
          errorRate: 0.8,
          random: math.Random(3),
        ),
      );
      final result = assessor.assess(
        pcm: SyntheticPcmRecorder().capture(),
        exercise: exercise,
      );
      expect(result.accuracyScore, inInclusiveRange(0.0, 1.0));
      expect(result.phonemeErrorRate, inInclusiveRange(0.0, 1.0));
      expect(result.alignment, isNotEmpty);
    });
  });

  group('SessionState', () {
    test('starts un-onboarded with five categories', () {
      final session = SessionState(persistToDatabase: false);
      expect(session.isOnboarded, isFalse);
      expect(session.categories, hasLength(5));
      expect(session.currentCategoryExercises, isEmpty);
    });

    test('setProfile onboarded and resets to home', () {
      final session = SessionState(persistToDatabase: false);
      session.setProfile(
        name: 'Maya',
        age: 8,
        role: UserRole.learner,
      );
      expect(session.isOnboarded, isTrue);
      expect(session.name, 'Maya');
      expect(session.age, 8);
      expect(session.role, UserRole.learner);
      expect(session.practiceView, PracticeView.home);
    });

    test('category navigation exposes category exercises', () {
      final session = SessionState(persistToDatabase: false);
      final category = session.categories.first;
      session.openCategory(category.id);
      expect(session.practiceView, PracticeView.category);
      expect(session.currentCategory?.id, category.id);
      expect(session.currentCategoryExercises, isNotEmpty);

      final exercise = session.currentCategoryExercises.first;
      session.openExercise(exercise.exerciseId);
      expect(session.practiceView, PracticeView.exercise);
      expect(session.currentExercise?.exerciseId, exercise.exerciseId);

      session.back();
      expect(session.practiceView, PracticeView.category);
      session.back();
      expect(session.practiceView, PracticeView.home);
    });

    test('every category word resolves to a library exercise', () {
      final session = SessionState(persistToDatabase: false);
      for (final category in session.categories) {
        session.openCategory(category.id);
        final exercises = session.currentCategoryExercises;
        expect(category.words, isNotEmpty);
        for (final word in category.words) {
          final exists = exercises
              .where((e) => e.exerciseId == word.exerciseId)
              .isNotEmpty;
          expect(exists, isTrue,
              reason: '${word.word} should exist in the exercise library');
        }
      }
    });

    test('nextExercise wraps around the current category', () {
      final session = SessionState(persistToDatabase: false);
      final category = session.categories.first;
      session.openCategory(category.id);
      final first = session.currentCategoryExercises.first.exerciseId;
      session.openExercise(first);
      session.nextExercise();
      final second = session.currentExercise!.exerciseId;
      expect(second, isNot(first));
      session.nextExercise();
      session.nextExercise();
      expect(session.currentExercise, isNotNull);
    });

    test('recordAttempt updates history, streak, stars, and feedback',
        () async {
      final session = SessionState(persistToDatabase: false);
      final category = session.categories.first;
      session.openCategory(category.id);
      final exercise = session.currentCategoryExercises.first;
      session.openExercise(exercise.exerciseId);

      final assessor = OnDeviceAssessor(
        model: DemoAsrModelRunner(
          targets: exercise.targets,
          errorRate: 0.0,
        ),
      );
      final result = assessor.assess(
        pcm: SyntheticPcmRecorder().capture(),
        exercise: exercise,
      );

      final outcome = await session.recordAttempt(
        result: result,
        exercise: exercise,
      );

      expect(session.records, hasLength(1));
      expect(session.streak, 1);
      expect(session.lastScore, 1.0);
      expect(session.starsForExercise(exercise.exerciseId), 3);
      expect(session.totalStars, 3);
      expect(outcome.feedbackMessage, isNotEmpty);
      expect(outcome.feedbackMessage, contains('Great'));
    });

    test('assignCategories drives assigned status', () {
      final session = SessionState(persistToDatabase: false);
      final ids = {session.categories[0].id, session.categories[1].id};
      session.assignCategories(ids);
      expect(session.assignedCategoryIds, ids);
      expect(session.isAssigned(ids.first), isTrue);
      expect(session.isAssigned(session.categories.last.id), isFalse);
    });

    test('music and sound settings toggle independently', () {
      final session = SessionState(persistToDatabase: false);
      expect(session.musicEnabled, isTrue);
      expect(session.soundEnabled, isTrue);

      session.setMusicEnabled(false);
      expect(session.musicEnabled, isFalse);
      expect(session.soundEnabled, isTrue);

      session.setSoundEnabled(false);
      expect(session.musicEnabled, isFalse);
      expect(session.soundEnabled, isFalse);

      session.setMusicEnabled(true);
      expect(session.musicEnabled, isTrue);
      expect(session.soundEnabled, isFalse);
    });
  });
}

List<PhonemeTarget> _targets(List<String> symbols) {
  return [
    for (var i = 0; i < symbols.length; i++)
      PhonemeTarget(
        ipaSymbol: symbols[i],
        expectedPosition: i,
        difficultyWeight: 1.0,
      ),
  ];
}

Exercise _exercise(List<String> symbols) {
  return Exercise(
    exerciseId: symbols.join(),
    displayWord: symbols.join(),
    targets: _targets(symbols),
  );
}
