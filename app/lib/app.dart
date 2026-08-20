import 'dart:async';

import 'package:flutter/material.dart';

import 'ui/app_theme.dart';
import 'state/session_state.dart';
import 'ui/home_shell.dart';
import 'ui/splash_screen.dart';
import 'ui/start_screen.dart';

/// Root widget for EchoVoice. Shows the branded splash first, then the
/// onboarding screen until the child's profile is set, then the two-tab
/// shell. Takes a [SessionState] so tests can inject a fully-configured (or
/// non-persisting) session.
class EchoVoiceApp extends StatefulWidget {
  const EchoVoiceApp({
    super.key,
    required this.session,
    this.splashDuration = const Duration(milliseconds: 2200),
  });

  final SessionState session;

  /// How long the splash stays up before the real home is revealed. Tests
  /// pass [Duration.zero] to skip it.
  final Duration splashDuration;

  @override
  State<EchoVoiceApp> createState() => _EchoVoiceAppState();
}

class _EchoVoiceAppState extends State<EchoVoiceApp> {
  Timer? _splashTimer;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    if (widget.splashDuration == Duration.zero) {
      _showSplash = false;
    } else {
      _splashTimer = Timer(widget.splashDuration, () {
        if (mounted) {
          setState(() => _showSplash = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return MaterialApp(
      title: 'EchoVoice',
      debugShowCheckedModeBanner: false,
      theme: buildEchoVoiceTheme(),
      home: _showSplash
          ? const SplashScreen()
          : ListenableBuilder(
              listenable: session,
              builder: (context, _) => session.isOnboarded
                  ? HomeShell(session: session)
                  : StartScreen(session: session),
            ),
    );
  }
}
