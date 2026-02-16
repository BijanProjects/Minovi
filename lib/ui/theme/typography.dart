import 'package:flutter/material.dart';

/// Material 3 typography scale — system font, no custom fonts.
abstract final class ChronoTypography {
  static TextTheme get textTheme => const TextTheme(
    displayLarge: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 32,
      height: 40 / 32,
      letterSpacing: -0.5,
    ),
    displayMedium: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 28,
      height: 36 / 28,
      letterSpacing: -0.25,
    ),
    headlineLarge: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 24,
      height: 32 / 24,
      letterSpacing: 0,
    ),
    headlineMedium: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 20,
      height: 28 / 20,
      letterSpacing: 0,
    ),
    titleLarge: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 18,
      height: 26 / 18,
      letterSpacing: 0,
    ),
    titleMedium: TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 16,
      height: 24 / 16,
      letterSpacing: 0.15,
    ),
    bodyLarge: TextStyle(
      fontWeight: FontWeight.normal,
      fontSize: 16,
      height: 24 / 16,
      letterSpacing: 0.15,
    ),
    bodyMedium: TextStyle(
      fontWeight: FontWeight.normal,
      fontSize: 14,
      height: 20 / 14,
      letterSpacing: 0.25,
    ),
    bodySmall: TextStyle(
      fontWeight: FontWeight.normal,
      fontSize: 12,
      height: 16 / 12,
      letterSpacing: 0.4,
    ),
    labelLarge: TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 14,
      height: 20 / 14,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 12,
      height: 16 / 12,
      letterSpacing: 0.5,
    ),
    labelSmall: TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 10,
      height: 14 / 10,
      letterSpacing: 0.5,
    ),
  );
}
