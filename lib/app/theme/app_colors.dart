import 'package:flutter/material.dart';

/// The Ascend palette.
///
/// The app is built around a *midnight* dark scheme: a warm near-black rather
/// than flat black, so the accents read as light sources inside the UI instead
/// of as coloured paint on a void. The light scheme is the same design system
/// inverted onto a warm pearl, rather than a separate palette, so a user
/// flipping their system theme sees one product instead of two.
///
/// The palette is **warm and low-chroma**: clay is the action colour, sage is
/// the "live / on" signal, warm charcoal is the deep end every gradient falls
/// away to, and bronze is the counterweight. Neutrals are warm stone rather
/// than blue-slate, so the whole surface temperature is consistent.
///
/// It was blue-dominant before, on the reasoning that a second green-family
/// hue next to "complete this habit" would read as two meanings for one
/// colour. That reasoning no longer applies, and the blue identity was the
/// thing that made the app look machine-assembled: `#3B82F6` / `#0EA5E9` /
/// `#6366F1` are the Tailwind defaults, and [habitBody]'s `#818CF8` measured
/// 2.98:1 on white. Warmth plus restraint is what the palette was missing, not
/// a different hue of the same saturated idea.
///
/// Every pairing below is checked by `test/app/theme/app_theme_test.dart`,
/// which runs the real WCAG relative-luminance formula. If you retune a colour
/// and an assertion starts failing, the margin tells you how close you are.
class AppColors {
  // ---------------------------------------------------------------------------
  // Seeds
  // ---------------------------------------------------------------------------

  /// Electric blue seed. Everything the Material `ColorScheme` does not
  /// explicitly pin below is derived from this via `fromSeed`.
  ///
  /// Two blues rather than one: the light scheme takes the deeper
  /// [#accentPrimaryDeep] because [#accentPrimary] only scores 3.4:1 on pearl and
  /// would fail the moment it became body text.
  static const Color seedLight = Color(0xFF8C4A2F);
  static const Color seedDark = Color(0xFFD08A63);

  // ---------------------------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------------------------

  /// Obsidian: the page background in dark. Very slightly blue rather than
  /// neutral grey so the cool accents sit on a cool base.
  static const Color surfaceDark = Color(0xFF12100E);

  /// Slate 900: the next step up. Used for sheets and raised chrome.
  static const Color surfaceRaisedDark = Color(0xFF1B1815);

  /// Slate 800: the translucent card body. Painted at 60-80% over the page so
  /// whatever sits behind a card tints it slightly.
  static const Color surfaceCardDark = Color(0xFF262119);

  /// The pearl counterpart of [surfaceDark].
  static const Color surfaceLight = Color(0xFFF6F4F1);
  static const Color surfaceRaisedLight = Color(0xFFFFFFFF);
  static const Color surfaceCardLight = Color(0xFFFFFFFF);

  static const Color onSurfaceLight = Color(0xFF14120F);
  static const Color onSurfaceDark = Color(0xFFF2EDE6);

  /// Muted slate for subtitles, captions and axis labels. Deliberately still
  /// clears 4.5:1 against the page *and* against all three header containers,
  /// because the same colour is used on both.
  static const Color onSurfaceVariantLight = Color(0xFF55504A);
  static const Color onSurfaceVariantDark = Color(0xFFA8A099);

  // ---------------------------------------------------------------------------
  // Header gradient containers
  // ---------------------------------------------------------------------------

  // The Habits, Journal, Analytics and Premium headers all paint a gradient
  // across two of these three. They are therefore tinted dark-navy rather than
  // mid-tone: a mid-tone container forces the muted body text to go light, and
  // then the *other* end of the gradient has to go dark, and you get a gradient
  // with unreadable text at one end.

  static const Color primaryContainerLight = Color(0xFFF2E3DC);
  static const Color primaryContainerDark = Color(0xFF2E1D15);
  static const Color onPrimaryContainerLight = Color(0xFF4A2A1C);
  static const Color onPrimaryContainerDark = Color(0xFFE0A98A);

  static const Color secondaryContainerLight = Color(0xFFE4E7E1);
  static const Color secondaryContainerDark = Color(0xFF1F221C);
  static const Color onSecondaryContainerLight = Color(0xFF35322C);
  static const Color onSecondaryContainerDark = Color(0xFFA8A099);

  // Tertiary stays amber. It is the only warm container, and it is what makes
  // "break" sessions and low ratings legible without a legend.
  static const Color tertiaryContainerLight = Color(0xFFF0EADB);
  static const Color tertiaryContainerDark = Color(0xFF2A2418);
  static const Color onTertiaryContainerLight = Color(0xFF3A3119);
  static const Color onTertiaryContainerDark = Color(0xFFC4A868);

  static const Color outlineLight = Color(0xFF5F5952);
  static const Color outlineDark = Color(0xFF8D857C);

  static const Color errorLight = Color(0xFFA33A2A);
  static const Color errorDark = Color(0xFFFF8A80);

  // There is no `success` pair any more. A green here was the last remaining
  // green in the file, and it duplicated what electric blue already says. Code
  // that needs a "this worked" signal should use [accentPrimary] - the palette
  // does not reserve a hue for confirmation.

  static const Color warningLight = Color(0xFF7A6126);
  static const Color warningDark = Color(0xFFFBBF24);

  // ---------------------------------------------------------------------------
  // Accents
  // ---------------------------------------------------------------------------

  /// The accents. Everything saturated in the scheme lives here, so these
  /// carry "this is the primary action" and "this is live / on" on their own.
  ///
  /// [accentPrimary] and [accentLive] are deliberately different jobs rather than
  /// two shades of the same thing: the deep blue is a *surface* you can put
  /// text on, the bright sky is a *light source* you point at something.
  static const Color accentPrimary = Color(0xFF9C4F32);
  static const Color accentLive = Color(0xFF4F6B52);
  static const Color accentDeep = Color(0xFF3B3630);
  static const Color accentPrimaryDeep = Color(0xFF8C4A2F);

  /// Warm counterweight. Used sparingly: break sessions, low ratings, and the
  /// Analytics tab so five nav destinations stay tellable apart when four of
  /// them are blue.
  static const Color accentWarm = Color(0xFF7A6126);

  /// Dark-scheme variants, where a mid-tone accent would disappear into the
  /// obsidian background.
  static const Color accentPrimaryDark = Color(0xFFD08A63);
  static const Color accentLiveDark = Color(0xFF8FB79A);
  static const Color accentDeepDark = Color(0xFFA8A099);
  static const Color accentWarmDark = Color(0xFFC4A868);

  /// Light-scheme variants of the two accents that cannot double as-is.
  ///
  /// The dark-scheme set is tuned for obsidian, where a mid-tone accent is the whole
  /// point. On the near-white glass nav bar in light mode the same values land
  /// at 2.6:1 ([accentLive]) and 2.8:1 ([accentWarm]), which is under the 3:1
  /// floor for a graphical object, so those two get a deeper counterpart there.
  static const Color accentLiveDeep = Color(0xFF4F6B52);
  static const Color accentWarmDeep = Color(0xFF7A6126);

  // ---------------------------------------------------------------------------
  // Glass
  // ---------------------------------------------------------------------------

  /// The 1px hairline that separates a translucent card from the page behind
  /// it. Light surfaces get a *dark* hairline instead: on a near-white card a
  /// white stroke is invisible, which is why the old cards read as unbordered
  /// blobs of grey.
  static Color hairline(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark
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
  ///
  /// Warm at the bottom, blue at the top. Keeping red and amber on the low end
  /// is deliberate: a mood scale where "1" is a slightly darker blue is
  /// correctly sequential and completely unreadable as *mood*. So the ramp runs
  /// red -> amber -> slate -> indigo -> electric blue, which is still
  /// warm overall but keeps "this was a bad day" instant.
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
  /// The accents are all mid-tone, so neither pure white nor the scheme's own
  /// `onSurface` clears 4.5:1 against most of them - white scores just 2.1:1 on
  /// [accentLive] and 3.7:1 on [accentPrimary]. A dark ink does, and where it does
  /// not the helper below falls back to white.
  ///
  /// This is the same obsidian as [surfaceDark] on purpose: the ink on a button
  /// is the page showing through it.
  static const Color accentInk = Color(0xFF12100E);

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

  /// Habit category colours: sage, clay, stone, bronze.
  ///
  /// These were `#38BDF8` / `#818CF8` / `#F59E0B` / `#F43F5E` - sky, indigo,
  /// amber and rose straight off the Tailwind palette, which is what made the
  /// app read as machine-assembled. It was not only taste: [habitBody] measured
  /// 2.98:1 as an icon on the white card, under the 3:1 floor, and the whole
  /// set had the fluorescent pastel character of a landing-page gradient rather
  /// than something you'd keep on screen all day.
  ///
  /// The earth tones are deliberately *deep* rather than desaturated-bright. A
  /// mid-tone that is calm on white is invisible on the obsidian background and
  /// vice versa, so each category ships a light-scheme and a dark-scheme value
  /// and resolves through `CategoryType.colorFor`. A single mid-tone cannot do
  /// both jobs: clearing 4.5:1 on white caps luminance at ~0.175, while
  /// clearing 4.5:1 on near-black needs ~0.19. The gap is real, so the pair is.
  ///
  /// All four clear 5.0:1 on the light card and 5.6:1 on the dark card, which
  /// matters because these are used for text as well as icons. Distinctness is
  /// asserted in `app_theme_test.dart` - four muddy browns would fail that
  /// just as four blues would, so the hues spread green / red / grey / yellow
  /// while staying inside a narrow, low-chroma band.
  ///
  /// Keep every use pointing at these constants. They used to be duplicated as
  /// raw literals in `habit_form.dart` and `premium_screen.dart`.
  static const Color habitMind = Color(0xFF3F6B4F);
  static const Color habitBody = Color(0xFF8A5A3C);
  static const Color habitCraft = Color(0xFF5F594F);
  static const Color habitDiscipline = Color(0xFF846A2E);

  /// Dark-scheme counterparts. Lighter versions of the same hues, not new ones.
  static const Color habitMindDark = Color(0xFF8FB79A);
  static const Color habitBodyDark = Color(0xFFD4916B);
  static const Color habitCraftDark = Color(0xFFB0A79B);
  static const Color habitDisciplineDark = Color(0xFFC4A868);

  // ---------------------------------------------------------------------------
  // Schemes
  // ---------------------------------------------------------------------------

  // The four scheme roles that are not shared with the surface block above.
  // Held as constants so the `fromSeed` overrides below read as palette picks
  // rather than inline literals.
  //
  // `secondary` is indigo rather than a second blue for the sake of
  // legibility: it is one of the five steps of the rating ramp, and two adjacent
  // blues would make ratings 4 and 5 indistinguishable on a pie slice.

  static const Color primaryLight = Color(0xFF8C4A2F);
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
///
/// Centralised so the Habits, Journal and Analytics headers read as one family
/// rather than three unrelated colour washes.
class AppGradients {
  const AppGradients._();

  /// Habits header: electric blue into indigo.
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

  /// The fill for a primary action: the accent falling away to deep indigo,
  /// bright end leading so the button reads as lit from the top-left.
  ///
  /// The 0.5 blend is the furthest this can go before the ink label drops under
  /// 4.5:1 against the indigo end of the ramp - past that, `GlowButton` has to
  /// flip to white text and the button stops looking like one object.
  static LinearGradient action(Color accent) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent,
          Color.lerp(accent, AppColors.accentDeep, 0.5)!,
        ],
      );

  /// Electric blue into indigo, for callers with no per-widget accent.
  static LinearGradient brand() => action(AppColors.accentPrimary);

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
