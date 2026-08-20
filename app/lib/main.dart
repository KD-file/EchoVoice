import 'package:flutter/material.dart';

import 'app.dart';
import 'state/session_state.dart';

void main() {
  runApp(EchoVoiceApp(session: SessionState()));
}
