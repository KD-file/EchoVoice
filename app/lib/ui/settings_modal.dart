import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/session_state.dart';
import '../ui/app_theme.dart';
import 'widgets/app_dialogs.dart';
import 'widgets/sound_toggle_tile.dart';

/// Bottom sheet with the audio settings: background music and sound
/// effects on/off, plus a quick way to leave the app. Opened from the gear
/// icon in the header so the child (or caregiver) can find it instantly.
class SettingsModal extends StatelessWidget {
  const SettingsModal({super.key, required this.session});

  final SessionState session;

  Future<void> _confirmExit(BuildContext context) async {
    final leave = await confirmLeave(
      context,
      title: 'Leave EchoVoice?',
      message: 'Your stars and progress are saved. Come back soon! \u{1F49B}',
      confirmLabel: 'Exit',
    );
    if (leave && context.mounted) {
      Navigator.of(context).pop();
      if (context.mounted) {
        await SystemNavigator.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(32),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Settings',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Turn the music and sounds on or off.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: session,
                builder: (context, _) => Material(
                  color: const Color(0xFFF3FAF7),
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      SoundToggleTile(
                        key: const ValueKey('music-toggle'),
                        emoji: '\u{1F3B5}',
                        label: 'Music',
                        hint: 'Background tunes',
                        value: session.musicEnabled,
                        onChanged: session.setMusicEnabled,
                      ),
                      const Divider(
                        height: 1,
                        indent: 52,
                        endIndent: 12,
                        color: AppColors.tealLight,
                      ),
                      SoundToggleTile(
                        key: const ValueKey('sound-toggle'),
                        emoji: '\u{1F50A}',
                        label: 'Sound effects',
                        hint: 'Prompts and chimes',
                        value: session.soundEnabled,
                        onChanged: session.setSoundEnabled,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                key: const ValueKey('exit-app-button'),
                onPressed: () => _confirmExit(context),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Exit EchoVoice'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.miss,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
