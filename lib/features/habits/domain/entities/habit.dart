import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/constants/category_type.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../tasks/domain/value_objects/task_schedule.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

    /// The moment this habit should next become due, set by a reschedule.
    DateTime? dueAt,

    /// While this is in the future the habit is held out of the workload, set
    /// by a snooze.
    DateTime? snoozedUntil,

    /// The project this habit is filed under, if any.
    ///
    /// Optional and id-only: the project is looked up by [projectId] rather
    /// than embedded, so the habit and project stay independently movable.
    String? projectId,

    /// The goal this habit is filed under, if any.
    String? goalId,

    /// The Task this habit has been migrated to, if any.
    ///
    /// When non-null, this Habit is the legacy representation of the Task.
    /// The Task is the canonical recurring item; this Habit is retained for
    /// rollback and audit but is excluded from user-facing recurring-work lists.
    String? taskId,
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
    String? projectId,
    String? goalId,
    String? taskId,
  }) {
    final now = AppClock.now();
    return Habit(
      id: IdGenerator.generateHabitId(),
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
      projectId: projectId,
      goalId: goalId,
      taskId: taskId,
      currentStreak: 0,
      longestStreak: 0,
      totalCompletions: 0,
    );
  }

  bool get isDueToday => isDueOnDate(AppClock.now());

  /// Whether an active snooze is holding this habit out of the workload.
  ///
  /// Snoozing is not completing: the completion history is untouched and the
  /// habit simply stops counting as due until the hold elapses. An expired
  /// [snoozedUntil] is inert, so nothing has to be cleared for the habit to
  /// come back.
  bool get isSnoozed {
    final until = snoozedUntil;
    return until != null && until.isAfter(AppClock.now());
  }

  /// The instant an active snooze ends, or null when the habit is not snoozed.
  DateTime? get activeSnoozeUntil => isSnoozed ? snoozedUntil : null;

  /// This habit expressed in the shared schedule vocabulary.
  ///
  /// A habit persists its recurrence as flat `frequency` / `customWeekdays`
  /// strings, so this is where those become a [Recurring]. It exists as a getter
  /// rather than being inlined at each use because [isDueOnDate] and the
  /// Stage G read model both need the *same* instance: rebuilding it in two
  /// places is how two call sites end up disagreeing about whether a habit is
  /// due, which is the bug this refactor removed once already.
  Recurring get recurringSchedule => Recurring(
        RecurrenceRule.fromFrequency(frequency, customWeekdays),
        dueAt: dueAt,
        snoozedUntil: snoozedUntil,
      );

  /// Whether this habit is scheduled on [date].
  ///
  /// The recurrence and the today-forward [snoozedUntil]/[dueAt] overrides are
  /// evaluated by [Recurring], which is the single definition of due-ness. This
  /// used to re-implement the frequency switch here, which is how the week
  /// strip and the Today list were able to disagree once schedules gained
  /// overrides.
  bool isDueOnDate(DateTime date) {
    return recurringSchedule.isDueOn(date, now: AppClock.now());
  }

  bool get isCompletedToday => isCompletedOn(AppClock.now());

  bool isCompletedOn(DateTime date) {
    final last = lastCompletedAt;
    if (last == null) return false;
    return _isSameDay(last, date);
  }

  double get completionRate {
    if (totalCompletions == 0) return 0.0;
    final daysSinceCreation = AppClock.now().difference(createdAt).inDays + 1;
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
      final newStreak = _calculateNewStreak(completionTime ?? AppClock.now());
      return copyWith(
        lastCompletedAt: completionTime ?? AppClock.now(),
        currentStreak: newStreak,
        longestStreak: newStreak > longestStreak ? newStreak : longestStreak,
        totalCompletions: totalCompletions + 1,
        updatedAt: AppClock.now(),
      );
    } else {
      return copyWithUncompletion();
    }
  }

  /// Reverts a completion: the streak is recomputed from the remaining history
  /// and the lifetime counter is decremented so `completionRate` stays honest.
  ///
  /// This used to reset `currentStreak` to 0 unconditionally, which meant
  /// un-ticking the most recent day of a 30-day streak destroyed the whole
  /// streak. The chain is now rebuilt from [totalCompletions] and
  /// [lastCompletedAt] instead: the user can only un-complete a day they just
  /// completed, so removing one day shortens the chain by exactly one (and a
  /// one-day streak legitimately falls back to 0).
  Habit copyWithUncompletion() {
    final newTotal = totalCompletions > 0 ? totalCompletions - 1 : 0;
    // Only the most recent day can be un-completed, so the surviving chain is
    // one shorter than the one on record.
    final newStreak = currentStreak > 1 ? currentStreak - 1 : 0;

    return copyWith(
      currentStreak: newStreak,
      totalCompletions: newTotal,
      // Once nothing is left, the completion timestamp has to go too, or
      // `isCompletedOn` would keep reporting the day as done.
      lastCompletedAt: newTotal > 0 ? lastCompletedAt : null,
      updatedAt: AppClock.now(),
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
      updatedAt: AppClock.now(),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Category colour, sourced from the theme so habit cards follow the app
  /// palette. This previously hard-coded its own copy of the four category
  /// colours, which left cards on the old palette after a retheme.
  ///
  /// The mapping now lives on [CategoryType] so the colour for a given
  /// category is defined in exactly one place.
  int get categoryColorValue => CategoryType.fromString(category).colorValue;

  Color get categoryColor => CategoryType.fromString(category).color;

  /// Category colour for the current theme.
  ///
  /// Prefer this over [categoryColor] in widgets: the two schemes need
  /// different values, and the light-scheme-only getter quietly fails on the
  /// dark surface.
  Color categoryColorFor(Brightness brightness) =>
      CategoryType.fromString(category).colorFor(brightness);

  IconData get categoryIcon =>
      CategoryType.tryFromString(category)?.icon ?? LucideIcons.star;
}
