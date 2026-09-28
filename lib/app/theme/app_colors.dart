import 'package:flutter/material.dart';

class AppColors {
  // Teal/mint seed. Everything else is derived from this via `fromSeed`, so
  // this one constant retones the whole app.
  static const Color seedLight = Color(0xFF0D9488);
  static const Color seedDark = Color(0xFF2DD4BF);

  // Warm neutral surfaces: a paper-like off-white rather than a cool grey, so
  // the cool teal reads as calm rather than clinical.
  static const Color surfaceLight = Color(0xFFFDFAF5);
  static const Color surfaceDark = Color(0xFF16130F);
  static const Color surfaceVariantLight = Color(0xFFF4EFE6);
  static const Color surfaceVariantDark = Color(0xFF2A251E);

  static const Color onSurfaceLight = Color(0xFF1F1B16);
  static const Color onSurfaceDark = Color(0xFFEDE7DC);
  static const Color onSurfaceVariantLight = Color(0xFF4A4438);
  static const Color onSurfaceVariantDark = Color(0xFFC9C1B3);

  static const Color primaryContainerLight = Color(0xFFCFF0E7);
  static const Color primaryContainerDark = Color(0xFF145047);
  static const Color onPrimaryContainerLight = Color(0xFF0A2B25);
  static const Color onPrimaryContainerDark = Color(0xFFCFF0E7);

  static const Color secondaryContainerLight = Color(0xFFDDE7E0);
  static const Color secondaryContainerDark = Color(0xFF33463C);
  static const Color onSecondaryContainerLight = Color(0xFF16241E);
  static const Color onSecondaryContainerDark = Color(0xFFDDE7E0);

  static const Color tertiaryContainerLight = Color(0xFFF7E3CE);
  // `tertiaryContainerDark` is the end colour of the Analytics and Journal header
  // gradients (`secondaryContainer -> tertiaryContainer`). It was originally a
  // saturated brown (#563A1F, S=64%), which fought the teal and turned the
  // gradient to mud. Halving the saturation alone was not enough -- at S=33% it
  // still read as brown on screen. At S=14% it is essentially a warm neutral,
  // so the gradient now travels from teal through a warm near-grey rather than
  // into a competing colour, and it still reads warm against the cool teal.
  // Text contrast on it improves too (8.33 -> 9.35).
  static const Color tertiaryContainerDark = Color(0xFF3B3A33);
  static const Color onTertiaryContainerLight = Color(0xFF3A2410);
  static const Color onTertiaryContainerDark = Color(0xFFF2E7D8);

  static const Color outlineLight = Color(0xFF7A7264);
  static const Color outlineDark = Color(0xFF9A9184);

  static const Color successLight = Color(0xFF2E7D32);
  static const Color successDark = Color(0xFF66BB6A);
  static const Color warningLight = Color(0xFFF57F17);
  static const Color warningDark = Color(0xFFFFB300);
  static const Color errorLight = Color(0xFFC62828);
  static const Color errorDark = Color(0xFFEF5350);

  /// Habit category colours.
  ///
  /// These were duplicated as raw literals in `habit_form.dart` and
  /// `premium_screen.dart`, which let the two drift apart. Keep every use
  /// pointing at these constants instead.
  ///
  /// "Body" is a distinct sky blue rather than a second green, because the
  /// brand teal already occupies the green slot and two greens were hard to
  /// tell apart at chip size.
  static const Color habitMind = Color(0xFF0D9488);
  static const Color habitBody = Color(0xFF0284C7);
  static const Color habitCraft = Color(0xFFD97706);
  static const Color habitDiscipline = Color(0xFFE11D48);

  /// Extra accents for the Premium feature list.
  static const Color accentViolet = Color(0xFF7C3AED);
  static const Color accentCyan = Color(0xFF0891B2);

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
