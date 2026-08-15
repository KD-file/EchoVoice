import 'package:flutter/material.dart';

import '../models/category.dart';
import '../state/session_state.dart';
import '../ui/app_theme.dart';
import 'widgets/app_logo.dart';

/// Practice home: a welcome card and the grid of sound families. Tapping a
/// family opens its word list.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      key: const ValueKey('home-screen'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _WelcomeCard(session: session),
        const SizedBox(height: 20),
        Text(
          'Choose a sound family',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Tap a group to practice its words.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.inkSoft,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 620
                    ? 2
                    : 2;
            final aspect = constraints.maxWidth >= 900
                ? 1.5
                : constraints.maxWidth >= 620
                    ? 1.2
                    : 0.92;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: aspect,
              children: [
                for (final category in session.categories)
                  _CategoryCard(
                    category: category,
                    progressLabel: _progressLabel(category),
                    onTap: () {
                      session.openCategory(category.id);
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              'Opening ${category.name} \u2014 let\u2019s '
                              'practice!',
                            ),
                            duration: const Duration(milliseconds: 1200),
                          ),
                        );
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _progressLabel(SoundCategory category) {
    final done = session.practicedWordCount(category.id);
    final total = category.words.length;
    return '$done/$total words \u2022 ${session.starsForCategory(category.id)} '
        'stars';
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = session.name ?? 'Friend';
    final words = session.practicedWords;
    final stars = session.totalStars;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, AppColors.tealLight],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealDark.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $name! \u{1F44B}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppColors.tealDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Let\u2019s practice your speech sounds.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(
                      label: '$words words \u2728',
                      color: AppColors.tealLight,
                    ),
                    _Pill(
                      label: '$stars stars \u2B50',
                      color: AppColors.amber.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const AppLogo(size: 84),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.ink,
            ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.progressLabel,
    required this.onTap,
  });

  final SoundCategory category;
  final String progressLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: category.colorLight,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: category.color.withValues(alpha: 0.35),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(category.emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(
                category.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                category.tagline,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: category.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                progressLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.inkSoft,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
