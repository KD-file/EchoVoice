import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:echovoice/app.dart';
import 'package:echovoice/services/demo_pipeline.dart';
import 'package:echovoice/services/tflite_asr_model.dart';
import 'package:echovoice/state/session_state.dart';

void main() {
  setUpAll(() {
    // Tests cannot reach the font CDN; fall back to system fonts.
    GoogleFonts.config.allowRuntimeFetching = false;
    // Keep asset I/O (rootBundle.load) out of the fake-async test zone by
    // always using the demo model, which ignores the audio input anyway.
    asrModelLoader = (targets) async => DemoAsrModelRunner(targets: targets);
  });

  Future<SessionState> onboard(WidgetTester tester) async {
    final session = SessionState(persistToDatabase: false);
    await tester.pumpWidget(
      EchoVoiceApp(session: session, splashDuration: Duration.zero),
    );
    expect(find.byKey(const ValueKey('name-field')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('name-field')), 'Maya');
    await tester.enterText(find.byKey(const ValueKey('age-field')), '8');
    await tester.ensureVisible(find.byKey(const ValueKey('start-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
    expect(find.text('Choose a sound family'), findsOneWidget);
    return session;
  }

  testWidgets('splash shows the logo before onboarding', (tester) async {
    final session = SessionState(persistToDatabase: false);
    await tester.pumpWidget(
      EchoVoiceApp(
          session: session, splashDuration: const Duration(milliseconds: 400)),
    );

    expect(find.byKey(const ValueKey('splash-screen')), findsOneWidget);
    expect(find.text('EchoVoice'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('splash-screen')), findsNothing);
    expect(find.byKey(const ValueKey('name-field')), findsOneWidget);
  });

  testWidgets('onboarding opens the practice home grid', (tester) async {
    await onboard(tester);

    expect(find.text('Popping Sounds'), findsOneWidget);
    expect(find.text('Hissing Sounds'), findsOneWidget);
    expect(find.text('Rolling Sounds'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-pill')), findsOneWidget);
  });

  testWidgets('category -> exercise -> inline result card', (tester) async {
    final session = await onboard(tester);

    await tester.ensureVisible(find.text('Popping Sounds'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Popping Sounds'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category-screen')), findsOneWidget);
    expect(find.text('pig'), findsOneWidget);

    await tester.ensureVisible(find.text('pig'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('pig'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('exercise-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('target-word')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('record-button')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('done-speaking-button')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('done-speaking-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('done-speaking-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('result-card')), findsOneWidget);
    expect(session.records, hasLength(1));
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Next word'), findsOneWidget);

    // Next word advances within the category and hides the result card.
    await tester.ensureVisible(find.text('Next word'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next word'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('result-card')), findsNothing);
    expect(find.byKey(const ValueKey('record-button')), findsOneWidget);
  });

  testWidgets('progress tab toggles learner and caregiver views', (tester) async {
    await onboard(tester);

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('progress-screen')), findsOneWidget);
    expect(find.text('Overall accuracy'), findsOneWidget);
    expect(find.text('Sound accuracy'), findsOneWidget);

    await tester.tap(find.text('Caregiver'));
    await tester.pumpAndSettle();
    expect(find.text('Caregiver dashboard'), findsOneWidget);
    expect(find.text('Assigned practice'), findsOneWidget);
    expect(find.byKey(const ValueKey('assign-button')), findsOneWidget);
  });

  testWidgets('profile sheet opens from the header', (tester) async {
    await onboard(tester);

    await tester.tap(find.byKey(const ValueKey('profile-pill')));
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('music and sound toggles live in the profile sheet',
      (tester) async {
    final session = await onboard(tester);
    expect(session.musicEnabled, isTrue);
    expect(session.soundEnabled, isTrue);

    await tester.tap(find.byKey(const ValueKey('profile-pill')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('music-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('music-toggle')));
    await tester.pumpAndSettle();
    expect(session.musicEnabled, isFalse);

    await tester.ensureVisible(find.byKey(const ValueKey('sound-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sound-toggle')));
    await tester.pumpAndSettle();
    expect(session.soundEnabled, isFalse);
  });

  testWidgets('settings sheet toggles music and sound from the header',
      (tester) async {
    final session = await onboard(tester);

    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('music-toggle')));
    await tester.pumpAndSettle();
    expect(session.musicEnabled, isFalse);

    await tester.tap(find.byKey(const ValueKey('sound-toggle')));
    await tester.pumpAndSettle();
    expect(session.soundEnabled, isFalse);
  });

  testWidgets('system back asks before leaving the app', (tester) async {
    await onboard(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leave EchoVoice?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirm-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Leave EchoVoice?'), findsNothing);
    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
  });

  testWidgets('backing out of a word asks to leave it', (tester) async {
    await onboard(tester);

    await tester.ensureVisible(find.text('Popping Sounds'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Popping Sounds'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('pig'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('pig'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('exercise-screen')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('back-button')));
    await tester.pumpAndSettle();
    expect(find.text('Leave this word?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirm-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('exercise-screen')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('back-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-leave')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category-screen')), findsOneWidget);
  });

  testWidgets('done practicing shows the result and returns home',
      (tester) async {
    final session = await onboard(tester);

    await tester.ensureVisible(find.text('Popping Sounds'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Popping Sounds'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('pig'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('pig'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('record-button')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('done-speaking-button')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('done-speaking-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('done-speaking-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('result-card')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('done-practicing-button')), findsOneWidget);

    await tester
        .ensureVisible(find.byKey(const ValueKey('done-practicing-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('done-practicing-button')));
    await tester.pumpAndSettle();
    expect(find.text('Done practicing?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirm-leave')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
    expect(session.practiceView, PracticeView.home);
  });
}
