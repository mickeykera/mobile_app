library ascend.core.constants;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Habit category types, replacing raw string literals scattered across
/// the codebase. Each case carries its display title so callers do not need
/// to keep a parallel string in sync.
enum CategoryType {
  mind('Mind', LucideIcons.brain),
  body('Body', LucideIcons.dumbbell),
  craft('Craft', LucideIcons.code),
  discipline('Discipline', LucideIcons.shield);

  const CategoryType(this.title, this.icon);

  final String title;

  /// Icon representing this category.
  final IconData icon;

  /// Palette entry for this category at the given [brightness].
  ///
  /// Sourced from [AppColors] so habit cards follow the app theme instead of
  /// hard-coded copies, and split by brightness because one mid-tone cannot
  /// carry both schemes - see the note on [AppColors.habitMind].
  Color colorFor(Brightness brightness) => switch (this) {
        CategoryType.mind => brightness == Brightness.dark
            ? AppColors.habitMindDark
            : AppColors.habitMind,
        CategoryType.body => brightness == Brightness.dark
            ? AppColors.habitBodyDark
            : AppColors.habitBody,
        CategoryType.craft => brightness == Brightness.dark
            ? AppColors.habitCraftDark
            : AppColors.habitCraft,
        CategoryType.discipline => brightness == Brightness.dark
            ? AppColors.habitDisciplineDark
            : AppColors.habitDiscipline,
      };

  /// The light-scheme colour.
  ///
  /// Prefer [colorFor] at the call site. This stays for the places that have no
  /// `BuildContext` to hand (raw `int` persistence, `const` widget trees).
  Color get color => colorFor(Brightness.light);

  String get value => title;

  /// ARGB int form of the light-scheme [color], for consumers that store a raw
  /// int. Only for storage; never render a persisted value directly.
  int get colorValue => color.toARGB32();

  /// Resolves [title] back to a [CategoryType], returning null when there is
  /// no match. Use this where an unknown value needs to be distinguished from
  /// a real one, so callers can pick their own fallback presentation.
  static CategoryType? tryFromString(String value) {
    for (final e in CategoryType.values) {
      if (e.title == value) return e;
    }
    return null;
  }

  /// Resolves [title] back to a [CategoryType], falling back to [mind] for
  /// unknown values so legacy data never crashes the UI.
  static CategoryType fromString(String value) {
    return tryFromString(value) ?? CategoryType.mind;
  }

  static List<String> getAllTitles() =>
      CategoryType.values.map((e) => e.title).toList();
}
