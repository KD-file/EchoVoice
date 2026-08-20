import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/session_state.dart';
import '../ui/app_theme.dart';
import 'category_screen.dart';
import 'exercise_screen.dart';
import 'home_screen.dart';
import 'progress_screen.dart';
import 'profile_modal.dart';
import 'widgets/app_dialogs.dart';
import 'widgets/app_logo.dart';
import 'widgets/pressable_scale.dart';
import 'widgets/sky_grass_background.dart';
import 'settings_modal.dart';

/// Root scaffold for signed-in users: the persistent header (brand, star
/// pill, profile pill), the Practice tab (home -> category -> exercise) and
/// the Progress tab (Learner / Caregiver views), over the sky-and-grass backdrop.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.session});

  final SessionState session;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  /// Steps back through practice; asks before leaving an exercise mid-word.
  Future<void> _handleBack() async {
    final session = widget.session;
    if (session.practiceView == PracticeView.exercise) {
      final leave = await confirmLeave(
        context,
        title: 'Leave this word?',
        message: 'You can try it again anytime from the word list.',
        confirmLabel: 'Leave',
        emoji: '\u{1F501}',
      );
      if (!leave || !mounted) {
        return;
      }
    }
    session.back();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final canGoBack = session.practiceView != PracticeView.home;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) {
              return;
            }
            // Back inside practice steps up a level; back at the root asks
            // before leaving the app.
            if (session.practiceView != PracticeView.home) {
              await _handleBack();
              return;
            }
            final leave = await confirmLeave(
              context,
              title: 'Leave EchoVoice?',
              message: 'Your stars and progress are saved. Come back soon! '
                  '\u{1F49B}',
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
                  child: Column(
                    children: [
                      _Header(
                        session: session,
                        canGoBack: canGoBack,
                        onBack: canGoBack ? _handleBack : null,
                      ),
                      Expanded(
                        child: IndexedStack(
                          index: _tab,
                          children: [
                            _PracticeBody(session: session),
                            ProgressScreen(session: session),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _TabBar(
              index: _tab,
              onChanged: (index) => setState(() => _tab = index),
            ),
          ),
        );
      },
    );
  }
}

/// Routes inside the Practice tab: home grid, a category's words, or the
/// exercise for the selected word.
class _PracticeBody extends StatelessWidget {
  const _PracticeBody({required this.session});

  final SessionState session;

  static const _viewOrder = {
    PracticeView.home: 0,
    PracticeView.category: 1,
    PracticeView.exercise: 2,
  };

  @override
  Widget build(BuildContext context) {
    final view = session.practiceView;
    final index = _viewOrder[view] ?? 0;
    final isForward = index >= (_lastViewIndex ?? 0);
    _lastViewIndex = index;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final isNew = child.key == ValueKey(view.name);
        final offset = isNew
            ? (isForward
                ? const Offset(0.3, 0.0)
                : const Offset(-0.3, 0.0))
            : (isForward
                ? const Offset(-0.3, 0.0)
                : const Offset(0.3, 0.0));
        return SlideTransition(
          position: Tween<Offset>(begin: offset, end: Offset.zero)
              .animate(animation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(view.name),
        child: switch (view) {
          PracticeView.home => HomeScreen(session: session),
          PracticeView.category => CategoryScreen(session: session),
          PracticeView.exercise => ExerciseScreen(session: session),
        },
      ),
    );
  }

  static int? _lastViewIndex;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.session,
    required this.canGoBack,
    required this.onBack,
  });

  final SessionState session;
  final bool canGoBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = session.name ?? '';
    final compact = MediaQuery.sizeOf(context).width < 440;

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 8 : 12, 6, compact ? 8 : 12, 4),
      child: Row(
        children: [
          if (canGoBack)
            IconButton(
              key: const ValueKey('back-button'),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 26),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Row(
              children: [
                const AppLogo(size: 38),
                if (!compact) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'EchoVoice',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.tealDark,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _StarPill(count: session.totalStars),
          const SizedBox(width: 8),
          _SettingsButton(onTap: () => _openSettings(context)),
          const SizedBox(width: 8),
          _ProfilePill(
            name: name,
            compact: compact,
            onTap: () => _openProfile(context),
          ),
        ],
      ),
    );
  }

  void _openProfile(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ProfileModal(session: session),
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SettingsModal(session: session),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Material(
        color: Colors.white.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        child: InkWell(
          key: const ValueKey('settings-button'),
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(
              Icons.settings_rounded,
              size: 22,
              color: AppColors.tealDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _StarPill extends StatelessWidget {
  const _StarPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.amberDark.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('\u2B50', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            '$count',
            key: const ValueKey('star-count'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({
    required this.name,
    required this.compact,
    required this.onTap,
  });

  final String name;
  final bool compact;
  final VoidCallback onTap;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }
    return parts.first[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressableScale(
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('profile-pill'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: EdgeInsets.fromLTRB(6, 6, compact ? 6 : 10, 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.tealDark.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.teal,
                  child: Text(
                    _initials,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.inkSoft,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.tealDark.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              _TabButton(
                label: 'Practice',
                emoji: '\u{1F3A4}',
                selected: index == 0,
                onTap: () => onChanged(0),
              ),
              const SizedBox(width: 6),
              _TabButton(
                label: 'Progress',
                emoji: '\u{1F4CA}',
                selected: index == 1,
                onTap: () => onChanged(1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.teal : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: selected ? Colors.white : AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
