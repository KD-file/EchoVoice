import 'package:flutter/material.dart';

import 'app.dart';
import 'state/session_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = SessionState();
  runApp(EchoVoiceApp(session: session));
}
