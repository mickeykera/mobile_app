import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';

import 'habit_task_identity.dart';

/// The single switch the write-path stage flips (Stage L1.5 §4, Stage L2).
///
/// ## L1.5 contract (history)
///
/// L1.5 shipped this **inert** (`static const bool enabled = false`, read by
/// nobody), which was the "no final cutover" guarantee of that stage. The seam
/// it opened was [CutoverAuditor], which records the gate's value on every
/// report so the same read-only audit can certify a dataset under either
/// regime.
///
/// ## L2: the wiring switch
///
/// L2 makes it the one switch production reads, at exactly four sites (see
/// `docs/ascend-stage-l2-task-write-cutover.md` §1): the two controller
/// providers (which decide whether the controllers are constructed *holding* a
/// `CutoverWritePath`), the migration runner's D4 backfill, and this file's
/// [CutoverAuditor.audit] default. Routing inside the controllers is
/// capability-driven by that path, so there is no per-write check and no
/// silent Task→Habit fallback: a controller without the path is a legacy
/// controller by construction, which stays the real path for quarantined
/// habits.
///
/// It is mutable rather than const so a test can pin either regime — Dart runs
/// each test file in its own isolate, so pinning in `setUp` cannot leak across
/// files. The production default flips to `true` as L2's final step, after the
/// cutover suite proves the routed path (§9 of the stage document).
abstract final class CutoverGate {
  /// Whether production wires the canonical Task write path.
  ///
  /// Flipped to `true` as the final step of Stage L2: the cutover suite proved
  /// the routed path with the gate pinned on, and the two controller providers
  /// now construct their controllers *holding* a `CutoverWritePath`.
  static bool enabled = true;
}

/// A single owned field where a migrated habit and its canonical Task disagree.
///
/// [field] is one of the strings in [kCutoverOwnedFields]. [habitValue] and
/// [taskValue] are what the two records carry right now, for a report (and a
/// future repair decision) to name.
///
/// [selfHealing] is the diagnostically important bit:
///
///  - `true`  → the field is one of the five capabilities and the launch-time
///    bridge (`MigrationService.syncTaskCapabilities`) converges it on its own,
///    so the divergence is transient and will be gone by next launch;
///  - `false` → no repair mechanism exists. These are the `D1` (narration /
///    context), `D2` (archive) and `D5` (schedule overrides) class gaps that the
///    write-path stage must resolve before the final cutover.
@immutable
class RecurringDivergence {
  final String habitId;
  final String taskId;
  final String field;
  final Object? habitValue;
  final Object? taskValue;
  final bool selfHealing;

  const RecurringDivergence({
    required this.habitId,
    required this.taskId,
    required this.field,
    required this.habitValue,
    required this.taskValue,
    required this.selfHealing,
  });

  @override
  String toString() => 'RecurringDivergence($habitId→$taskId, $field, '
      'selfHealing: $selfHealing, habit: $habitValue, task: $taskValue)';
}

/// The owned fields a migrated pair is expected to agree on.
///
/// The five capabilities are the ones the bridge covers ([selfHealing]):
/// the rest are the L1.5 findings D1/D2/D5 and have no current repair.
const List<String> kCutoverOwnedFields = [
  'title',
  'category',
  'description',
  'projectId',
  'goalId',
  'schedule',
  'archived',
  'targetCount',
  'targetDuration',
  'cue',
  'timeOfDay',
  'streakFreezesUsed',
];

/// The subset of [kCutoverOwnedFields] the launch-time capability bridge
/// converges by itself.
const List<String> kCutoverSelfHealingFields = [
  'targetCount',
  'targetDuration',
  'cue',
  'timeOfDay',
  'streakFreezesUsed',
];

/// Every linked pair diverging from its Task, plus dangling and orphaned links.
///
/// Read-only by construction: it scans [habits] and [tasks] and writes nothing,
/// its contract matching the parity gate — detect and report, leave repair to
/// the stage that has a decided rule. Re-running it over the same data yields
/// the same report, which is what makes it a safe every-launch audit later.
@immutable
class CutoverReadinessReport {
  /// The gate value the audit ran under, recorded so a report cannot be
  /// mistaken later for a certification it was not.
  final bool routeWritesToTask;

  /// Habits carrying a `taskId`.
  final int migratedHabits;

  /// Habits with no `taskId` — the legacy-only remainder (`D4`, incl. every
  /// habit created after the migration marker).
  final int unlinkedHabits;

  /// Field-level disagreements among the linked pairs, excluding the zero.
  final List<RecurringDivergence> divergences;

  /// `taskId` values pointing at no Task — the L1.4 recovery state machine's
  /// territory, listed so the report is complete rather than as a new finding.
  final List<String> danglingTaskIds;

  /// Migration-created Tasks (`task_hm_*`) that no habit claims — `D3` residue.
  final List<String> orphanedMigratedTaskIds;

  const CutoverReadinessReport({
    required this.routeWritesToTask,
    required this.migratedHabits,
    required this.unlinkedHabits,
    required this.divergences,
    required this.danglingTaskIds,
    required this.orphanedMigratedTaskIds,
  });

  /// No field diverges and no link is dangling or orphaned.
  ///
  /// A clean report means the migrated half and the canonical half of every
  /// linked item agree today — the precondition the audit side of the final
  /// cutover gate will assert.
  bool get isClean =>
      divergences.isEmpty &&
      danglingTaskIds.isEmpty &&
      orphanedMigratedTaskIds.isEmpty;

  /// Whether, under the gate value this report ran with, the dataset is
  /// certified ready for the Task-owned write path.
  bool get certifiesReadyForCutover => routeWritesToTask && isClean;

  @override
  String toString() => 'CutoverReadinessReport(migrated: $migratedHabits, '
      'unlinked: $unlinkedHabits, divergences: ${divergences.length}, '
      'dangling: $danglingTaskIds, orphans: $orphanedMigratedTaskIds, '
      'clean: $isClean, routeWritesToTask: $routeWritesToTask)';
}

/// Read-only divergence detector for the Habit → Task cutover.
///
/// Same shape as the other recurring-domain readers: plain collections in,
/// immutable report out, one pass, no clock, no storage, no writes. It exists so
/// the future write-path stage has a tested boundary it can run (and gate on)
/// before retiring the Habit write path.
abstract final class CutoverAuditor {
  /// Audits every habit against every task in one pass.
  ///
  /// [routeWritesToTask] defaults to [CutoverGate.enabled] (resolved in the
  /// body, since a mutable static can no longer be a parameter default); pass
  /// it explicitly (in tests) to certify a dataset under either regime without
  /// writing a byte.
  static CutoverReadinessReport audit({
    required List<Habit> habits,
    required List<Task> tasks,
    bool? routeWritesToTask,
  }) {
    final writesToTask = routeWritesToTask ?? CutoverGate.enabled;
    final byId = {for (final task in tasks) task.id: task};

    final divergences = <RecurringDivergence>[];
    final dangling = <String>[];
    final claimed = <String>{};

    var migrated = 0;
    var unlinked = 0;

    for (final habit in habits) {
      final taskId = habit.taskId;
      if (taskId == null) {
        unlinked++;
        continue;
      }
      migrated++;
      claimed.add(taskId);

      final task = byId[taskId];
      if (task == null) {
        dangling.add(taskId);
        continue;
      }
      divergences.addAll(pairDivergences(habit, task));
    }

    final orphans = tasks
        .where((t) => HabitTaskIdentity.isMigratedTaskId(t.id))
        .where((t) => !claimed.contains(t.id))
        .map((t) => t.id)
        .toList();

    return CutoverReadinessReport(
      routeWritesToTask: writesToTask,
      migratedHabits: migrated,
      unlinkedHabits: unlinked,
      divergences: divergences,
      danglingTaskIds: dangling,
      orphanedMigratedTaskIds: orphans,
    );
  }

  /// The owned fields on which [habit] and its linked [task] disagree.
  ///
  /// Exposed separately so a per-pair test can assert exactly which field
  /// diverges without building a whole dataset.
  static List<RecurringDivergence> pairDivergences(Habit habit, Task task) {
    final divergences = <RecurringDivergence>[];

    String? t(String? value) => value;
    String? h(String? value) => value;

    _diverges(
      divergences,
      habit,
      task,
      'title',
      habit.title,
      task.title,
      false,
    );
    _diverges(
      divergences,
      habit,
      task,
      'category',
      habit.category,
      task.category,
      false,
    );
    _diverges(
      divergences,
      habit,
      task,
      'description',
      h(habit.description),
      t(task.description),
      false,
    );
    _diverges(
      divergences,
      habit,
      task,
      'projectId',
      habit.projectId,
      task.projectId,
      false,
    );
    _diverges(
      divergences,
      habit,
      task,
      'goalId',
      habit.goalId,
      task.goalId,
      false,
    );
    _diverges(
      divergences,
      habit,
      task,
      'schedule',
      jsonEncode(habit.recurringSchedule.toJson()),
      jsonEncode(task.schedule.toJson()),
      false,
    );
    _diverges(
      divergences,
      habit,
      task,
      'archived',
      habit.isArchived,
      task.status == TaskStatus.archived,
      false,
    );

    // The five capabilities are compared through the legacy shape so the field
    // names match the storage keys and the bridge's own vocabulary.
    final expected = LegacyHabitCapabilities.fromHabit(habit);
    _diverges(
      divergences,
      habit,
      task,
      'targetCount',
      expected.targetCount,
      task.targetCount,
      true,
    );
    _diverges(
      divergences,
      habit,
      task,
      'targetDuration',
      expected.targetDuration,
      task.targetDuration,
      true,
    );
    _diverges(
      divergences,
      habit,
      task,
      'cue',
      expected.cue,
      task.cue,
      true,
    );
    _diverges(
      divergences,
      habit,
      task,
      'timeOfDay',
      expected.timeOfDay,
      task.timeOfDay,
      true,
    );
    _diverges(
      divergences,
      habit,
      task,
      'streakFreezesUsed',
      expected.streakFreezesUsed,
      task.streakFreezeUsage.used,
      true,
    );

    return divergences;
  }

  static void _diverges(
    List<RecurringDivergence> out,
    Habit habit,
    Task task,
    String field,
    Object? habitValue,
    Object? taskValue,
    bool selfHealing,
  ) {
    if (_sameValue(habitValue, taskValue)) return;
    out.add(RecurringDivergence(
      habitId: habit.id,
      taskId: task.id,
      field: field,
      habitValue: habitValue,
      taskValue: taskValue,
      selfHealing: selfHealing,
    ));
  }

  static bool _sameValue(Object? a, Object? b) {
    if (a is DateTime && b is DateTime) return a.isAtSameMomentAs(b);
    if (a is Map && b is Map) {
      return _mapEquals(a.cast<String, dynamic>(), b.cast<String, dynamic>());
    }
    return a == b;
  }

  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!_sameValue(entry.value, b[entry.key])) return false;
    }
    return true;
  }
}