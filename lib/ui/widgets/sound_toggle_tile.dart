import 'package:flutter/material.dart';

import '../app_theme.dart';

/// A labelled on/off switch row used by the profile and settings sheets for
/// toggling music and sound effects.
class SoundToggleTile extends StatelessWidget {
  const SoundToggleTile({
    super.key,
    required this.emoji,
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final String emoji;
  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.teal,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      secondary: Text(emoji, style: const TextStyle(fontSize: 22)),
      title: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(color: AppColors.ink),
      ),
      subtitle: Text(
        hint,
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.inkSoft,
        ),
      ),
    );
  }
}
