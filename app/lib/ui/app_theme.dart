import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The EchoVoice palette, lifted from the design mockup.
abstract final class AppColors {
  static const Color skyTop = Color(0xFFBFEAF5);
  static const Color skyBottom = Color(0xFFEAF7FA);
  static const Color grass = Color(0xFF8FD08A);
  static const Color grassDark = Color(0xFF6EB86C);
  static const Color amber = Color(0xFFFFC857);
  static const Color amberDark = Color(0xFFE8A33D);
  static const Color coral = Color(0xFFFF7B5A);
  static const Color coralDark = Color(0xFFE85C3C);
  static const Color teal = Color(0xFF1F8A70);
  static const Color tealDark = Color(0xFF0E5C48);
  static const Color tealLight = Color(0xFFDFF4EE);
  static const Color ink = Color(0xFF2B3A3A);
  static const Color inkSoft = Color(0xFF5B6B6A);
  static const Color ok = Color(0xFF2E9E6B);
  static const Color warn = Color(0xFFF29E4C);
  static const Color miss = Color(0xFFF0595A);
  static const Color surface = Colors.white;
}

/// Global theme: Baloo 2 for headings/brand, Quicksand for body, matching
/// the mockup's warm, rounded feel.
ThemeData buildEchoVoiceTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      primary: AppColors.teal,
      secondary: AppColors.amber,
      error: AppColors.miss,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: Colors.transparent,
    splashFactory: InkSparkle.splashFactory,
  );

  final quicksand = GoogleFonts.quicksandTextTheme();
  final baloo = GoogleFonts.baloo2TextTheme();

  final body = base.textTheme.copyWith(
    bodyLarge: quicksand.bodyLarge?.copyWith(color: AppColors.ink),
    bodyMedium: quicksand.bodyMedium?.copyWith(color: AppColors.ink),
    bodySmall: quicksand.bodySmall?.copyWith(color: AppColors.inkSoft),
    labelLarge: quicksand.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    labelMedium: quicksand.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.inkSoft,
    ),
    labelSmall: quicksand.labelSmall?.copyWith(color: AppColors.inkSoft),
  );

  return base.copyWith(
    textTheme: body.copyWith(
      displayLarge: baloo.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      displayMedium: baloo.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      displaySmall: baloo.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      headlineLarge: baloo.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      headlineMedium: baloo.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      headlineSmall: baloo.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      titleLarge: baloo.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      titleMedium: baloo.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      titleSmall: baloo.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.ink,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: GoogleFonts.quicksand(
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: GoogleFonts.quicksand(
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      contentTextStyle: GoogleFonts.quicksand(
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF3FAF7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.tealLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.teal, width: 2),
      ),
    ),
  );
}
