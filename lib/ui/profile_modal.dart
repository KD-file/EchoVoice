import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/category.dart';
import '../state/session_state.dart';
import '../ui/app_theme.dart';
import 'widgets/app_dialogs.dart';
import 'widgets/sound_toggle_tile.dart';

/// Bottom sheet showing the learner's profile with inline editing of name,
/// age, and role, plus a snapshot of what they have achieved.
class ProfileModal extends StatefulWidget {
  const ProfileModal({super.key, required this.session});

  final SessionState session;

  @override
  State<ProfileModal> createState() => _ProfileModalState();
}

class _ProfileModalState extends State<ProfileModal> {
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.session.name);
    _ageController = TextEditingController(
      text: widget.session.age?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _save() {
    final messenger = ScaffoldMessenger.of(context);
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim());
    if (name.isEmpty) {
      setState(() => _error = 'Name cannot be empty.');
      return;
    }
    if (age == null || age < 3 || age > 99) {
      setState(() => _error = 'Enter a valid age (3-99).');
      return;
    }
    widget.session.updateProfile(name: name, age: age);
    Navigator.of(context).pop();
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Profile saved! \u{1F44D}'),
          duration: Duration(milliseconds: 1500),
        ),
      );
  }

  /// Asks for confirmation, then leaves the app. The sheet is popped first so
  /// the exit dialog appears on top of the shell, not inside the sheet.
  Future<void> _confirmExit() async {
    final leave = await confirmLeave(
      context,
      title: 'Leave EchoVoice?',
      message: 'Your stars and progress are saved. Come back soon! \u{1F49B}',
      confirmLabel: 'Exit',
    );
    if (leave && mounted) {
      Navigator.of(context).pop();
      if (mounted) {
        await SystemNavigator.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = widget.session;
    final average = session.averageAccuracy;

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
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 16),
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.tealLight,
                child: Text(
                  _initials,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AppColors.tealDark,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                session.name ?? '',
                style: theme.textTheme.headlineSmall,
              ),
              Text(
                '${session.age ?? '-'} years old \u2022 ${session.role.label}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _MiniStat(
                    label: 'Stars',
                    value: '${session.totalStars}',
                    emoji: '\u2B50',
                  ),
                  _MiniStat(
                    label: 'Words',
                    value: '${session.practicedWords}',
                    emoji: '\u2728',
                  ),
                  _MiniStat(
                    label: 'Accuracy',
                    value:
                        average == null ? '--' : '${(average * 100).round()}%',
                    emoji: '\u{1F3AF}',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Edit profile',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: 'Age',
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Role',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _RoleChip(
                    emoji: '\u{1F388}',
                    label: 'Learner',
                    selected: session.role == UserRole.learner,
                    onTap: () => session.setRole(UserRole.learner),
                  ),
                  const SizedBox(width: 10),
                  _RoleChip(
                    emoji: '\u{1F9D1}\u200D\u2695\uFE0F',
                    label: 'SLP-Caregiver',
                    selected: session.role == UserRole.slp,
                    onTap: () => session.setRole(UserRole.slp),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sounds',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
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
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.miss,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  key: const ValueKey('exit-app-button'),
                  onPressed: _confirmExit,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _initials {
    final name = widget.session.name?.trim() ?? '';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }
    return parts.first[0].toUpperCase();
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.emoji,
  });

  final String label;
  final String value;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.tealLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.tealDark,
              ),
            ),
            Text(label, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.tealLight : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.teal : const Color(0xFFE0EAE6),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected ? AppColors.tealDark : AppColors.inkSoft,
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
