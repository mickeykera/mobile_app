import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../app/theme/app_colors.dart';

part 'habit.freezed.dart';

@freezed
abstract class Habit with _$Habit {
  const factory Habit({
    required String id,
    required String title,
    required String description,
    required String category,
    required String frequency,
    required List<int> customWeekdays,
    required String timeOfDay,
    required int targetCount,
    required Duration targetDuration,
    required String cue,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int sortOrder,
    required bool isArchived,
    required int streakFreezesUsed,
    DateTime? lastCompletedAt,
    required int currentStreak,
    required int longestStreak,
    required int totalCompletions,
  }) = _Habit;

  const Habit._();

  factory Habit.create({
    required String title,
    required String category,
    String description = '',
    String frequency = 'Daily',
    List<int> customWeekdays = const [],
    String timeOfDay = 'Morning',
    int targetCount = 1,
    Duration targetDuration = const Duration(minutes: 0),
    String cue = '',
    int sortOrder = 0,
  }) {
    final now = DateTime.now();
    return Habit(
      id: 'habit_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      category: category,
      frequency: frequency,
      customWeekdays: customWeekdays,
      timeOfDay: timeOfDay,
      targetCount: targetCount,
      targetDuration: targetDuration,
      cue: cue,
      createdAt: now,
      updatedAt: now,
      sortOrder: sortOrder,
      isArchived: false,
      streakFreezesUsed: 0,
      lastCompletedAt: null,
      currentStreak: 0,
      longestStreak: 0,
      totalCompletions: 0,
    );
  }

  bool get isDueToday => isDueOnDate(DateTime.now());

  bool isDueOnDate(DateTime date) {
    final weekday = date.weekday;

    switch (frequency) {
      case 'Daily':
        return true;
      case 'Weekdays':
        return weekday >= 1 && weekday <= 5;
      case 'Weekends':
        return weekday >= 6 && weekday <= 7;
      case 'Custom':
        return customWeekdays.contains(weekday);
      default:
        return false;
    }
  }

  bool get isCompletedToday => isCompletedOn(DateTime.now());

  bool isCompletedOn(DateTime date) {
    final last = lastCompletedAt;
    if (last == null) return false;
    return _isSameDay(last, date);
  }

  double get completionRate {
    if (totalCompletions == 0) return 0.0;
    final daysSinceCreation = DateTime.now().difference(createdAt).inDays + 1;
    final expectedCompletions =
        (daysSinceCreation / 7 * _getWeeklyFrequency()).ceil();
    if (expectedCompletions == 0) return 1.0;
    return (totalCompletions / expectedCompletions).clamp(0.0, 1.0);
  }

  int _getWeeklyFrequency() {
    switch (frequency) {
      case 'Daily':
        return 7;
      case 'Weekdays':
        return 5;
      case 'Weekends':
        return 2;
      case 'Custom':
        return customWeekdays.length;
      default:
        return 7;
    }
  }

  Habit copyWithCompletion({
    required bool completed,
    DateTime? completionTime,
  }) {
    if (completed) {
      final newStreak = _calculateNewStreak(completionTime ?? DateTime.now());
      return copyWith(
        lastCompletedAt: completionTime ?? DateTime.now(),
        currentStreak: newStreak,
        longestStreak: newStreak > longestStreak ? newStreak : longestStreak,
        totalCompletions: totalCompletions + 1,
        updatedAt: DateTime.now(),
      );
    } else {
      return copyWithUncompletion();
    }
  }

  /// Reverts a completion: the streak restarts and the lifetime counter is
  /// decremented so `completionRate` stays honest.
  Habit copyWithUncompletion() {
    return copyWith(
      currentStreak: 0,
      totalCompletions: totalCompletions > 0 ? totalCompletions - 1 : 0,
      lastCompletedAt: totalCompletions > 1 ? lastCompletedAt : null,
      updatedAt: DateTime.now(),
    );
  }

  int _calculateNewStreak(DateTime completionTime) {
    final last = lastCompletedAt;
    if (last == null) return 1;
    // Re-completing the same day must neither grow nor break the streak.
    if (_isSameDay(last, completionTime)) {
      return currentStreak == 0 ? 1 : currentStreak;
    }
    if (_isSameDay(last, completionTime.subtract(const Duration(days: 1)))) {
      return currentStreak + 1;
    }
    return 1;
  }

  Habit useStreakFreeze() {
    return copyWith(
      streakFreezesUsed: streakFreezesUsed + 1,
      updatedAt: DateTime.now(),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String get categoryIconName {
    switch (category) {
      case 'Mind':
        return 'psychology';
      case 'Body':
        return 'fitness_center';
      case 'Craft':
        return 'code';
      case 'Discipline':
        return 'shield';
      default:
        return 'star';
    }
  }

  /// Category colour, sourced from the theme so habit cards follow the app
  /// palette. This previously hard-coded its own copy of the four category
  /// colours, which left cards on the old palette after a retheme.
  int get categoryColorValue {
    switch (category) {
      case 'Mind':
        return AppColors.habitMind.toARGB32();
      case 'Body':
        return AppColors.habitBody.toARGB32();
      case 'Craft':
        return AppColors.habitCraft.toARGB32();
      case 'Discipline':
        return AppColors.habitDiscipline.toARGB32();
      default:
        return AppColors.habitMind.toARGB32();
    }
  }

  Color get categoryColor => Color(categoryColorValue);

  IconData get categoryIcon {
    switch (category) {
      case 'Mind':
        return Icons.psychology_outlined;
      case 'Body':
        return Icons.fitness_center_outlined;
      case 'Craft':
        return Icons.code_outlined;
      case 'Discipline':
        return Icons.shield_outlined;
      default:
        return Icons.star_outline;
    }
  }
}
