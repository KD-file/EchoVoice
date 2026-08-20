import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/category.dart';
import '../state/session_state.dart';
import '../ui/app_theme.dart';
import 'widgets/app_dialogs.dart';
import 'widgets/app_logo.dart';
import 'widgets/sky_grass_background.dart';

/// Onboarding: the child (or caregiver) picks a name, age, and role before
/// entering the app. Matches the mockup's welcome card on the sky.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key, required this.session});

  final SessionState session;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  UserRole _role = UserRole.learner;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim());
    if (name.isEmpty) {
      setState(() => _error = 'Add your name to get started.');
      return;
    }
    if (age == null || age < 3 || age > 99) {
      setState(() => _error = 'Add a valid age (3-99).');
      return;
    }
    widget.session.setProfile(name: name, age: age, role: _role);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        final leave = await confirmLeave(
          context,
          title: 'Leave EchoVoice?',
          message: 'Set up your profile to start practicing!',
          confirmLabel: 'Exit',
        );
        if (leave && context.mounted) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const SkyGrassBackground(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.tealDark.withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppLogo(size: 104),
                          const SizedBox(height: 12),
                          Text(
                            'EchoVoice',
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: AppColors.teal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Learn your speech sounds the fun way!',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            key: const ValueKey('name-field'),
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Your name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const ValueKey('age-field'),
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Your age',
                              prefixIcon: Icon(Icons.cake_outlined),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Who is setting up EchoVoice?',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final learner = _RoleCard(
                                emoji: '\u{1F388}',
                                label: 'Learner',
                                hint: 'I practice my sounds',
                                selected: _role == UserRole.learner,
                                onTap: () => setState(
                                  () => _role = UserRole.learner,
                                ),
                              );
                              final caregiver = _RoleCard(
                                emoji: '\u{1F9D1}\u200D\u2695\uFE0F',
                                label: 'Caregiver',
                                hint: 'I guide practice',
                                selected: _role == UserRole.caregiver,
                                onTap: () =>
                                    setState(() => _role = UserRole.caregiver),
                              );
                              if (constraints.maxWidth < 420) {
                                return Column(
                                  children: [
                                    learner,
                                    const SizedBox(height: 12),
                                    caregiver,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: learner),
                                  const SizedBox(width: 12),
                                  Expanded(child: caregiver),
                                ],
                              );
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.miss,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: FilledButton(
                              key: const ValueKey('start-button'),
                              onPressed: _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.teal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                textStyle:
                                    theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              child: const Text('Start practicing'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.emoji,
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.tealLight : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.teal : const Color(0xFFE0EAE6),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: selected ? AppColors.tealDark : AppColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              hint,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
