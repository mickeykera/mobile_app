import 'package:flutter/foundation.dart';

import '../../habits/domain/entities/habit_completion.dart';

/// The one day-consecutive streak and activity calculation for recurring work.
///
/// ## Why this exists
///
/// Recurring work used to be describable two ways, and the two disagreed. A
/// Habit was read through its stored counters and its legacy completion log,
/// both of which count **day-consecutive** runs. A recurring Task was read
/// through `TaskStreakComputer`, which counted **scheduled-consecutive** runs by
/// walking the Task's schedule. The same item, completed on the same days,
/// therefore reported two different numbers depending on which model still held
/// it.
///
/// Stage L1.1 settled the semantics. A recurring streak is a run of **calendar
/// days that were completed**, and the schedule is not consulted at all. The
/// rationale lives on `HabitLogProjection`, which documented the definition
/// before this type existed and which now delegates here. What Stage L1.2 adds
/// is that the Task side reads the *same* definition, so there is one algorithm
/// rather than two that happen to be kept in step by hand.
///
/// ## Which log owns which rows
///
/// Completion rows are owner-typed. [HabitCompletion.isHabitCompletion] splits
/// legacy habit rows from Task occurrence rows, and the migration copies a
/// habit's history into its Task's occurrence log under new ids. So the two logs
/// for one migrated item overlap on purpose, and a reader that sums both is
/// double counting. Read a migrated item through [forTaskLog]; read an
/// un-migrated one through [forHabitLog]. `ProgressService` applies that rule
/// in one place for the whole app.
///
/// ## Two different totals, on purpose
///
/// [totalCompletedDays] counts *days*. [occurrenceCount] sums the `count`
/// column. A habit that wants three glasses of water a day has one row carrying
/// `count: 3`, and `currentStreak` has never counted repetitions. Both totals
/// are exposed because both already existed on both sides with those meanings;
/// collapsing them would silently change one of them.
@immutable
class RecurringStreak {
  /// Days on which this owner has at least one completion, newest first.
  ///
  /// A day appears once however many rows it has.
  final List<DateTime> completedDays;

  /// Sum of `count` across every row belonging to this owner.
  final int occurrenceCount;

  const RecurringStreak._(this.completedDays, this.occurrenceCount);

  /// An owner with no completions at all.
  factory RecurringStreak.empty() => const RecurringStreak._(<DateTime>[], 0);

  /// The projection for an un-migrated Habit, read from the legacy habit log.
  ///
  /// Rows for other habits, and Task occurrence rows that merely sit in the same
  /// table, are excluded: completion rows are owner-typed and a Task's history
  /// is not this habit's history.
  factory RecurringStreak.forHabitLog(
    List<HabitCompletion> completions,
    String habitId,
  ) {
    return _fromRows(
      completions,
      (row) => row.isHabitCompletion && row.ownerId == habitId,
    );
  }

  /// The projection for a recurring Task, read from its occurrence log.
  ///
  /// Requires `itemType == 'task'` as well as a matching `itemId`, because a
  /// migrated habit's copied rows and its own legacy rows share the table and
  /// only the item type tells them apart.
  factory RecurringStreak.forTaskLog(
    List<HabitCompletion> completions,
    String taskId,
  ) {
    return _fromRows(
      completions,
      (row) => row.itemType == 'task' && row.itemId == taskId,
    );
  }

  /// Total completions, counting days: one per completed calendar day.
  int get totalCompletedDays => completedDays.length;

  /// Alias for [totalCompletedDays], named for callers whose surrounding metric
  /// is the occurrence count and which would otherwise read as a subtraction.
  int get totalCompletions => totalCompletedDays;

  /// Length of the unbroken run of completed calendar days ending at the most
  /// recent completion.
  ///
  /// Zero when the log is empty. Note this is a run of *completed* days, not of
  /// days since the last completion: an item last done a week ago has a current
  /// streak of whatever it had then, which is what the legacy stored counter also
  /// holds. Ageing is a separate concern and neither side applies it.
  int get currentStreak {
    if (completedDays.isEmpty) return 0;

    var streak = 1;
    for (var i = 1; i < completedDays.length; i++) {
      if (!_isNextDay(completedDays[i - 1], completedDays[i])) break;
      streak++;
    }
    return streak;
  }

  /// Longest run of consecutive completed days anywhere in the log.
  ///
  /// **Diagnostic only.** This is a high-water mark the log cannot reconstruct:
  /// un-completing a day deletes the log's only evidence that the run ever
  /// happened, while the persisted `Habit.longestStreak` deliberately keeps it,
  /// because the run *was* achieved. The stored counter is therefore the
  /// canonical value for every item, migrated or not, and nothing on a read path
  /// may write this value back over it.
  int get longestStreak {
    if (completedDays.isEmpty) return 0;

    var longest = 1;
    var running = 1;
    for (var i = 1; i < completedDays.length; i++) {
      if (_isNextDay(completedDays[i - 1], completedDays[i])) {
        running++;
        if (running > longest) longest = running;
      } else {
        running = 1;
      }
    }
    return longest;
  }

  /// The most recent day with a completion, or `null` when the log is empty.
  DateTime? get lastCompletedAt =>
      completedDays.isEmpty ? null : completedDays.first;

  /// Whether [day] has at least one completion, at any hour of that day.
  bool isCompletedOn(DateTime day) =>
      completedDays.any((d) => _isSameDay(d, day));

  static RecurringStreak _fromRows(
    List<HabitCompletion> completions,
    bool Function(HabitCompletion) isOwnedBy,
  ) {
    final days = <DateTime>{};
    var occurrenceCount = 0;

    for (final completion in completions) {
      if (!isOwnedBy(completion)) continue;
      occurrenceCount += completion.count;
      days.add(startOfDay(completion.completedAt));
    }

    final sorted = days.toList()..sort((a, b) => b.compareTo(a));
    return RecurringStreak._(sorted, occurrenceCount);
  }

  /// Midnight on [value]'s calendar day, in local time.
  static DateTime startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Whether [later] is the calendar day immediately after [earlier].
  ///
  /// Steps back a whole day and compares dates, which is what the legacy
  /// projection did before this type existed. Keeping the same arithmetic is the
  /// point: the parity gate reports on whether the log and the stored counters
  /// agree, and it can only keep agreeing while both sides run identical code.
  static bool _isNextDay(DateTime earlier, DateTime later) =>
      _isSameDay(earlier.subtract(const Duration(days: 1)), later);
}
