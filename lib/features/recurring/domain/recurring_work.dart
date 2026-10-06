import 'package:flutter/foundation.dart';

import '../../../core/utils/app_clock.dart';
import '../../habits/domain/entities/habit.dart';
import '../../habits/domain/entities/habit_completion.dart';
import '../../tasks/domain/entities/task.dart';
import '../../tasks/domain/value_objects/task_schedule.dart';
import '../../tasks/domain/value_objects/task_status.dart';

/// Which model a piece of recurring work is stored as today.
///
/// Stage G changes no writes, so the two sources genuinely are two sources.
/// This enum is how a consumer reads both without pretending they are one.
enum RecurringSource {
  /// Stored as a `Habit`, with its own recurrence fields and a completion log.
  habit,

  /// Stored as a `Task` whose schedule is `Recurring`.
  ///
  /// Occurrence history exists for these: `TaskController` records one through
  /// `HabitRepository.recordRecurringTaskOccurrence`, which writes a
  /// `HabitCompletion` with `itemId` = the task id and `itemType` = 'task'.
  /// [fromTaskWithHistory] reads those rows back to populate [lastCompletedAt],
  /// and [occurrenceRecorded] is derived from them.
  ///
  /// Stage L0 corrected an earlier version of this comment, which claimed that a
  /// recurring task "leaves no history behind" and called the resulting lack of
  /// history "the largest single obstacle to convergence". That was true when
  /// written and stopped being true once occurrence rows were added; the
  /// remaining obstacle is the one described in the Stage L audit - what is
  /// still missing is a canonical Task-side streak, not the log itself.
  recurringTask,
}

/// One read-only shape over "the work that repeats".
///
/// A `Habit` and a recurring `Task` are the same idea stored twice, and Stage G
/// exists to prove that reading them together is safe before any write unifies
/// them. This is that joint read.
///
/// It deliberately carries **only the fields both sources already have**.
/// Anything only one of them has stays on the entity: a shape with per-source
/// extras is the old two lists wearing a single type's clothes, and it would let
/// a caller read `habitStreak` off a task and get a null it has to remember to
/// check. Consumers needing a habit's streak read the `Habit`; this answers
/// "what repeats, and when is it next due".
///
/// [schedule] is the shared vocabulary both already speak. `Habit.isDueOnDate`
/// builds a `Recurring` from its flat `frequency` / `customWeekdays` strings, so
/// a habit reaches this shape with its recurrence already expressed the same way
/// a recurring task expresses it. That overlap is what makes the conversion a
/// codec change rather than a redesign.
@immutable
class RecurringWork {
  final String id;
  final String title;
  final String? description;
  final RecurringSource source;

  /// Always a `Recurring`. Callers reaching here through [fromTask] never see any
  /// other schedule, which is why the type is not wider.
  final Recurring schedule;

  final String? projectId;
  final String? goalId;
  final String? category;

  /// The most recent completion either source can point at.
  ///
  /// `null` for a recurring task even when it is done today: its completion is
  /// `Task.completedAt`, which this shape does not carry, and reading it here
  /// would invite a caller to treat "done" and "has history" as the same claim.
  /// [occurrenceRecorded] is the honest answer to that question.
  final DateTime? lastCompletedAt;

  const RecurringWork({
    required this.id,
    required this.title,
    required this.source,
    required this.schedule,
    this.description,
    this.projectId,
    this.goalId,
    this.category,
    this.lastCompletedAt,
  });

  /// A habit, expressed through the shared schedule vocabulary.
  factory RecurringWork.fromHabit(Habit habit) => RecurringWork(
        id: habit.id,
        title: habit.title,
        description: habit.description,
        source: RecurringSource.habit,
        // `Habit` persists its recurrence as flat fields, so this is where it
        // becomes the shared type. Delegating to [Habit.recurringSchedule] keeps
        // one definition of due-ness instead of rebuilding the rule here.
        schedule: habit.recurringSchedule,
        projectId: habit.projectId,
        goalId: habit.goalId,
        category: habit.category,
        lastCompletedAt: habit.lastCompletedAt,
      );

  /// A task, but only if it actually repeats.
  ///
  /// Returns `null` for `Once` and `Unscheduled`: they are not recurring work,
  /// and folding them in would make "repeats" mean "exists".
  static RecurringWork? fromTask(Task task) {
    final schedule = task.schedule;
    if (schedule is! Recurring) return null;

    return RecurringWork(
      id: task.id,
      title: task.title,
      description: task.description,
      source: RecurringSource.recurringTask,
      schedule: schedule,
      projectId: task.projectId,
      goalId: task.goalId,
      category: task.category,
      lastCompletedAt: null,
    );
  }

  /// Async version of [fromTask] that loads the task's occurrence history.
  ///
  /// This loads the task's completion rows from the repository to populate
  /// [lastCompletedAt] and [occurrenceRecorded] correctly.
  static Future<RecurringWork?> fromTaskWithHistory(
    Task task,
    List<HabitCompletion> completions,
  ) {
    final schedule = task.schedule;
    if (schedule is! Recurring) return Future.value(null);

    // Find task completions (itemType == 'task', itemId == task.id)
    final taskCompletions = completions
        .where((c) => c.itemId == task.id && c.itemType == 'task')
        .toList();

    DateTime? lastCompletedAt;
    if (taskCompletions.isNotEmpty) {
      taskCompletions.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      lastCompletedAt = taskCompletions.first.completedAt;
    }

    return Future.value(RecurringWork(
      id: task.id,
      title: task.title,
      description: task.description,
      source: RecurringSource.recurringTask,
      schedule: schedule,
      projectId: task.projectId,
      goalId: task.goalId,
      category: task.category,
      lastCompletedAt: lastCompletedAt,
    ));
  }

  /// Whether a recurring task can point at a recorded occurrence.
  ///
  /// True for habits (which have a completion log). For tasks, true only if
  /// there is at least one occurrence row recorded.
  bool get occurrenceRecorded =>
      source == RecurringSource.habit || lastCompletedAt != null;

  /// Whether this work repeats on [date].
  ///
  /// Takes `now` rather than calling [DateTime.now] so a caller with a fixed
  /// clock gets an answer consistent with it — the same reason [Recurring] takes
  /// `now` rather than reading the wall clock.
  bool isDueOn(DateTime date, {DateTime? now}) =>
      schedule.isDueOn(date, now: now ?? AppClock.now());

  @override
  bool operator ==(Object other) =>
      other is RecurringWork &&
      other.id == id &&
      other.source == source &&
      other.title == title &&
      other.schedule == schedule &&
      other.projectId == projectId &&
      other.goalId == goalId;

  @override
  int get hashCode =>
      Object.hash(id, source, title, schedule, projectId, goalId);

  @override
  String toString() =>
      'RecurringWork(${source.name}:$id, "$title", project: $projectId)';
}

/// Every piece of recurring work, from both sources, as one list.
///
/// The order is stable and source-independent: habits keep their own `sortOrder`,
/// recurring tasks keep theirs, and within each the stored order is preserved.
/// Callers that need a specific order sort it themselves — interleaving two
/// independent orderings here would invent a sequence the user never set.
///
/// Habits with a non-null [Habit.taskId] are excluded because they are the
/// legacy representation of a Task; the Task is the canonical representation.
List<RecurringWork> recurringWorkFrom({
  required List<Habit> habits,
  required List<Task> tasks,
  bool includeArchived = false,
}) {
  final result = <RecurringWork>[];

  for (final habit in habits) {
    if (!includeArchived && habit.isArchived) continue;
    // Skip Habits that have been migrated to a Task — the Task is the canonical
    // representation. See the unified read rule in the architecture doc.
    if (habit.taskId != null) continue;
    result.add(RecurringWork.fromHabit(habit));
  }

  for (final task in tasks) {
    // Tasks archive through their status, not a flag, so this matches how
    // tasksProvider and ProgressService exclude them.
    if (!includeArchived && task.status == TaskStatus.archived) continue;
    final work = RecurringWork.fromTask(task);
    if (work != null) result.add(work);
  }

  return result;
}

/// Async version of [recurringWorkFrom] that loads task occurrence history.
///
/// This loads task occurrence rows from the completion log to populate
/// [lastCompletedAt] and [occurrenceRecorded] for recurring tasks.
Future<List<RecurringWork>> recurringWorkFromWithHistory({
  required List<Habit> habits,
  required List<Task> tasks,
  required List<HabitCompletion> completions,
  bool includeArchived = false,
}) async {
  final result = <RecurringWork>[];

  for (final habit in habits) {
    if (!includeArchived && habit.isArchived) continue;
    // Skip Habits that have been migrated to a Task — the Task is the canonical
    // representation. See the unified read rule in the architecture doc.
    if (habit.taskId != null) continue;
    result.add(RecurringWork.fromHabit(habit));
  }

  for (final task in tasks) {
    // Tasks archive through their status, not a flag, so this matches how
    // tasksProvider and ProgressService exclude them.
    if (!includeArchived && task.status == TaskStatus.archived) continue;
    final work = await RecurringWork.fromTaskWithHistory(task, completions);
    if (work != null) result.add(work);
  }

  return result;
}
