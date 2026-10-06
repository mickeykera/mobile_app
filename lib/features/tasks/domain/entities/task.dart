import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../value_objects/streak_freeze_usage.dart';
import '../value_objects/task_schedule.dart';
import '../value_objects/task_status.dart';

part 'task.freezed.dart';

/// A unit of work.
///
/// As with [Goal] and [Project] this is deliberately plain data: whether a task
/// is overdue, or how much of a project is done, is derived from its schedule
/// and the completion log. Storing that here would create a second source of
/// truth. A habit is a recurring task; this entity is the canonical shape the
/// habit form will converge on later, but for now the two coexist.
///
/// ## The five legacy capabilities
///
/// Stage L1.3 gave the five capabilities that Stage L0 declared "legacy-only"
/// (`targetCount`, `targetDuration`, `cue`, `timeOfDay`, `streakFreezesUsed`) a
/// canonical home here. The analysis behind that placement - and the reasons
/// none of them belongs on [TaskSchedule] or [Recurring] - is written up in
/// `docs/ascend-stage-l1-design.md` under "Canonical Legacy Capability Model".
/// The short version:
///
/// | Field | Boundary |
/// |---|---|
/// | [targetCount], [targetDuration] | per-occurrence target: task-level configuration, not schedule and not completion history |
/// | [cue] | task-level metadata |
/// | [timeOfDay] | presentation/intent label; deliberately *not* consulted by [Recurring] |
/// | [streakFreezeUsage] | spent streak state carried on the surviving item record |
///
/// All five default to the legacy defaults, so a Task written by Stage L0 (and
/// therefore carrying none of these keys) reads as identical to a default
/// `Habit` and the capability bridge performs no write for it.
@freezed
abstract class Task with _$Task {
  const factory Task({
    required String id,
    required String title,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int sortOrder,
    required TaskStatus status,
    required TaskSchedule schedule,
    String? description,
    String? projectId,
    String? goalId,
    String? category,
    DateTime? completedAt,
    DateTime? archivedAt,

    /// How much counts as done on one due day.
    @Default(1) int targetCount,

    /// The intended duration of one occurrence.
    ///
    /// Aimed-at, not measured: a *measured* duration lives on the occurrence
    /// row (`HabitCompletion.duration`), so overwriting this with what actually
    /// happened would erase the target.
    @Default(Duration.zero) Duration targetDuration,

    /// Free-text cue or trigger ("After brushing teeth").
    @Default('') String cue,

    /// Morning/Afternoon/Evening label. Presentation and scheduling *intent*
    /// only - it is never consulted by [Recurring], `dueAt`, snooze, reschedule
    /// or the streak readers, and L1.3 did not change that.
    @Default(AppConstants.timeOfDayMorning) String timeOfDay,

    /// Streak freezes spent on this item.
    @Default(StreakFreezeUsage()) StreakFreezeUsage streakFreezeUsage,
  }) = _Task;

  const Task._();

  factory Task.create({
    required String title,
    String? description,
    TaskSchedule schedule = const Unscheduled(),
    String? projectId,
    String? goalId,
    String? category,
    int sortOrder = 0,
  }) {
    final now = AppClock.now();
    return Task(
      id: IdGenerator.generateTaskId(),
      title: title,
      description: description,
      schedule: schedule,
      projectId: projectId,
      goalId: goalId,
      category: category,
      createdAt: now,
      updatedAt: now,
      sortOrder: sortOrder,
      status: TaskStatus.todo,
    );
  }

  /// Whether this task is finished.
  bool get isComplete => status == TaskStatus.done;

  /// Whether this task has neither a project nor a goal.
  ///
  /// The Inbox is not a stored collection: it is exactly the tasks that no
  /// project or goal has claimed, so filing a task removes it and clearing a
  /// link puts it back with no bookkeeping.
  bool get isInbox => projectId == null && goalId == null;

  /// Whether this task should surface on [date], as of the instant [now].
  bool isDueOn(DateTime date, {required DateTime now}) =>
      schedule.isDueOn(date, now: now);
}
