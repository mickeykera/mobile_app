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
    test('both themes use the teal seed rather than the old indigo', () {
      expect(AppColors.seedLight, isNot(const Color(0xFF6366F1)));
      expect(AppTheme.lightTheme.colorScheme.primary,
          AppColors.lightColorScheme.primary);
      expect(AppTheme.darkTheme.colorScheme.primary,
          AppColors.darkColorScheme.primary);
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
