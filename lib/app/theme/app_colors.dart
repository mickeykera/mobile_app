import 'package:flutter/material.dart';

class AppColors {
  static const Color seedLight = Color(0xFF6366F1);
  static const Color seedDark = Color(0xFF818CF8);

  static const Color surfaceLight = Color(0xFFFFFBFF);
  static const Color surfaceDark = Color(0xFF1C1B1F);
  static const Color surfaceVariantLight = Color(0xFFF5F0FC);
  static const Color surfaceVariantDark = Color(0xFF2D2A32);

  static const Color onSurfaceLight = Color(0xFF1C1B1F);
  static const Color onSurfaceDark = Color(0xFFE6E1E5);
  static const Color onSurfaceVariantLight = Color(0xFF49454F);
  static const Color onSurfaceVariantDark = Color(0xFFCAC4D0);

  static const Color primaryContainerLight = Color(0xFFE8E7FF);
  static const Color primaryContainerDark = Color(0xFF3F3C5E);
  static const Color onPrimaryContainerLight = Color(0xFF1F1B3B);
  static const Color onPrimaryContainerDark = Color(0xFFE8E7FF);

  static const Color secondaryContainerLight = Color(0xFFE8DEF8);
  static const Color secondaryContainerDark = Color(0xFF3B344E);
  static const Color onSecondaryContainerLight = Color(0xFF1D192B);
  static const Color onSecondaryContainerDark = Color(0xFFE8DEF8);

  static const Color tertiaryContainerLight = Color(0xFFFFD8E4);
  static const Color tertiaryContainerDark = Color(0xFF4A2532);
  static const Color onTertiaryContainerLight = Color(0xFF3C1321);
  static const Color onTertiaryContainerDark = Color(0xFFFFD8E4);

  static const Color outlineLight = Color(0xFF79747E);
  static const Color outlineDark = Color(0xFF938F99);

  static const Color successLight = Color(0xFF2E7D32);
  static const Color successDark = Color(0xFF66BB6A);
  static const Color warningLight = Color(0xFFF57F17);
  static const Color warningDark = Color(0xFFFFB300);
  static const Color errorLight = Color(0xFFC62828);
  static const Color errorDark = Color(0xFFEF5350);

  static const Color habitMind = Color(0xFF6366F1);
  static const Color habitBody = Color(0xFF10B981);
  static const Color habitCraft = Color(0xFFF59E0B);
  static const Color habitDiscipline = Color(0xFFEF4444);

  static ColorScheme lightColorScheme = ColorScheme.fromSeed(
    seedColor: seedLight,
    brightness: Brightness.light,
    surface: surfaceLight,
    onSurface: onSurfaceLight,
    primaryContainer: primaryContainerLight,
    onPrimaryContainer: onPrimaryContainerLight,
    secondaryContainer: secondaryContainerLight,
    onSecondaryContainer: onSecondaryContainerLight,
    tertiaryContainer: tertiaryContainerLight,
    onTertiaryContainer: onTertiaryContainerLight,
    outline: outlineLight,
    error: errorLight,
  );

  static ColorScheme darkColorScheme = ColorScheme.fromSeed(
    seedColor: seedDark,
    brightness: Brightness.dark,
    surface: surfaceDark,
    onSurface: onSurfaceDark,
    primaryContainer: primaryContainerDark,
    onPrimaryContainer: onPrimaryContainerDark,
    secondaryContainer: secondaryContainerDark,
    onSecondaryContainer: onSecondaryContainerDark,
    tertiaryContainer: tertiaryContainerDark,
    onTertiaryContainer: onTertiaryContainerDark,
    outline: outlineDark,
    error: errorDark,
  );
}
