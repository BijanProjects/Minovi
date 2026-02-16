import 'package:flutter/material.dart';
import 'package:chronosense/ui/theme/colors.dart';
import 'package:chronosense/ui/theme/typography.dart';

/// Material 3 theme with exact color mapping from the Kotlin app.
abstract final class ChronoTheme {
  // ── Light ──
  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: ChronoColors.indigo500,
      onPrimary: ChronoColors.slate50,
      primaryContainer: ChronoColors.indigo100,
      onPrimaryContainer: ChronoColors.indigo900,
      secondary: ChronoColors.amber500,
      onSecondary: ChronoColors.slate900,
      secondaryContainer: ChronoColors.amber300,
      onSecondaryContainer: ChronoColors.slate900,
      tertiary: ChronoColors.indigo300,
      onTertiary: ChronoColors.slate900,
      error: Color(0xFFDC2626),
      onError: Colors.white,
      surface: ChronoColors.slate50,
      onSurface: ChronoColors.slate900,
      surfaceContainerHighest: ChronoColors.slate100,
      onSurfaceVariant: ChronoColors.slate600,
      outline: ChronoColors.slate300,
      outlineVariant: ChronoColors.slate200,
      shadow: Colors.black,
      inverseSurface: ChronoColors.slate800,
      onInverseSurface: ChronoColors.slate50,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: ChronoTypography.textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primary,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: false,
        contentPadding: const EdgeInsets.all(16),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
    );
  }

  // ── Dark ──
  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: ChronoColors.indigo400,
      onPrimary: ChronoColors.indigo900,
      primaryContainer: ChronoColors.indigo800,
      onPrimaryContainer: ChronoColors.indigo100,
      secondary: ChronoColors.amber400,
      onSecondary: ChronoColors.slate900,
      secondaryContainer: ChronoColors.amber500,
      onSecondaryContainer: ChronoColors.slate50,
      tertiary: ChronoColors.indigo300,
      onTertiary: ChronoColors.slate900,
      error: Color(0xFFF87171),
      onError: Color(0xFF7F1D1D),
      surface: ChronoColors.darkSurface,
      onSurface: ChronoColors.slate100,
      surfaceContainerHighest: ChronoColors.darkCard,
      onSurfaceVariant: ChronoColors.slate400,
      outline: ChronoColors.slate600,
      outlineVariant: ChronoColors.slate700,
      shadow: Colors.black,
      inverseSurface: ChronoColors.slate200,
      onInverseSurface: ChronoColors.slate900,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: ChronoTypography.textTheme,
      scaffoldBackgroundColor: ChronoColors.darkBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: ChronoColors.darkBackground,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ChronoColors.darkSurface,
        indicatorColor: colorScheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      cardTheme: CardThemeData(
        color: ChronoColors.darkCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ChronoColors.darkCard,
        selectedColor: colorScheme.primary,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: false,
        contentPadding: const EdgeInsets.all(16),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
    );
  }
}
