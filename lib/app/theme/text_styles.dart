import 'package:flutter/material.dart';

/// The type scale.
///
/// Two deliberate departures from the Material 3 defaults:
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

  // ---------------------------------------------------------------------------
  // Display
  // ---------------------------------------------------------------------------

  /// Hero numerals. The focus timer uses this, so the tracking is tight enough
  /// that a `25:00` does not shimmer as the digits change every second.
  static const TextStyle displayLarge = TextStyle(
    fontSize: 57,
    fontWeight: FontWeight.w700,
    letterSpacing: -2.2,
    height: 1.05,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 45,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.6,
    height: 1.08,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.1,
    height: 1.12,
  );

  // ---------------------------------------------------------------------------
  // Headline
  // ---------------------------------------------------------------------------

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.9,
    height: 1.16,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
    height: 1.2,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.24,
  );

  // ---------------------------------------------------------------------------
  // Title
  // ---------------------------------------------------------------------------

  static const TextStyle titleLarge = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.26,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 15.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.35,
  );

  static const TextStyle titleSmall = TextStyle(
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
    fontSize: 15.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
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
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.5,
    height: 1.35,
  );

  /// Placeholder copy inside an empty text area. Italic and dimmer than
  /// [bodyMedium] so an empty field never competes with real content.
  static const TextStyle placeholder = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    letterSpacing: 0,
    height: 1.5,
  );

  /// The big numerals inside stat tiles and the completion ring.
  static const TextStyle metricLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
    height: 1.0,
  );

  static const TextStyle metricMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.1,
  );

  // ---------------------------------------------------------------------------
  // Label
  // ---------------------------------------------------------------------------

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.35,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.3,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.4,
  );

  /// All-caps section eyebrow, e.g. "FOCUS" above the timer.
  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.8,
    height: 1.3,
  );

  /// Tabular figures for anything that counts down or ticks up in place, so the
  /// glyphs do not shift horizontally as the digits change.
  static TextStyle get tabular => const TextStyle(
        fontFeatures: [FontFeature.tabularFigures()],
      );
}