import 'dart:io';

import 'package:echovoice/models/category.dart';
import 'package:echovoice/services/assessment_pipeline.dart';
import 'package:echovoice/services/demo_pipeline.dart';
import 'package:echovoice/services/progress_report_exporter.dart';
import 'package:echovoice/state/session_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<SessionState> practicedSession() async {
    final session = SessionState(persistToDatabase: false);
    session.setProfile(name: 'Maya', age: 8, role: UserRole.learner);
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
    await session.recordAttempt(result: result, exercise: exercise);
    return session;
  }

  test('attemptCountFor counts per-word attempts', () async {
    final session = await practicedSession();
    final exercisedId = session.records.first.exerciseId;
    expect(session.attemptCountFor(exercisedId), 1);
    expect(session.attemptCountFor('unpracticed_word'), 0);
  });

  test('buildDocument produces a valid PDF document', () async {
    final session = await practicedSession();
    final bytes = await ProgressReportExporter.buildDocument(session).save();
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('exportToPdf writes a file into the requested directory', () async {
    final session = await practicedSession();
    final dir = Directory.systemTemp.createTempSync('echovoice_report');
    addTearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    final path =
        await ProgressReportExporter.exportToPdf(session, directory: dir.path);

    expect(path, contains(dir.path));
    final file = File(path);
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(1000));
    expect(
      String.fromCharCodes(file.readAsBytesSync().take(5)),
      '%PDF-',
    );
  });

  test('exportToPdf rejects an un-onboarded session', () {
    final session = SessionState(persistToDatabase: false);
    expect(
      () => ProgressReportExporter.exportToPdf(session),
      throwsA(isA<Object>()),
    );
  });
}
