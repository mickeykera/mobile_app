import 'package:flutter/material.dart';

/// The Ascend palette.
///
/// The app is built around a *midnight* dark scheme: near-black slate rather
/// than flat black, so the neon accents read as light sources inside the UI
/// instead of as coloured paint on a void. The light scheme is the same design
/// system inverted onto a cool pearl, rather than a separate palette, so a
/// user flipping their system theme sees one product instead of two.
///
/// Every pairing below is checked by `test/app/theme/app_theme_test.dart`,
/// which runs the real WCAG relative-luminance formula. If you retune a colour
/// and an assertion starts failing, the margin tells you how close you are.
class AppColors {
  // ---------------------------------------------------------------------------
  // Seeds
  // ---------------------------------------------------------------------------

  /// Cyan seed. Everything the Material `ColorScheme` does not explicitly pin
  /// below is derived from this via `fromSeed`.
  static const Color seedLight = Color(0xFF0E7490);
  static const Color seedDark = Color(0xFF22D3EE);

  // ---------------------------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------------------------

  /// Obsidian: the page background in dark. Very slightly blue rather than
  /// neutral grey so the cool accents sit on a cool base.
  static const Color surfaceDark = Color(0xFF0A0F1D);

  /// Slate 900: the next step up. Used for sheets and raised chrome.
  static const Color surfaceRaisedDark = Color(0xFF0F172A);

  /// Slate 800: the translucent card body. Painted at 60-80% over the page so
  /// whatever sits behind a card tints it slightly.
  static const Color surfaceCardDark = Color(0xFF1E293B);

  /// The pearl counterpart of [surfaceDark].
  static const Color surfaceLight = Color(0xFFF5F7FB);
  static const Color surfaceRaisedLight = Color(0xFFFFFFFF);
  static const Color surfaceCardLight = Color(0xFFFFFFFF);

  static const Color onSurfaceLight = Color(0xFF0B1220);
  static const Color onSurfaceDark = Color(0xFFEAF0FA);

  /// Muted slate for subtitles, captions and axis labels. Deliberately still
  /// clears 4.5:1 against the page *and* against all three header containers,
  /// because the same colour is used on both.
  static const Color onSurfaceVariantLight = Color(0xFF4A5568);
  static const Color onSurfaceVariantDark = Color(0xFF9FB0C9);

  // ---------------------------------------------------------------------------
  // Header gradient containers
  // ---------------------------------------------------------------------------

  // The Habits, Journal, Analytics and Premium headers all paint a gradient
  // across two of these three. They are therefore tinted dark-navy rather than
  // mid-tone: a mid-tone container forces the muted body text to go light, and
  // then the *other* end of the gradient has to go dark, and you get a gradient
  // with unreadable text at one end.

  static const Color primaryContainerLight = Color(0xFFD4EFF7);
  static const Color primaryContainerDark = Color(0xFF0D2436);
  static const Color onPrimaryContainerLight = Color(0xFF06303C);
  static const Color onPrimaryContainerDark = Color(0xFF8FE9FA);

  static const Color secondaryContainerLight = Color(0xFFE3DEFA);
  static const Color secondaryContainerDark = Color(0xFF1B1B38);
  static const Color onSecondaryContainerLight = Color(0xFF231A4A);
  static const Color onSecondaryContainerDark = Color(0xFFC9C2FF);

  static const Color tertiaryContainerLight = Color(0xFFFCE3C9);
  static const Color tertiaryContainerDark = Color(0xFF33220F);
  static const Color onTertiaryContainerLight = Color(0xFF3A2003);
  static const Color onTertiaryContainerDark = Color(0xFFFFE0BC);

  static const Color outlineLight = Color(0xFF5A6270);
  static const Color outlineDark = Color(0xFF8494AC);

  static const Color errorLight = Color(0xFFC0392B);
  static const Color errorDark = Color(0xFFFF8A80);

  static const Color successLight = Color(0xFF047857);
  static const Color successDark = Color(0xFF34D399);

  static const Color warningLight = Color(0xFFB45309);
  static const Color warningDark = Color(0xFFFBBF24);

  // ---------------------------------------------------------------------------
  // Accents
  // ---------------------------------------------------------------------------

  /// The four electric accents. These are the only saturated colours in the
  /// scheme, so they carry "this is live / this is on fire / this is the
  /// primary action" on their own.
  static const Color neonCyan = Color(0xFF06B6D4);
  static const Color radiantViolet = Color(0xFF8B5CF6);
  static const Color coralOrange = Color(0xFFF97316);
  static const Color emerald = Color(0xFF10B981);

  /// Neon variants for the dark scheme, where a mid-tone accent disappears into
  /// the obsidian background.
  static const Color neonCyanDark = Color(0xFF22D3EE);
  static const Color radiantVioletDark = Color(0xFFA78BFA);
  static const Color coralOrangeDark = Color(0xFFFB923C);
  static const Color emeraldDark = Color(0xFF34D399);

  // ---------------------------------------------------------------------------
  // Glass
  // ---------------------------------------------------------------------------

  /// The 1px hairline that separates a translucent card from the page behind
  /// it. Light surfaces get a *dark* hairline instead: on a near-white card a
  /// white stroke is invisible, which is why the old cards read as unbordered
  /// blobs of grey.
  static Color hairline(ColorScheme scheme) => scheme.brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.07);

  /// Translucent body fill for a card. Dark cards sit at 70% so the page
  /// gradient shows through; light cards are opaque, because a translucent
  /// white card over white has no visible translucency and only risks text
  /// contrast.
  static Color cardFill(ColorScheme scheme, {double opacity = 0.7}) =>
      scheme.brightness == Brightness.dark
          ? surfaceCardDark.withValues(alpha: opacity)
          : surfaceCardLight;

  /// A slightly denser fill for nested surfaces inside a card (an inner chip, a
  /// text field sitting on a card).
  static Color insetFill(ColorScheme scheme, {double opacity = 0.5}) =>
      scheme.brightness == Brightness.dark
          ? surfaceRaisedDark.withValues(alpha: opacity)
          : Color.lerp(surfaceLight, Colors.black, 0.035)!;

  /// Standard glass treatment: a translucent fill plus the hairline stroke.
  ///
  /// [tint] is blended *into* the fill rather than painted over it. A second
  /// translucent layer on top of a translucent layer compounds the alpha and
  /// the border stops matching the body, so the wash has to be resolved before
  /// it reaches the canvas.
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

  /// The accent that matches [scheme]'s brightness.
  static Color accent(ColorScheme scheme, Color light, Color dark) =>
      scheme.brightness == Brightness.dark ? dark : light;

  // ---------------------------------------------------------------------------
  // Rating scales (mood / energy)
  // ---------------------------------------------------------------------------

  /// Mood/energy rating colours, low to high.
  ///
  /// One step of [ratingScale]. Kept as a separate helper because callers that
  /// only ever render a single rating - a picker chip, a slider fill - should
  /// not allocate the whole five-element list to get one colour out of it.
  ///
  /// The mapping is 1..5 and clamps rather than bucketing: an earlier version
  /// collapsed 1-2 and 4-5 together, which meant a "1" and a "2" rendered
  /// identically and the low end of the scale had no gradient at all.
  static Color ratingColor(ColorScheme scheme, int rating) =>
      ratingScaleColor(scheme, rating);

  /// A five-step ramp for the 1-5 mood and energy scales, shared by the chips,
  /// the header pills and the pie slices so a "1" is the same colour everywhere.
  static List<Color> ratingScale(ColorScheme scheme) => [
        scheme.error,
        scheme.tertiary,
        scheme.outline,
        scheme.secondary,
        scheme.primary,
      ];

  /// The colour for a 1-5 rating within the scale above.
  static Color ratingScaleColor(ColorScheme scheme, int rating) {
    final clamped = rating.clamp(1, 5);
    return ratingScale(scheme)[clamped - 1];
  }

  // ---------------------------------------------------------------------------
  // Foreground selection
  // ---------------------------------------------------------------------------

  /// A near-black used as foreground on saturated accent fills.
  ///
  /// The category accents are all mid-tone, so neither pure white nor the
  /// scheme's own `onSurface` clears 4.5:1 against most of them - white scores
  /// just 3.2:1 on the amber "Craft" accent. A dark ink does, and where it does
  /// not the helper below falls back to white.
  static const Color accentInk = Color(0xFF0B0F0E);

  /// A legible foreground for text or an icon drawn on top of [background].
  ///
  /// Every candidate is scored with the real WCAG relative-luminance formula
  /// and the best one wins, so this keeps working when the palette is retuned.
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

  /// Habit category colours.
  ///
  /// These are the neon accents rather than the muted brand colours: a habit
  /// card's category tag has to be identifiable at a glance from across the
  /// list, and a mid-tone colour on an obsidian card does not read.
  ///
  /// Keep every use pointing at these constants. They used to be duplicated as
  /// raw literals in `habit_form.dart` and `premium_screen.dart`.
  static const Color habitMind = Color(0xFF22D3EE);
  static const Color habitBody = Color(0xFFA78BFA);
  static const Color habitCraft = Color(0xFFF59E0B);
  static const Color habitDiscipline = Color(0xFFF43F5E);

  /// Extra accents for the Premium feature list.
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color accentCyan = Color(0xFF06B6D4);

  // ---------------------------------------------------------------------------
  // Schemes
  // ---------------------------------------------------------------------------

  // The four scheme roles that are not shared with the surface block above.
  // Held as constants so the `fromSeed` overrides below read as palette picks
  // rather than inline literals.

  static const Color primaryLight = Color(0xFF0E7490);
  static const Color secondaryLight = Color(0xFF5B4BB8);
  static const Color tertiaryLight = Color(0xFF9A5B12);

  static const Color primaryDark = Color(0xFF22D3EE);
  static const Color secondaryDark = Color(0xFFA78BFA);
  static const Color tertiaryDark = Color(0xFFFB923C);

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
///
/// Centralised so the Habits, Journal and Analytics headers read as one family
/// rather than three unrelated colour washes.
class AppGradients {
  const AppGradients._();

  /// Habits header: cool cyan into indigo.
  static LinearGradient header(ColorScheme scheme) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.primaryContainer,
          scheme.secondaryContainer,
        ],
      );

  /// Journal header, running the other way for variety.
  static LinearGradient journalHeader(ColorScheme scheme) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.tertiaryContainer,
          scheme.secondaryContainer,
        ],
      );

  /// The fill for a primary action: two stops of the same hue, bright end
  /// leading so the button reads as lit from the top-left.
  static LinearGradient action(Color accent) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent,
          Color.lerp(accent, AppColors.radiantViolet, 0.45)!,
        ],
      );

  /// A vertical ramp for bars and heatmap tiles: saturated at the bottom where
  /// the data is, washed out at the top.
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