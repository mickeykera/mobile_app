import 'package:flutter/foundation.dart';

import '../../habits/domain/entities/habit_completion.dart';
import '../../tasks/domain/entities/task.dart';
import '../../tasks/domain/value_objects/task_schedule.dart';
import 'recurring_streak.dart';

/// A recurring Task's streaks, read through the canonical day-consecutive rule.
///
/// ## What changed, and why it was a bug rather than a feature
///
/// This used to walk the Task's **schedule** backwards and count only the days
/// it was due, so a Mon/Wed/Fri Task completed on those three days reported a
/// streak of 1, while the same item read as a Habit had reported 3. Stage L1.1
/// settled that a recurring streak is day-consecutive and the schedule is not
/// consulted at all; Stage L1.2 is where the Task side was brought over. The
/// arithmetic is no longer here — [RecurringStreak] owns it, so the legacy habit
/// parity gate and the Task side cannot drift apart again.
///
/// That is also why there is no clock. A day-consecutive streak is the run
/// ending at the most recent completion, not the run ending today, so nothing
/// about it depends on what time it is now and no injected date is required.
/// Ageing is a separate feature and did not exist on either side before.
@immutable
class TaskStreakComputer {
  /// Every completion row passed in, of any owner.
  ///
  /// The caller hands over the whole table once; [completions] is narrowed to
  /// this Task's occurrence rows on the way in rather than being pre-filtered,
  /// which keeps the filter rule — `itemType == 'task'` *and* a matching
  /// `itemId` — in one place next to the definition of what a Task row is.
  final List<HabitCompletion> completions;

  /// The Task whose history is being projected.
  final Task task;

  /// The canonical projection for this Task.
  RecurringStreak get _streak =>
      RecurringStreak.forTaskLog(completions, task.id);

  const TaskStreakComputer({
    required this.completions,
    required this.task,
  });

  /// Days on which this Task has an occurrence, newest first.
  ///
  /// A day appears once; if multiple rows exist for the same day (should not
  /// happen due to dedupe in `recordRecurringTaskOccurrence`) they collapse.
  List<DateTime> get completedDays => _streak.completedDays;

  /// Total occurrences: the sum of `count` across every row.
  ///
  /// Deliberately not [RecurringStreak.totalCompletedDays]. The Task-side
  /// counter has always measured repetitions while the streak measures days,
  /// and both numbers are load-bearing somewhere else.
  int get totalCompletions => _streak.occurrenceCount;

  /// Length of the unbroken run of completed calendar days ending at the most
  /// recent occurrence.
  int get currentStreak => _streak.currentStreak;

  /// Longest run of consecutive completed days anywhere in the log.
  ///
  /// Diagnostic only. The persisted `Habit.longestStreak` is the canonical
  /// high-water mark and is never recomputed from a log; see
  /// [RecurringStreak.longestStreak].
  int get longestStreak => _streak.longestStreak;

  /// The most recent day with an occurrence, or null if none.
  DateTime? get lastCompletedAt => _streak.lastCompletedAt;

  /// Whether this Task was completed on [day], at any hour of it.
  bool isCompletedOn(DateTime day) => _streak.isCompletedOn(day);
}

/// Computed streak snapshot for a Task.
@immutable
class TaskStreakSnapshot {
  final String taskId;
  final int currentStreak;

  /// Diagnostic only; never written back to a stored counter.
  final int longestStreak;

  /// Occurrences, summing `count` — see [TaskStreakComputer.totalCompletions].
  final int totalCompletions;

  final DateTime? lastCompletedAt;

  const TaskStreakSnapshot({
    required this.taskId,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalCompletions,
    this.lastCompletedAt,
  });

  @override
  String toString() =>
      'TaskStreakSnapshot($taskId: current=$currentStreak, longest=$longestStreak, total=$totalCompletions)';
}

/// Computes streak snapshots for the recurring [tasks], from one shared log.
///
/// Every Task is projected from the same [completions] table in one pass, so a
/// caller holding hundreds of Tasks pays for one scan rather than one per Task.
List<TaskStreakSnapshot> computeTaskStreaks({
  required List<Task> tasks,
  required List<HabitCompletion> completions,
}) {
  return [
    for (final task in tasks)
      if (task.schedule is Recurring) _snapshotFor(completions, task),
  ];
}

TaskStreakSnapshot _snapshotFor(
  List<HabitCompletion> completions,
  Task task,
) {
  final computer = TaskStreakComputer(completions: completions, task: task);
  return TaskStreakSnapshot(
    taskId: task.id,
    currentStreak: computer.currentStreak,
    longestStreak: computer.longestStreak,
    totalCompletions: computer.totalCompletions,
    lastCompletedAt: computer.lastCompletedAt,
  );
}
