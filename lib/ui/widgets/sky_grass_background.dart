import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Full-bleed sky-to-grass backdrop used behind every screen: a soft sky
/// gradient, two drifting clouds, and the green grass hills at the bottom.
class SkyGrassBackground extends StatelessWidget {
  const SkyGrassBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.skyTop, AppColors.skyBottom],
            ),
          ),
        ),
        Positioned(top: 36, left: 28, child: _cloud(44)),
        Positioned(top: 110, right: 40, child: _cloud(34)),
        Positioned(
          left: -80,
          right: -80,
          bottom: -24,
          height: 104,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.grass,
              borderRadius: BorderRadius.vertical(top: Radius.circular(72)),
            ),
          ),
        ),
        Positioned(
          left: -40,
          right: -40,
          bottom: -40,
          height: 92,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.grassDark.withValues(alpha: 0.55),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(60),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cloud(double size) {
    return Opacity(
      opacity: 0.95,
      child: Text(
        '\u2601\uFE0F',
        style: TextStyle(fontSize: size),
      ),
    );
  }
}
