import 'package:flutter/material.dart';

import '../models/category.dart';
import '../state/session_state.dart';
import '../ui/app_theme.dart';

/// A single sound family's word grid. Each card shows the word's emoji,
/// name, and earned stars; tapping it starts the exercise.
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key, required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = session.currentCategory;

    if (category == null) {
      return const SizedBox.shrink();
    }

    final words = category.words;
    final done = session.practicedWordCount(category.id);

    return ListView(
      key: const ValueKey('category-screen'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          '${category.emoji}  ${category.name}',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Sounds: ${category.tagline}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.inkSoft,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: words.isEmpty ? 0 : done / words.length,
                    minHeight: 10,
                    backgroundColor: AppColors.tealLight,
                    color: category.color,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$done / ${words.length} words',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 6
                : constraints.maxWidth >= 720
                    ? 5
                    : constraints.maxWidth >= 520
                        ? 4
                        : 3;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.92,
              children: [
                for (final word in words)
                  _WordCard(
                    word: word,
                    stars: session.starsForExercise(word.exerciseId),
                    attempts: session.attemptCountFor(word.exerciseId),
                    color: category.color,
                    onTap: () {
                      session.openExercise(word.exerciseId);
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              'Practicing ${word.word}! Tap the mic and say '
                              'it. \u{1F3A4}',
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
}

class _WordCard extends StatelessWidget {
  const _WordCard({
    required this.word,
    required this.stars,
    required this.attempts,
    required this.color,
    required this.onTap,
  });

  final CategoryWord word;
  final int stars;
  final int attempts;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Ink(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.tealDark.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        word.emoji,
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                  ),
                  Text(
                    word.word,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _StarRow(stars: stars, color: color),
                  const SizedBox(height: 4),
                  Text(
                    attempts == 0
                        ? 'Not tried yet'
                        : attempts == 1
                            ? 'Tried 1\u00D7'
                            : 'Tried $attempts\u00D7',
                    key: ValueKey('attempt-count-${word.exerciseId}'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: attempts > 0 ? color : AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (attempts > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.stars, required this.color});

  final int stars;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Text(
            i < stars ? '\u2B50' : '\u2606',
            key: ValueKey('star-$i'),
            style: TextStyle(
              fontSize: 14,
              color: i < stars ? AppColors.amberDark : AppColors.inkSoft,
            ),
          ),
      ],
    );
  }
}
