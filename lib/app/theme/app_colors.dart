import 'package:flutter/material.dart';

/// The Ascend palette — white dominant, warm clay as accent.
///
/// The app is built around a clean light scheme: white surfaces with warm clay
/// accents. Dark mode inverts to a warm near-black with the same clay accents
/// so a user flipping their system theme sees one product instead of two.
///
/// The palette is **warm and low-chroma**: clay is the action colour, sage is
/// the "live / on" signal, warm charcoal is the deep end every gradient falls
/// away to, and bronze is the counterweight. Neutrals are warm stone rather
/// than blue-slate, so the whole surface temperature is consistent.
class AppColors {
  // ---------------------------------------------------------------------------
  // Seeds
  // ---------------------------------------------------------------------------

  /// Clay seed for light scheme — derives the warm accent family.
  static const Color seedLight = Color(0xFF9C4F32);

  /// Lighter clay seed for dark scheme — derives accents that pop on near-black.
  static const Color seedDark = Color(0xFFD08A63);

  // ---------------------------------------------------------------------------
  // Surfaces (Light = dominant white)
  // ---------------------------------------------------------------------------

  /// Pure white — the primary page background in light mode.
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// White — raised surfaces (sheets, cards) in light mode.
  static const Color surfaceRaisedLight = Color(0xFFFFFFFF);

  /// Warm pearl 50 — card bodies in light mode, subtle separation.
  static const Color surfaceCardLight = Color(0xFFFDFBF7);

  /// Warm near-black — the page background in dark mode.
  static const Color surfaceDark = Color(0xFF12100E);

  /// Slate 900 warm — raised surfaces in dark mode.
  static const Color surfaceRaisedDark = Color(0xFF1B1815);

  /// Slate 800 warm — card bodies in dark mode.
  static const Color surfaceCardDark = Color(0xFF262119);

  static const Color onSurfaceLight = Color(0xFF14120F);
  static const Color onSurfaceDark = Color(0xFFF2EDE6);

  /// Muted warm stone for subtitles, captions and axis labels.
  static const Color onSurfaceVariantLight = Color(0xFF55504A);
  static const Color onSurfaceVariantDark = Color(0xFFA8A099);

  // ---------------------------------------------------------------------------
  // Header gradient containers
  // ---------------------------------------------------------------------------

  static const Color primaryContainerLight = Color(0xFFF2E3DC);
  static const Color primaryContainerDark = Color(0xFF2E1D15);
  static const Color onPrimaryContainerLight = Color(0xFF4A2A1C);
  static const Color onPrimaryContainerDark = Color(0xFFE0A98A);

  static const Color secondaryContainerLight = Color(0xFFE4E7E1);
  static const Color secondaryContainerDark = Color(0xFF1F221C);
  static const Color onSecondaryContainerLight = Color(0xFF35322C);
  static const Color onSecondaryContainerDark = Color(0xFFA8A099);

  static const Color tertiaryContainerLight = Color(0xFFF0EADB);
  static const Color tertiaryContainerDark = Color(0xFF2A2418);
  static const Color onTertiaryContainerLight = Color(0xFF3A3119);
  static const Color onTertiaryContainerDark = Color(0xFFC4A868);

  static const Color outlineLight = Color(0xFF5F5952);
  static const Color outlineDark = Color(0xFF8D857C);

  static const Color errorLight = Color(0xFFA33A2A);
  static const Color errorDark = Color(0xFFFF8A80);

  static const Color warningLight = Color(0xFF7A6126);
  static const Color warningDark = Color(0xFFFBBF24);

  // ---------------------------------------------------------------------------
  // Accents (clay, sage, charcoal, bronze)
  // ---------------------------------------------------------------------------

  /// Primary action — warm clay.
  static const Color accentPrimary = Color(0xFF9C4F32);

  /// Live/on signal — muted sage.
  static const Color accentLive = Color(0xFF4F6B52);

  /// Deep charcoal — gradient end stop.
  static const Color accentDeep = Color(0xFF3B3630);

  /// Deeper clay for light-mode text on clay backgrounds.
  static const Color accentPrimaryDeep = Color(0xFF8C4A2F);

  /// Warm bronze counterweight — breaks, low ratings, analytics tab.
  static const Color accentWarm = Color(0xFF7A6126);

  /// Dark-scheme variants — lighter versions of the same hues.
  static const Color accentPrimaryDark = Color(0xFFD08A63);
  static const Color accentLiveDark = Color(0xFF8FB79A);
  static const Color accentDeepDark = Color(0xFFA8A099);
  static const Color accentWarmDark = Color(0xFFC4A868);

  /// Light-scheme variants for accents that need deeper values on white.
  static const Color accentLiveDeep = Color(0xFF4F6B52);
  static const Color accentWarmDeep = Color(0xFF7A6126);

  // ---------------------------------------------------------------------------
  // Glass
  // ---------------------------------------------------------------------------

  /// 1px hairline separating translucent cards from the page.
  static Color hairline(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06);

  /// Translucent body fill for a card.
  static Color cardFill(ColorScheme scheme, {double opacity = 0.7}) =>
      scheme.brightness == Brightness.dark
          ? surfaceCardDark.withValues(alpha: opacity)
          : surfaceCardLight;

  /// Denser fill for nested surfaces inside a card.
  static Color insetFill(ColorScheme scheme, {double opacity = 0.5}) =>
      scheme.brightness == Brightness.dark
          ? surfaceRaisedDark.withValues(alpha: opacity)
          : Color.lerp(surfaceLight, Colors.black, 0.02)!;

  /// Standard glass treatment: translucent fill plus hairline stroke.
  static BoxDecoration glass(
    ColorScheme scheme, {
    double radius = 20,
    double opacity = 0.7,
    Color? tint,
    double tintOpacity = 0.09,
    Border? border,
    List<BoxShadow>? shadows,
    Gradient? gradient,
  }) {
    final Color? fill;
    if (gradient != null) {
      fill = null;
    } else if (tint == null) {
      fill = cardFill(scheme, opacity: opacity);
    } else {
      fill = Color.alphaBlend(
        tint.withValues(alpha: tintOpacity),
        cardFill(scheme, opacity: opacity),
      );
    }

    return BoxDecoration(
      color: fill,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: border ?? Border.all(color: hairline(scheme), width: 1),
      boxShadow: shadows,
    );
  }

  // ---------------------------------------------------------------------------
  // Accent helpers
  // ---------------------------------------------------------------------------

  static Color accent(ColorScheme scheme, Color light, Color dark) =>
      scheme.brightness == Brightness.dark ? dark : light;

  // ---------------------------------------------------------------------------
  // Rating scales (mood / energy)
  // ---------------------------------------------------------------------------

  static Color ratingColor(ColorScheme scheme, int rating) =>
      ratingScaleColor(scheme, rating);

  static List<Color> ratingScale(ColorScheme scheme) => [
        scheme.error,
        scheme.tertiary,
        scheme.outline,
        scheme.secondary,
        scheme.primary,
      ];

  static Color ratingScaleColor(ColorScheme scheme, int rating) {
    final clamped = rating.clamp(1, 5);
    return ratingScale(scheme)[clamped - 1];
  }

  // ---------------------------------------------------------------------------
  // Foreground selection
  // ---------------------------------------------------------------------------

  /// Near-black ink for text on saturated accent fills.
  static const Color accentInk = Color(0xFF12100E);

  /// Legible foreground for text or icon on [background].
  static Color onColorFor(Color background, ColorScheme scheme) {
    final candidates = <Color>[
      Colors.white,
      accentInk,
      scheme.onSurface,
    ];
    Color best = candidates.first;
    var bestRatio = -1.0;
    for (final candidate in candidates) {
      final ratio = _contrast(candidate, background);
      if (ratio > bestRatio) {
        bestRatio = ratio;
        best = candidate;
      }
    }
    return best;
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  // ---------------------------------------------------------------------------
  // Habit categories
  // ---------------------------------------------------------------------------

  static const Color habitMind = Color(0xFF3F6B4F);
  static const Color habitBody = Color(0xFF8A5A3C);
  static const Color habitCraft = Color(0xFF5F594F);
  static const Color habitDiscipline = Color(0xFF846A2E);

  static const Color habitMindDark = Color(0xFF8FB79A);
  static const Color habitBodyDark = Color(0xFFD4916B);
  static const Color habitCraftDark = Color(0xFFB0A79B);
  static const Color habitDisciplineDark = Color(0xFFC4A868);

  // ---------------------------------------------------------------------------
  // Schemes
  // ---------------------------------------------------------------------------

  static const Color primaryLight = Color(0xFF9C4F32);
  static const Color secondaryLight = Color(0xFF5F594F);
  static const Color tertiaryLight = Color(0xFF7A6126);

  static const Color primaryDark = Color(0xFFD08A63);
  static const Color secondaryDark = Color(0xFFA8A099);
  static const Color tertiaryDark = Color(0xFFC4A868);

  static ColorScheme lightColorScheme = ColorScheme.fromSeed(
    seedColor: seedLight,
    brightness: Brightness.light,
    surface: surfaceLight,
    onSurface: onSurfaceLight,
    primary: primaryLight,
    secondary: secondaryLight,
    tertiary: tertiaryLight,
    primaryContainer: primaryContainerLight,
    onPrimaryContainer: onPrimaryContainerLight,
    secondaryContainer: secondaryContainerLight,
    onSecondaryContainer: onSecondaryContainerLight,
    tertiaryContainer: tertiaryContainerLight,
    onTertiaryContainer: onTertiaryContainerLight,
    surfaceContainerHighest: surfaceCardLight,
    outline: outlineLight,
    error: errorLight,
  );

  static ColorScheme darkColorScheme = ColorScheme.fromSeed(
    seedColor: seedDark,
    brightness: Brightness.dark,
    surface: surfaceDark,
    onSurface: onSurfaceDark,
    primary: primaryDark,
    secondary: secondaryDark,
    tertiary: tertiaryDark,
    primaryContainer: primaryContainerDark,
    onPrimaryContainer: onPrimaryContainerDark,
    secondaryContainer: secondaryContainerDark,
    onSecondaryContainer: onSecondaryContainerDark,
    tertiaryContainer: tertiaryContainerDark,
    onTertiaryContainer: onTertiaryContainerDark,
    surfaceContainerHighest: surfaceCardDark,
    outline: outlineDark,
    error: errorDark,
  );
}

/// Named gradients used by more than one screen.
class AppGradients {
  const AppGradients._();

  static LinearGradient header(ColorScheme scheme) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.primaryContainer,
          scheme.secondaryContainer,
        ],
      );

  static LinearGradient journalHeader(ColorScheme scheme) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.tertiaryContainer,
          scheme.secondaryContainer,
        ],
      );

  static LinearGradient action(Color accent) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent,
          Color.lerp(accent, AppColors.accentDeep, 0.5)!,
        ],
      );

  static LinearGradient brand() => action(AppColors.accentPrimary);

  static LinearGradient vertical(Color accent, {double from = 0.35}) =>
      LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: from),
          accent,
        ],
      );
}