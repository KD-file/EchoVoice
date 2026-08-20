import 'package:flutter/material.dart';

import '../app_theme.dart';

/// The EchoVoice logo image, shown inside a soft white ring so it looks good
/// on any backdrop. [size] controls the outer diameter.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72, this.ringColor = Colors.white});

  final double size;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(
        color: ringColor,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.tealLight, width: size * 0.035),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealDark.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.jpg',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
