import 'package:flutter/foundation.dart';

import '../../habits/domain/entities/habit.dart';
import '../../tasks/domain/entities/task.dart';
import '../../tasks/domain/value_objects/streak_freeze_usage.dart';

/// Deterministic identity for the artifacts the Habit -> Task migration writes.
///
/// ## Why this exists
///
/// The original migration called [IdGenerator.generateTaskId] on every run and
/// treated `habit.taskId != null` as proof the habit was already migrated. That
/// is two independent failures:
///
///  * a fresh random id per attempt means a retry cannot recognise the Task a
///    previous attempt already wrote, so an interrupted run produces a second
///    Task for the same habit, and
///  * `taskId` was never serialised at all (fixed in Stage L0), so the marker
///    did not survive a process restart either.
///
/// Deriving both ids from the habit makes the migration self-healing: the Task
/// is discoverable by id whether or not the link was written, and a copied
/// completion row is discoverable by its own derived id. Retry then converges
/// instead of accumulating.
abstract final class HabitTaskIdentity {
  /// Prefix marking a Task created by this migration.
  ///
  /// Namespaced so it cannot collide with [IdGenerator.generateTaskId], which is
  /// always `task_` followed by exactly 8 characters.
  static const String migratedTaskIdPrefix = 'task_hm_';

  /// Prefix marking a completion row copied from a legacy habit row.
  static const String migratedCompletionIdPrefix = 'completion_hm_';

  /// The one Task id this habit's migration may ever use.
  ///
  /// Injective in [habitId], so two habits can never claim the same Task.
  static String taskIdForHabit(String habitId) =>
      '$migratedTaskIdPrefix$habitId';

  /// Whether [taskId] was produced by [taskIdForHabit].
  static bool isMigratedTaskId(String taskId) =>
      taskId.startsWith(migratedTaskIdPrefix);

  /// The one completion id a given legacy row may be copied to.
  ///
  /// Derived per source row rather than per day, so a day that legitimately
  /// holds two legacy rows keeps both. Deduping by day instead would silently
  /// drop one - [reconcileHabitToTask] does exactly that, which is why the two
  /// copy paths historically disagreed.
  static String completionIdForCopy(String legacyCompletionId) =>
      '$migratedCompletionIdPrefix$legacyCompletionId';

  /// Whether [completionId] was produced by [completionIdForCopy].
  static bool isMigratedCompletionId(String completionId) =>
      completionId.startsWith(migratedCompletionIdPrefix);
}

/// The five `Habit` capabilities, and their canonical home on `Task`.
///
/// ## Stage L0: named, not moved
///
/// `targetCount`, `targetDuration`, `cue`, `timeOfDay` and `streakFreezesUsed`
/// are all user-entered and all persisted, and `Task` had no field for any of
/// them. Stage L0's decision was **legacy-only for now**: adding five fields
/// without deciding what they meant would have been inventing product
/// semantics. What L0 added instead is that the gap is *typed and testable* -
/// [matchesHabit] is what migration verification asserts, so a change that
/// blanks or loses any of these fields fails a test rather than passing
/// silently.
///
/// ## Stage L1.3: given a home
///
/// L1.3 performed that decision, field by field, and the answer is
/// **Task-level, not schedule-level**:
///
/// | Capability | Canonical home | Why not somewhere else |
/// |---|---|---|
/// | `targetCount` | `Task.targetCount` | per-due-day target of the work item. `Recurring` models *when*; completion rows record *what happened*. Neither owns *how much is aimed for*. |
/// | `targetDuration` | `Task.targetDuration` | the aimed-at duration of one occurrence. `HabitCompletion.duration` is the *measured* one, so they must stay separate or the target would be erased by the act of finishing. |
/// | `cue` | `Task.cue` | free-text trigger, i.e. task-level metadata. Not a schedule: nothing derives due-ness from it. |
/// | `timeOfDay` | `Task.timeOfDay` | a Morning/Afternoon/Evening label. It reads like scheduling, but no read path consults it - `dueAt`, `snoozedUntil` and `Recurring` ignore it - so promoting it into `TaskSchedule` would have invented behaviour. |
/// | `streakFreezesUsed` | `Task.streakFreezeUsage` | spent streak state, not configuration. Typed as [StreakFreezeUsage] so the allowance is part of the value rather than a number each reader has to interpret. |
///
/// The full rationale, the retirement condition for each field, and the
/// verification that proves nothing was lost are in
/// `docs/ascend-stage-l1-design.md` under "Canonical Legacy Capability Model".
///
/// ## What this type guarantees now
///
/// Preservation is structural, not a promise: this stage does **not** delete
/// `Habit`, so the legacy record keeps all five fields. What this type adds is
/// that the copy is *checked* - [matchesHabit] asserts the legacy side,
/// [matchesTask] asserts the canonical side, and [fieldsLostFrom]/[fieldsLostFromTask]
/// name the exact capability that failed instead of reporting an
/// undifferentiated "preservation failed". Migration verification runs both,
/// so a divergence between the two representations is caught at the moment the
/// write happens rather than at retirement.
///
/// [applyTo] is the one place a `Habit`'s capabilities are turned into a
/// `Task`'s, so the copy has a single definition instead of being restated at
/// the create site and the sync site.
@immutable
class LegacyHabitCapabilities {
  final int targetCount;
  final Duration targetDuration;
  final String cue;
  final String timeOfDay;
  final int streakFreezesUsed;

  const LegacyHabitCapabilities({
    required this.targetCount,
    required this.targetDuration,
    required this.cue,
    required this.timeOfDay,
    required this.streakFreezesUsed,
  });

  factory LegacyHabitCapabilities.fromHabit(Habit habit) =>
      LegacyHabitCapabilities(
        targetCount: habit.targetCount,
        targetDuration: habit.targetDuration,
        cue: habit.cue,
        timeOfDay: habit.timeOfDay,
        streakFreezesUsed: habit.streakFreezesUsed,
      );

  /// The same five values as the canonical `Task` now holds them.
  ///
  /// Reading the canonical side through the legacy shape is deliberate: it
  /// makes "did the copy survive" a single comparison in one vocabulary rather
  /// than two comparisons that could drift apart.
  factory LegacyHabitCapabilities.fromTask(Task task) =>
      LegacyHabitCapabilities(
        targetCount: task.targetCount,
        targetDuration: task.targetDuration,
        cue: task.cue,
        timeOfDay: task.timeOfDay,
        streakFreezesUsed: task.streakFreezeUsage.used,
      );

  /// This capability set written onto [task], leaving every other field alone.
  ///
  /// The only writer of the five canonical fields during migration and the
  /// capability bridge, so schedule, status, links and history are structurally
  /// incapable of being touched by a capability write.
  Task applyTo(Task task) => task.copyWith(
        targetCount: targetCount,
        targetDuration: targetDuration,
        cue: cue,
        timeOfDay: timeOfDay,
        streakFreezeUsage: StreakFreezeUsage(streakFreezesUsed),
      );

  /// The field names, for reporting which capability a failure concerns.
  static const List<String> fieldNames = [
    'targetCount',
    'targetDuration',
    'cue',
    'timeOfDay',
    'streakFreezesUsed',
  ];

  /// The individual fields that no longer match [habit].
  ///
  /// Used by verification so a failure names the capability that was lost
  /// rather than reporting an undifferentiated "preservation failed".
  List<String> fieldsLostFrom(Habit habit) {
    final lost = <String>[];
    if (targetCount != habit.targetCount) lost.add('targetCount');
    if (targetDuration != habit.targetDuration) lost.add('targetDuration');
    if (cue != habit.cue) lost.add('cue');
    if (timeOfDay != habit.timeOfDay) lost.add('timeOfDay');
    if (streakFreezesUsed != habit.streakFreezesUsed) {
      lost.add('streakFreezesUsed');
    }
    return lost;
  }

  /// The individual fields the canonical [task] does not hold.
  ///
  /// [fieldsLostFrom] read against the *legacy* side is the L0 check that the
  /// Habit record kept its values; this is the L1.3 check that the Task record
  /// received them. Both must be empty, or the two representations disagree
  /// and one of them is about to lose data at retirement.
  List<String> fieldsLostFromTask(Task task) {
    final lost = <String>[];
    if (targetCount != task.targetCount) lost.add('targetCount');
    if (targetDuration != task.targetDuration) lost.add('targetDuration');
    if (cue != task.cue) lost.add('cue');
    if (timeOfDay != task.timeOfDay) lost.add('timeOfDay');
    if (streakFreezesUsed != task.streakFreezeUsage.used) {
      lost.add('streakFreezesUsed');
    }
    return lost;
  }

  /// Whether every one of the five fields still reads back off [habit].
  bool matchesHabit(Habit habit) => fieldsLostFrom(habit).isEmpty;

  /// Whether the canonical [task] carries every one of the five fields.
  bool matchesTask(Task task) => fieldsLostFromTask(task).isEmpty;

  /// Whether any of the five differs from a fresh habit's defaults.
  ///
  /// Only used for reporting volume - a habit with no customised capability
  /// would lose nothing if `Task` never grew these fields.
  bool get hasCustomisedValues =>
      targetCount != 1 ||
      targetDuration != Duration.zero ||
      cue.isNotEmpty ||
      timeOfDay != 'Morning' ||
      streakFreezesUsed != 0;

  @override
  bool operator ==(Object other) =>
      other is LegacyHabitCapabilities &&
      other.targetCount == targetCount &&
      other.targetDuration == targetDuration &&
      other.cue == cue &&
      other.timeOfDay == timeOfDay &&
      other.streakFreezesUsed == streakFreezesUsed;

  @override
  int get hashCode => Object.hash(
      targetCount, targetDuration, cue, timeOfDay, streakFreezesUsed);

  @override
  String toString() => 'LegacyHabitCapabilities(targetCount: $targetCount, '
      'targetDuration: ${targetDuration.inMinutes}m, cue: "$cue", '
      'timeOfDay: $timeOfDay, streakFreezesUsed: $streakFreezesUsed)';
}
