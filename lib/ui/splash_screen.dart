import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'widgets/app_logo.dart';
import 'widgets/sky_grass_background.dart';

/// Branded splash shown before onboarding while the app warms up. Purely
/// cosmetic: it fades and scales the logo in, then EchoVoiceApp swaps it for
/// the start screen (or the shell if already onboarded).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const ValueKey('splash-screen'),
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const SkyGrassBackground(),
          SafeArea(
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutBack,
                builder: (context, value, child) => Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.7 + 0.3 * value,
                    child: child,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppLogo(size: 150),
                    const SizedBox(height: 20),
                    Text(
                      'EchoVoice',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Learn your speech sounds the fun way!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.teal,
                        backgroundColor: AppColors.tealLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
