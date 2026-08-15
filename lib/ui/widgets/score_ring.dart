import 'package:flutter/material.dart';

import '../app_theme.dart';

/// A circular accuracy gauge with the percentage in the center. Color shifts
/// green -> red as accuracy drops so the child gets an immediate, glanceable
/// result.
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.accuracy, this.size = 180});

  final double accuracy;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clamped = accuracy.clamp(0.0, 1.0);
    final color = clamped >= 0.9
        ? AppColors.ok
        : clamped >= 0.7
            ? AppColors.warn
            : AppColors.miss;
    final strokeWidth = size / 12;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: clamped,
              strokeWidth: strokeWidth,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(clamped * 100).round()}%',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
              ),
              Text(
                'accuracy',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.inkSoft,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
