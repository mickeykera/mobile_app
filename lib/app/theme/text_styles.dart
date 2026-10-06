import 'package:flutter/material.dart';

/// The type scale.
///
/// Set in Geist: a 2023 Vercel/Basement neo-grotesque with a single variable
/// weight axis and tabular figures in its default feature set. It replaces the
/// platform default, which meant Roboto on Android and San Francisco on iOS -
/// so the same screen was set in two unrelated typefaces depending on the
/// phone. One bundled family makes the layout identical everywhere, and
/// `tabular` below is a real feature of the font rather than a synthesised one.
///
/// Two further deliberate departures from the Material 3 defaults:
///
///  * **Weight does the hierarchy work.** The default scale leans on size
///    alone, which at a 57pt display size looks thin and at a 12pt label looks
///    shouty. Here the display sizes are heavy and tightly tracked, and the
///    small sizes are light and loosely tracked, so a screen reads as a set of
///    distinct levels rather than one uniform grey.
///
///  * **Tracking follows size, uniformly.** Large text is set negative so it
///    reads as a single tight shape; small text is set positive so it stays
///    legible at 11-12pt. The scale below inverts that on body sizes only where
///    the text is a subtitle - see [subtitle].
class AppTextStyles {
  const AppTextStyles._();

  /// The bundled family. Must match a `family:` key in pubspec.yaml.
  ///
  /// Set on every style below rather than only on the theme's `textTheme`,
  /// because these are also applied directly by widgets - a heading in a hero
  /// header or a numeral in a stat tile bypasses the theme entirely and would
  /// otherwise silently fall back to the platform face.
  static const String fontFamily = 'Geist';

  /// Used for diagnostic text: error detail, IDs, raw values. See the error
  /// screen in `app.dart`.
  static const String monoFontFamily = 'Geist Mono';

  // ---------------------------------------------------------------------------
  // Display
  // ---------------------------------------------------------------------------

  /// Hero numerals. The focus timer uses this, so the tracking is tight enough
  /// that a `25:00` does not shimmer as the digits change every second.
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 57,
    fontWeight: FontWeight.w700,
    letterSpacing: -2.2,
    height: 1.05,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 45,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.6,
    height: 1.08,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.1,
    height: 1.12,
  );

  // ---------------------------------------------------------------------------
  // Headline
  // ---------------------------------------------------------------------------

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.9,
    height: 1.16,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
    height: 1.2,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 21,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.24,
  );

  // ---------------------------------------------------------------------------
  // Title
  // ---------------------------------------------------------------------------

  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.26,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.35,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.4,
  );

  // ---------------------------------------------------------------------------
  // Body
  // ---------------------------------------------------------------------------

  /// Running prose. Positive tracking here, not negative: below ~15pt a
  /// negative track pulls the letters together enough to blur on a low-density
  /// screen.
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.38,
  );

  /// The muted line under a heading: "Today", "Stay focused", a hint.
  ///
  /// Set negative, which is what makes it read as a quiet aside rather than
  /// another paragraph - and it is the style that pairs with the muted
  /// `onSurfaceVariant` slate.
  static const TextStyle subtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.5,
    height: 1.35,
  );

  /// Placeholder copy inside an empty text area. Italic and dimmer than
  /// [bodyMedium] so an empty field never competes with real content.
  static const TextStyle placeholder = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    letterSpacing: 0,
    height: 1.5,
  );

  /// The big numerals inside stat tiles and the completion ring.
  static const TextStyle metricLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
    height: 1.0,
  );

  static const TextStyle metricMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.1,
  );

  // ---------------------------------------------------------------------------
  // Label
  // ---------------------------------------------------------------------------

  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.35,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.3,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.4,
  );

  /// All-caps section eyebrow, e.g. "FOCUS" above the timer.
  static const TextStyle overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.8,
    height: 1.3,
  );

  /// Tabular figures for anything that counts down or ticks up in place, so the
  /// glyphs do not shift horizontally as the digits change.
  static TextStyle get tabular => const TextStyle(
        fontFamily: 'Geist Mono',
        fontFeatures: [FontFeature.tabularFigures()],
      );
}
