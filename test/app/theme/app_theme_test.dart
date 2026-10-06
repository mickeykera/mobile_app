import 'package:ascend/app/theme/app_colors.dart';
import 'package:ascend/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the light and dark palettes against unreadable pairings.
///
/// The dark scheme was hand-picked rather than derived, so a future tweak can
/// easily drop a pairing below the WCAG AA threshold of 4.5:1 without anything
/// failing. These assertions run the real relative-luminance formula used by
/// WCAG, so they fail on genuinely unreadable colour pairs.
void main() {
  /// WCAG relative luminance contrast ratio between two opaque colours.
  double contrast(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  void checkScheme(
    String name,
    ColorScheme scheme,
  ) {
    // Body and label text against the page background.
    expect(
        contrast(scheme.onSurface, scheme.surface), greaterThanOrEqualTo(4.5),
        reason: '$name: onSurface on surface');
    expect(contrast(scheme.onSurfaceVariant, scheme.surface),
        greaterThanOrEqualTo(4.5),
        reason: '$name: onSurfaceVariant on surface');

    // Text drawn on the coloured header containers.
    expect(contrast(scheme.onPrimaryContainer, scheme.primaryContainer),
        greaterThanOrEqualTo(4.5),
        reason: '$name: onPrimaryContainer on primaryContainer');
    expect(contrast(scheme.onSecondaryContainer, scheme.secondaryContainer),
        greaterThanOrEqualTo(4.5),
        reason: '$name: onSecondaryContainer on secondaryContainer');
    expect(contrast(scheme.onTertiaryContainer, scheme.tertiaryContainer),
        greaterThanOrEqualTo(4.5),
        reason: '$name: onTertiaryContainer on tertiaryContainer');

    // The header gradient blends these two, so muted text must stay legible
    // on either end of it.
    expect(contrast(scheme.onSurfaceVariant, scheme.primaryContainer),
        greaterThanOrEqualTo(4.5),
        reason: '$name: onSurfaceVariant on primaryContainer');
    expect(contrast(scheme.onSurfaceVariant, scheme.secondaryContainer),
        greaterThanOrEqualTo(4.5),
        reason: '$name: onSurfaceVariant on secondaryContainer');
    expect(contrast(scheme.onSurfaceVariant, scheme.tertiaryContainer),
        greaterThanOrEqualTo(4.5),
        reason: '$name: onSurfaceVariant on tertiaryContainer');
  }

  group('colour scheme contrast', () {
    test('light scheme meets WCAG AA',
        () => checkScheme('light', AppColors.lightColorScheme));
    test('dark scheme meets WCAG AA',
        () => checkScheme('dark', AppColors.darkColorScheme));
  });

  group('theme wiring', () {
    test('both themes are seeded from the primary accent', () {
      // The dark scheme is seeded from the *light* variant of the accent, not
      // the deep one: a mid-tone clay that reads well on obsidian is a
      // different colour from the one that clears 4.5:1 on pearl.
      expect(AppColors.seedLight, AppColors.accentPrimaryDeep);
      expect(AppColors.seedDark, AppColors.accentPrimaryDark);
      expect(AppTheme.lightTheme.colorScheme.primary,
          AppColors.lightColorScheme.primary);
      expect(AppTheme.darkTheme.colorScheme.primary,
          AppColors.darkColorScheme.primary);
    });

    test('the accent family is warm, not blue', () {
      // Replaces "the blue family is actually blue". That test existed to stop
      // the accents drifting away from the brand blue; the brand is now a warm
      // clay, so the equivalent risk is drifting back toward blue - or toward
      // a saturated Tailwind tone, which is how the palette got here at all.
      for (final accent in <String, Color>{
        'seedLight': AppColors.seedLight,
        'primaryLight': AppColors.primaryLight,
        'primaryDark': AppColors.primaryDark,
        'accentPrimary': AppColors.accentPrimary,
        'accentPrimaryDeep': AppColors.accentPrimaryDeep,
        'accentLive': AppColors.accentLive,
        'accentDeep': AppColors.accentDeep,
        'accentWarm': AppColors.accentWarm,
      }.entries) {
        // Hue band, not a channel comparison. An `r > b` check is too blunt:
        // sage (#4F6B52) is a cool green that fails it by three counts while
        // being nothing like the old blue identity. What actually matters is
        // that nothing sits in the cyan-to-violet arc the palette left.
        final hue = HSLColor.fromColor(accent.value).hue;
        expect(hue < 200 || hue > 290, isTrue,
            reason: '${accent.key} sits in the blue/violet band '
                '(hue ${hue.toStringAsFixed(0)}) '
                '(${accent.value.toARGB32().toRadixString(16)}), so the '
                'palette is drifting back to the old blue identity');
        final hsl = HSLColor.fromColor(accent.value);
        expect(hsl.saturation, lessThan(0.65),
            reason: '${accent.key} is over-saturated at '
                '${hsl.saturation.toStringAsFixed(2)}');
      }
    });

    test('the category palette is earth-toned, not fluorescent', () {
      // This replaced a "no green anywhere" rule that only made sense while
      // the whole app was blue-dominant. It was guarding against a *hue*; the
      // palette actually went wrong on *chroma* - Tailwind-400 pastels that
      // measured 2.98:1 on white and read as machine-assembled. So the guard is
      // now saturation, plus a check that no category still carries one of the
      // four Tailwind values the palette was migrated away from.
      for (final entry in <String, Color>{
        'habitMind': AppColors.habitMind,
        'habitBody': AppColors.habitBody,
        'habitCraft': AppColors.habitCraft,
        'habitDiscipline': AppColors.habitDiscipline,
        'habitMindDark': AppColors.habitMindDark,
        'habitBodyDark': AppColors.habitBodyDark,
        'habitCraftDark': AppColors.habitCraftDark,
        'habitDisciplineDark': AppColors.habitDisciplineDark,
      }.entries) {
        final hsl = HSLColor.fromColor(entry.value);
        expect(hsl.saturation, lessThan(0.62),
            reason:
                '${entry.key} (${entry.value.toARGB32().toRadixString(16)}) '
                'is too saturated at ${hsl.saturation.toStringAsFixed(2)}');
      }

      // The exact old values, so a copy-paste reintroduction fails loudly.
      const retired = <int>{
        0xFF38BDF8, // sky-400
        0xFF818CF8, // indigo-400
        0xFFF59E0B, // amber-500
        0xFFF43F5E, // rose-500
      };
      for (final entry in <String, Color>{
        'habitMind': AppColors.habitMind,
        'habitBody': AppColors.habitBody,
        'habitCraft': AppColors.habitCraft,
        'habitDiscipline': AppColors.habitDiscipline,
        'habitMindDark': AppColors.habitMindDark,
        'habitBodyDark': AppColors.habitBodyDark,
        'habitCraftDark': AppColors.habitCraftDark,
        'habitDisciplineDark': AppColors.habitDisciplineDark,
      }.entries) {
        expect(retired.contains(entry.value.toARGB32()), isFalse,
            reason: '${entry.key} reverted to the old Tailwind value');
      }
    });

    test('action gradients land on indigo and stay legible', () {
      // The button label is picked once, from the accent, and then has to
      // survive being read against the far end of the gradient too.
      final far = AppGradients.action(AppColors.accentPrimary).colors.last;
      final ink = AppColors.onColorFor(
          AppColors.accentPrimary, AppColors.darkColorScheme);
      expect(contrast(ink, far), greaterThanOrEqualTo(4.5),
          reason: 'button label on the indigo end of the action gradient');
      expect(far, isNot(AppColors.accentPrimary));
      expect(far.computeLuminance(),
          lessThan(AppColors.accentPrimary.computeLuminance()),
          reason: 'gradient should fall away to a deeper indigo, not brighten');
    });

    test('every nav accent clears the 3:1 graphical floor in both schemes', () {
      // The nav bar is a blurred sheet, so an accent is read against near-white
      // glass in light mode and obsidian glass in dark mode. A single value per
      // tab cannot satisfy both: the neon set that sings on obsidian drops to
      // 2.6:1 on pearl.
      final navAccents = <String, (Color, Color)>{
        'habits': (AppColors.accentPrimaryDeep, AppColors.accentPrimary),
        'focus': (AppColors.accentDeep, AppColors.accentDeepDark),
        'journal': (AppColors.accentLiveDeep, AppColors.accentLiveDark),
        'analytics': (AppColors.accentWarmDeep, AppColors.accentWarm),
        'premium': (AppColors.accentDeep, AppColors.accentDeepDark),
      };
      for (final entry in navAccents.entries) {
        final (light, dark) = entry.value;
        expect(
            contrast(light, AppColors.surfaceLight), greaterThanOrEqualTo(3.0),
            reason: '${entry.key} light accent on the light nav bar');
        expect(contrast(dark, AppColors.surfaceDark), greaterThanOrEqualTo(3.0),
            reason: '${entry.key} dark accent on the dark nav bar');
      }
    });

    test('dark surfaces are actually dark and light ones are light', () {
      expect(
        AppColors.darkColorScheme.surface.computeLuminance(),
        lessThan(AppColors.lightColorScheme.surface.computeLuminance()),
      );
    });

    test('habit category colours are distinct enough to tell apart', () {
      // Two categories rendering the same colour would make the filter chips
      // and habit cards ambiguous.
      final categories = <Color>[
        AppColors.habitMind,
        AppColors.habitBody,
        AppColors.habitCraft,
        AppColors.habitDiscipline,
      ];
      for (var i = 0; i < categories.length; i++) {
        for (var j = i + 1; j < categories.length; j++) {
          expect(categories[i], isNot(categories[j]),
              reason: 'categories $i and $j share a colour');
        }
      }
    });
  });
}
