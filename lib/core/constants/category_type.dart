library ascend.core.constants;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Habit category types, replacing raw string literals scattered across
/// the codebase. Each case carries its display title so callers do not need
/// to keep a parallel string in sync.
enum CategoryType {
  mind('Mind', AppColors.habitMind, Icons.psychology_outlined),
  body('Body', AppColors.habitBody, Icons.fitness_center_outlined),
  craft('Craft', AppColors.habitCraft, Icons.code_outlined),
  discipline('Discipline', AppColors.habitDiscipline, Icons.shield_outlined);

  const CategoryType(this.title, this.color, this.icon);

  final String title;

  /// Palette entry for this category. Sourced from [AppColors] so habit
  /// cards follow the app theme instead of hard-coded copies.
  final Color color;

  /// Icon representing this category.
  final IconData icon;

  String get value => title;

  /// ARGB int form of [color], for consumers that store a raw int.
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
