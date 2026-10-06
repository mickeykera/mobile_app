import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/habits/domain/entities/habit_completion.dart';
import 'package:ascend/features/habits/domain/repositories/habit_repository.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/repositories/task_repository.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/core/errors/failures.dart';
import 'package:ascend/core/extensions/date_extensions.dart';
import 'habit_task_identity.dart';
import 'streak_parity.dart';

/// Report of the parity gate run before migration.
///
/// Contains the list of Habits eligible for migration (parity agrees) and
/// those quarantined (parity diverges) with their verdict and reason.
@immutable
class MigrationReport {
  final List<String> eligible;
  final List<QuarantinedHabit> quarantined;

  const MigrationReport({
    required this.eligible,
    required this.quarantined,
  });

  int get totalChecked => eligible.length + quarantined.length;
  bool get hasQuarantined => quarantined.isNotEmpty;

  @override
  String toString() => 'MigrationReport(eligible: ${eligible.length}, '
      'quarantined: ${quarantined.length})';
}

/// A Habit that failed the parity gate and is quarantined from migration.
@immutable
class QuarantinedHabit {
  final String habitId;
  final ParityVerdict verdict;
  final String reason;

  const QuarantinedHabit({
    required this.habitId,
    required this.verdict,
    required this.reason,
  });

  @override
  String toString() => 'QuarantinedHabit($habitId: ${verdict.name})';
}

/// Report of one capability-bridge pass ([MigrationService.syncTaskCapabilities]).
///
/// Unlike [HabitMigrationOutcome] this is a pass over the whole linked set, so
/// its numbers are aggregate and its purpose is diagnosis: a quiet, fully
/// migrated install should report `checked == verified` and every other number
/// zero.
@immutable
class CapabilitySyncReport {
  /// Linked habits whose Task was examined.
  final int checked;

  /// Tasks whose capability fields were written because they diverged from
  /// their habit.
  final int updated;

  /// Tasks that read back carrying the right five values.
  final int verified;

  /// Linked habits whose Task no longer exists. Reported separately from
  /// [failed]: the link needs the recovery state machine in Stage L1.4, not
  /// another write here.
  final int unmatched;

  /// Writes that failed or re-read verification that did not hold.
  final int failed;

  const CapabilitySyncReport({
    required this.checked,
    required this.updated,
    required this.verified,
    required this.unmatched,
    required this.failed,
  });

  bool get isClean => failed == 0;

  @override
  String toString() => 'CapabilitySyncReport(checked: $checked, '
      'updated: $updated, verified: $verified, unmatched: $unmatched, '
      'failed: $failed)';
}

/// How the migration resolved a habit to exactly one Task.
enum MigrationIdentitySource {
  /// The habit already pointed at a Task that exists and verifies.
  existingLink,

  /// A Task with the deterministic migrated id already existed, so an earlier
  /// attempt had written it and lost the link.
  deterministicId,

  /// A Task created by an older attempt with a random id was matched on its
  /// logical content and adopted instead of creating a second one.
  logicalAdoption,

  /// This run created the Task.
  created,
}

/// Which step of the per-habit state machine produced the outcome.
enum MigrationState {
  /// Already migrated and verified. No writes.
  alreadyMigrated,

  /// The habit carried a `taskId` whose Task no longer exists. The dead link
  /// was cleared and the habit re-resolved to a live Task.
  recoveredDanglingLink,

  /// An existing Task was adopted rather than a new one created.
  adoptedExistingTask,

  /// A new Task was created.
  migrated,

  /// Parity failed; the habit was left untouched.
  quarantined,

  /// The habit could not be read or a write failed.
  failed,
}

/// The outcome of migrating one habit.
///
/// [verification] is the record of what was actually checked against persisted
/// state - completion is never inferred from `taskId != null`.
@immutable
class HabitMigrationOutcome {
  final String habitId;
  final MigrationState state;
  final String? taskId;
  final MigrationIdentitySource? identitySource;
  final MigrationVerification verification;

  /// Tasks that looked like another copy of this habit's work.
  ///
  /// Reported, never deleted: they may hold real user history, and Stage L has
  /// not established a safe deletion mechanism for them.
  final List<String> duplicateTaskIds;

  final String? error;

  const HabitMigrationOutcome({
    required this.habitId,
    required this.state,
    required this.verification,
    this.taskId,
    this.identitySource,
    this.duplicateTaskIds = const [],
    this.error,
  });

  bool get isSuccess =>
      state == MigrationState.alreadyMigrated ||
      state == MigrationState.recoveredDanglingLink ||
      state == MigrationState.adoptedExistingTask ||
      state == MigrationState.migrated;

  /// Whether this outcome represents a Task this run created.
  ///
  /// Keyed off [identitySource], not off [state]. The state is a label for how
  /// the habit got here, and the most specific one wins: recovering a dangling
  /// link and then creating the Task is reported as
  /// [MigrationState.recoveredDanglingLink], which would hide the creation from
  /// a `state == migrated` check and undercount the run.
  bool get createdTask => identitySource == MigrationIdentitySource.created;

  @override
  String toString() => 'HabitMigrationOutcome($habitId, ${state.name}, '
      'task: $taskId, verified: ${verification.isVerified})';
}

/// What verification confirmed about one migrated habit.
///
/// Every flag is a fact read back from persisted state after the writes, not an
/// intention. [failures] names what did not hold so a caller can gate on it.
@immutable
class MigrationVerification {
  final bool taskExists;
  final bool taskIsRecurring;
  final bool schedulePreserved;
  final bool projectIdPreserved;
  final bool goalIdPreserved;
  final bool archivedStatePreserved;

  /// The five capabilities still read back off the retained legacy habit
  /// record, byte-identical to before this run.
  final bool legacyCapabilitiesPreserved;

  /// The specific capability fields that no longer match, empty when preserved.
  final List<String> legacyCapabilitiesLost;

  /// The same five capabilities read back off the canonical Task.
  ///
  /// Stage L0 asserted only the legacy side, because the legacy record was the
  /// only place they existed. L1.3 moved them onto `Task`, so a migration that
  /// preserved the Habit but never wrote the Task would now pass the L0 check
  /// while leaving the canonical side empty - which is exactly the "moved a
  /// field and silently dropped it" failure this stage exists to rule out.
  final bool taskCapabilitiesPresent;

  /// The capability fields the Task does not hold, empty when present.
  final List<String> taskCapabilitiesLost;

  /// Every legacy completion row has a corresponding copied Task row.
  final bool historyPreserved;

  /// The number of legacy rows found missing from the Task's occurrence log.
  final int historyRowsMissing;

  /// The habit's stored streak counters are byte-identical to before the run.
  final bool streakCountersPreserved;

  /// This run resolved the habit to exactly one Task rather than adding a
  /// second copy of the same logical work.
  final bool noDuplicateLogicalTask;

  /// A Task this run created carries the deterministic migrated id.
  ///
  /// Stage L1.4 hardening: if the create path ever wrote a random id, a retry
  /// after a lost link could not rediscover the Task by id, and the second run
  /// would create a second Task. The parity boundary therefore asserts the
  /// create used [HabitTaskIdentity.taskIdForHabit] - not that *every* Task id
  /// is deterministic (an older attempt's adopted Task legitimately is not),
  /// only that this run introduced none.
  final bool deterministicIdentity;

  final List<String> failures;

  const MigrationVerification({
    required this.taskExists,
    required this.taskIsRecurring,
    required this.schedulePreserved,
    required this.projectIdPreserved,
    required this.goalIdPreserved,
    required this.archivedStatePreserved,
    required this.legacyCapabilitiesPreserved,
    required this.legacyCapabilitiesLost,
    required this.taskCapabilitiesPresent,
    required this.taskCapabilitiesLost,
    required this.historyPreserved,
    required this.historyRowsMissing,
    required this.streakCountersPreserved,
    required this.noDuplicateLogicalTask,
    required this.deterministicIdentity,
    required this.failures,
  });

  /// A verification that failed because there was nothing to verify.
  factory MigrationVerification.absent(String reason) => MigrationVerification(
        taskExists: false,
        taskIsRecurring: false,
        schedulePreserved: false,
        projectIdPreserved: false,
        goalIdPreserved: false,
        archivedStatePreserved: false,
        legacyCapabilitiesPreserved: false,
        legacyCapabilitiesLost: const [],
        taskCapabilitiesPresent: false,
        taskCapabilitiesLost: const [],
        historyPreserved: false,
        historyRowsMissing: 0,
        streakCountersPreserved: false,
        noDuplicateLogicalTask: true,
        deterministicIdentity: true,
        failures: [reason],
      );

  /// True only when every check held.
  bool get isVerified => failures.isEmpty;

  @override
  String toString() => 'MigrationVerification(verified: $isVerified, '
      'failures: $failures)';
}

/// The difference between the two streak definitions, and how it was settled.
///
/// A legacy `Habit` streak is **day**-consecutive and stored on the entity
/// ([HabitLogProjection]); a `Task` streak used to be **scheduled**-consecutive
/// and derived ([TaskStreakComputer]). A Mon/Wed/Fri habit with a
/// day-consecutive streak of 3 reported 1 under the Task rule.
///
/// Stage L0 therefore **did not** migrate streak numbers: it left the legacy
/// counters untouched and asserted they survived, because the number the user
/// saw came from those counters and the Task-rule number had no production
/// caller yet.
///
/// Stage L1 settled it — **day-consecutive is canonical for recurring work** —
/// and Stage L1.2 moved the Task side onto it, so [RecurringStreak] is now the
/// only streak arithmetic and `taskStreaksByCategory` is wired into Analytics.
///
/// The persisted counters are still not rewritten. `Habit.longestStreak` in
/// particular is a high-water mark the log cannot reconstruct after an
/// un-completion, so it stays the canonical value for every habit, migrated or
/// not; the derived figure is reported for diagnosis only and is never written
/// back. A migrated habit's *current* streak is re-derived from its Task
/// occurrence log, because that log is what its write path now maintains.
const String kStreakSemanticsDelta =
    'Legacy streaks are day-consecutive and stored on Habit; Task streaks were '
    'scheduled-consecutive and derived. Settled in Stage L1: day-consecutive is '
    'canonical for recurring work, RecurringStreak owns the arithmetic for both '
    'sides, and stored counters are still preserved verbatim - including '
    'longestStreak, which no read path recalculates.';

/// Service that orchestrates the Habit -> Task migration.
///
/// ## Resumability
///
/// The migration is a state machine per habit, and every step is idempotent:
///
/// ```
/// habit.taskId set, Task exists, verifies  -> alreadyMigrated (no writes)
/// habit.taskId set, Task missing            -> clear link, fall through
/// no link, deterministic Task exists       -> adopt, relink
/// no link, no deterministic Task,
///   logical duplicate found                -> adopt, relink, report duplicates
/// otherwise                                 -> create, copy history, link, verify
/// ```
///
/// Nothing here depends on the link having been written: the Task is found by
/// [HabitTaskIdentity.taskIdForHabit], so losing the link at any point costs a
/// re-link, not a duplicate. Copied history is likewise found by derived
/// completion id, so re-running never appends a second copy of a row.
///
/// ## Streaks
///
/// Legacy streak counters are carried across untouched; see
/// [kStreakSemanticsDelta] for why that is deliberate.
class MigrationService {
  final HabitRepository _habitRepository;
  final TaskRepository _taskRepository;

  const MigrationService(this._habitRepository, this._taskRepository);

  /// Runs the parity gate over all Habits.
  ///
  /// Returns a [MigrationReport] listing eligible and quarantined Habits.
  /// Does NOT perform any writes.
  ///
  /// Archived habits are included by default. The Stage L audit found the gate
  /// was calling `getAllHabits()` with the repository default of
  /// `includeArchived: false`, so archived habits were never gated, never
  /// copied and never linked - and would have been dropped outright at
  /// retirement. They migrate too, into archived Tasks, so the user's archive
  /// intent survives the move.
  ///
  /// Throws if the habits cannot be read. Reporting an empty eligible list on a
  /// read failure would be the worst possible outcome here: "nothing to do"
  /// reads as a clean pass, and the production runner would write its completion
  /// marker over an install whose habits it never actually saw.
  Future<MigrationReport> runParityGate({bool includeArchived = true}) async {
    final habitsResult =
        await _habitRepository.getAllHabits(includeArchived: includeArchived);
    final completionsResult = await _habitRepository.getAllCompletions();

    // `getOrNull` rather than `getOrElse([])`: a failure must not be
    // indistinguishable from an empty install.
    final habits = habitsResult.getOrNull();
    if (habits == null) {
      throw StateError(
        'parity gate could not read habits: ${habitsResult.left?.message}',
      );
    }
    // Symmetric with the habits read. A completions read failure in the wild
    // would silently read as "every habit's log is empty", quarantine the whole
    // install, and mask a storage failure as a parity finding - which no longer
    // needs a repair decision. An unreadable log is the one thing the gate must
    // say something about instead.
    final completions = completionsResult.getOrNull();
    if (completions == null) {
      throw StateError(
        'parity gate could not read completions: '
        '${completionsResult.left?.message}',
      );
    }

    final eligible = <String>[];
    final quarantined = <QuarantinedHabit>[];

    for (final habit in habits) {
      final parity =
          HabitLogProjection.from(completions, habit.id).compareTo(habit);
      if (parity.verdict == ParityVerdict.agrees) {
        eligible.add(habit.id);
      } else {
        quarantined.add(QuarantinedHabit(
          habitId: habit.id,
          verdict: parity.verdict,
          reason: parity.verdict.name,
        ));
      }
    }

    return MigrationReport(eligible: eligible, quarantined: quarantined);
  }

  /// Migrates each habit in [eligibleHabitIds], returning one outcome each.
  ///
  /// Idempotent: a habit already holding a verified link is reported as
  /// [MigrationState.alreadyMigrated] and not written again.
  Future<List<HabitMigrationOutcome>> migrateHabits(
    List<String> eligibleHabitIds,
  ) async {
    final outcomes = <HabitMigrationOutcome>[];
    for (final habitId in eligibleHabitIds) {
      outcomes.add(await migrateHabit(habitId));
    }
    return outcomes;
  }

  /// Copies eligible Habits to Tasks and links them.
  ///
  /// Retained for callers that only need the count. See [migrateHabits] for the
  /// per-habit outcomes and [migrateHabit] for the state machine.
  ///
  /// Returns the number of habits for which this run created a Task.
  Future<int> copyEligibleToTasks(List<String> eligibleHabitIds) async {
    final outcomes = await migrateHabits(eligibleHabitIds);
    return outcomes.where((o) => o.createdTask).length;
  }

  /// Runs the state machine for one habit and reports what happened.
  Future<HabitMigrationOutcome> migrateHabit(String habitId) async {
    final habitResult = await _habitRepository.getHabitById(habitId);
    // Reassigned when a dangling link is cleared, so later steps read current
    // persisted state rather than the copy loaded above.
    var habit = habitResult.getOrNull();
    if (habit == null) {
      return HabitMigrationOutcome(
        habitId: habitId,
        state: MigrationState.failed,
        verification: MigrationVerification.absent('Habit not found'),
        error: 'Habit not found',
      );
    }

    final expectedId = HabitTaskIdentity.taskIdForHabit(habit.id);
    final originalCounters = _streakCounters(habit);
    final expectedCapabilities = LegacyHabitCapabilities.fromHabit(habit);

    var recoveredDanglingLink = false;
    var task = await _findTask(expectedId);
    var identitySource = MigrationIdentitySource.deterministicId;
    final duplicates = <String>[];
    var tasksCreated = 0;

    // A link that points at nothing is worse than no link: the Stage L audit
    // showed the old code skipped on `taskId != null` and never looked the Task
    // up, so a deleted Task left the habit permanently un-migratable. Resolve
    // the link instead of trusting it.
    if (task == null && habit.taskId != null) {
      final linked = await _findTask(habit.taskId!);
      if (linked != null) {
        // The habit points at a Task that exists but is not the deterministic
        // one - an older attempt's random id. Adopt it rather than creating a
        // second Task for the same habit.
        task = linked;
        identitySource = MigrationIdentitySource.existingLink;
      } else {
        habit = await _clearTaskLink(habit);
        recoveredDanglingLink = true;
      }
    } else if (task != null && habit.taskId == task.id) {
      identitySource = MigrationIdentitySource.existingLink;
    }

    if (task == null) {
      // No deterministic Task and no usable link: look for a Task an older
      // attempt created with a random id before creating a second one.
      final candidates = await _logicalMatchesFor(habit);
      if (candidates.isNotEmpty) {
        candidates.sort();
        task = await _findTask(candidates.first);
        duplicates.addAll(candidates.skip(1));
        identitySource = MigrationIdentitySource.logicalAdoption;
      }
    }

    if (task == null) {
      task = await _createTaskFor(habit, expectedId);
      if (task == null) {
        return HabitMigrationOutcome(
          habitId: habit.id,
          state: MigrationState.failed,
          verification: MigrationVerification.absent('Task creation failed'),
          error: 'Task creation failed',
        );
      }
      tasksCreated++;
      identitySource = MigrationIdentitySource.created;
    }

    await _copyHistory(habit, task.id);

    await _writeLink(habit, task.id);

    // Stage L1.3: converge the canonical capability fields on every path, not
    // just on the create path. A Task resolved as an existing link, recovered
    // from a dangling link, or adopted from an older attempt's random id may
    // predate this stage and therefore carry none of the five values - the
    // adoption path in particular copies only title/timestamps/schedule, so
    // without this the very act of recognising an already-migrated Task would
    // leave the canonical side permanently empty.
    task = await _syncCapabilities(habit, task);

    final verification = await _verify(
      habit,
      task,
      expectedCapabilities,
      originalCounters,
      tasksCreated,
    );

    final MigrationState state;
    if (recoveredDanglingLink) {
      state = MigrationState.recoveredDanglingLink;
    } else if (identitySource == MigrationIdentitySource.created) {
      state = MigrationState.migrated;
    } else if (identitySource == MigrationIdentitySource.existingLink) {
      state = MigrationState.alreadyMigrated;
    } else {
      state = MigrationState.adoptedExistingTask;
    }

    return HabitMigrationOutcome(
      habitId: habit.id,
      state: state,
      taskId: task.id,
      identitySource: identitySource,
      duplicateTaskIds: duplicates,
      verification: verification,
    );
  }

  /// Convenience method that runs the full migration in one call.
  ///
  /// 1. Runs the parity gate (archived habits included).
  /// 2. Migrates every eligible habit through the state machine.
  ///
  /// Returns the [MigrationReport], the per-habit outcomes, and the count of
  /// habits this run actually created a Task for.
  Future<
      ({
        MigrationReport report,
        List<HabitMigrationOutcome> outcomes,
        int migratedCount
      })> runFullMigration() async {
    final report = await runParityGate();
    final outcomes = await migrateHabits(report.eligible);
    return (
      report: report,
      outcomes: outcomes,
      migratedCount: outcomes.where((o) => o.createdTask).length,
    );
  }

  /// Stage L2 (D4): migrates every eligible habit that has no link yet.
  ///
  /// Unlike [runFullMigration] this is not gated on the one-time migration
  /// marker: it runs on every launch while the cutover gate is open, adopting
  /// habits that a failed create left unlinked, so a habit can never be stranded
  /// in the legacy regime by one bad write.
  ///
  /// It deliberately skips any habit that already carries a `taskId`, including
  /// a dangling one. A dangling link is the residue of a pair the user deleted
  /// (Stage L2 D3); re-migrating it would resurrect a Task and history that were
  /// intentionally removed, so the backfill reports nothing and moves on.
  Future<List<HabitMigrationOutcome>> migrateUnlinkedHabits() async {
    final report = await runParityGate(includeArchived: true);
    final habitsResult =
        await _habitRepository.getAllHabits(includeArchived: true);
    final habits = habitsResult.getOrNull();
    if (habits == null) {
      throw StateError('Backfill could not read habits to migrate.');
    }
    final eligible = report.eligible.toSet();
    final targets = [
      for (final habit in habits)
        if (habit.taskId == null && eligible.contains(habit.id)) habit.id,
    ];
    if (targets.isEmpty) return const [];
    return migrateHabits(targets);
  }

  Future<Task?> _findTask(String id) async =>
      (await _taskRepository.getTaskById(id)).getOrNull();

  Future<Habit?> _findHabit(String id) async =>
      (await _habitRepository.getHabitById(id)).getOrNull();

  /// Creates the Task for [habit] under its deterministic id.
  ///
  /// Archive state is carried across: Stage L found the old copy hard-coded
  /// `status: todo`, which would have resurrected every archived habit as an
  /// active task. `archivedAt` reuses the habit's `updatedAt` rather than
  /// `AppClock.now()` so a re-run produces an identical record.
  ///
  /// The five capability fields are written here too (Stage L1.3), so a Task
  /// is born complete rather than being backfilled afterwards - a run that
  /// creates the Task and then dies before the capability sync still leaves a
  /// Task that carries the habit's values.
  Future<Task?> _createTaskFor(Habit habit, String taskId) async {
    final result = await _taskRepository.createTask(
      LegacyHabitCapabilities.fromHabit(habit).applyTo(Task(
        id: taskId,
        title: habit.title,
        description: habit.description,
        createdAt: habit.createdAt,
        updatedAt: AppClock.now(),
        sortOrder: habit.sortOrder,
        status: habit.isArchived ? TaskStatus.archived : TaskStatus.todo,
        schedule: habit.recurringSchedule,
        projectId: habit.projectId,
        goalId: habit.goalId,
        category: habit.category,
        archivedAt: habit.isArchived ? habit.updatedAt : null,
      )),
    );
    return result.getOrNull();
  }

  /// Copies every legacy completion row to the Task, exactly once.
  ///
  /// Each copy gets an id derived from its source row, and a row whose derived
  /// id already exists is skipped, so re-running appends nothing. Copied rows
  /// carry `habitId: null` and `itemType: 'task'`, which is what keeps Analytics
  /// from counting them a second time: every habit-scoped read filters on
  /// `habitId == habitId` or on `isHabitCompletion`, and both exclude a row
  /// with a null `habitId`.
  Future<void> _copyHistory(Habit habit, String taskId) async {
    final legacyResult =
        await _habitRepository.getCompletionsForHabit(habit.id);
    final legacy = legacyResult.getOrElse((_) => const <HabitCompletion>[]);
    if (legacy.isEmpty) return;

    final allResult = await _habitRepository.getAllCompletions();
    final all = allResult.getOrElse((_) => const <HabitCompletion>[]);

    final existingIds = all.map((c) => c.id).toSet();

    // Ids alone are not enough. When this run adopts a Task an older attempt
    // already copied into - one with a random id, so its completion rows carry
    // random ids too - a derived-id check finds nothing and re-copies every
    // occurrence, doubling the Task's history and inflating its streak. Matching
    // on the occurrence itself (day plus count plus duration) recognises what an
    // earlier attempt already wrote, while still letting two genuinely distinct
    // same-day rows through.
    final covered = <String>{};
    for (final c
        in all.where((c) => c.itemId == taskId && c.itemType == 'task')) {
      covered.add(_occurrenceKey(c));
    }

    for (final completion in legacy) {
      final copyId = HabitTaskIdentity.completionIdForCopy(completion.id);
      if (existingIds.contains(copyId)) continue;

      final key = _occurrenceKey(completion);
      if (covered.contains(key)) continue;

      await _habitRepository.createCompletion(HabitCompletion(
        id: copyId,
        habitId: null,
        itemId: taskId,
        itemType: 'task',
        completedAt: completion.completedAt,
        count: completion.count,
        duration: completion.duration,
        note: completion.note,
        moodRating: completion.moodRating,
        energyRating: completion.energyRating,
      ));
      existingIds.add(copyId);
      covered.add(key);
    }
  }

  /// Identity of a single occurrence, independent of which row recorded it.
  static String _occurrenceKey(HabitCompletion c) =>
      '${c.completedAt.startOfDay.toIso8601String()}|${c.count}|${c.duration?.inMinutes ?? -1}';

  /// Tasks that could be another copy of this habit's work.
  ///
  /// Matches on the content the migration copies, and skips any Task already
  /// claimed by some habit's `taskId`, so adopting one cannot steal another
  /// habit's Task. When several match, the lowest id is adopted and the rest are
  /// reported rather than deleted.
  Future<List<String>> _logicalMatchesFor(Habit habit) async {
    final allResult = await _taskRepository.getAllTasks(includeArchived: true);
    final tasks = allResult.getOrElse((_) => const <Task>[]);

    final habitsResult =
        await _habitRepository.getAllHabits(includeArchived: true);
    final claimed = habitsResult
        .getOrElse((_) => const <Habit>[])
        .where((h) => h.id != habit.id && h.taskId != null)
        .map((h) => h.taskId!)
        .toSet();

    final expectedSchedule = jsonEncode(habit.recurringSchedule.toJson());

    return tasks
        .where((t) => !claimed.contains(t.id))
        .where((t) => t.id != HabitTaskIdentity.taskIdForHabit(habit.id))
        .where((t) => t.title == habit.title)
        .where((t) => t.createdAt == habit.createdAt)
        .where((t) => t.projectId == habit.projectId)
        .where((t) => t.goalId == habit.goalId)
        .where((t) => t.category == habit.category)
        .where((t) => t.schedule is Recurring)
        .where((t) => jsonEncode(t.schedule.toJson()) == expectedSchedule)
        .map((t) => t.id)
        .toList();
  }

  /// Clears a `taskId` that points at a Task which no longer exists.
  ///
  /// Returns the habit as persisted, so the caller keeps working from current
  /// state. Ignoring the return value is not safe: [migrateHabit] goes on to
  /// [_writeLink], whose skip-check compares `habit.taskId` against the target
  /// and would otherwise see the stale pre-clearing value, decide the link was
  /// already written, and write nothing - leaving the habit unlinked.
  Future<Habit> _clearTaskLink(Habit habit) async {
    final result =
        await _habitRepository.updateHabit(habit.copyWith(taskId: null));
    return result.getOrElse((_) => habit.copyWith(taskId: null));
  }

  /// Persists the habit -> task link, skipping the write when it already holds.
  ///
  /// The skip matters for the "does not repeatedly rewrite already-verified
  /// records" requirement: a fully migrated install performs no habit writes on
  /// subsequent launches.
  Future<Habit> _writeLink(Habit habit, String taskId) async {
    if (habit.taskId == taskId) return habit;
    final updated = habit.copyWith(taskId: taskId, updatedAt: AppClock.now());
    final result = await _habitRepository.updateHabit(updated);
    return result.getOrElse((_) => updated);
  }

  /// Writes the habit's five capabilities onto [task] if they are not already
  /// there, and returns the task as it now stands.
  ///
  /// Writes only on divergence, so a fully migrated install performs no task
  /// write at all. On a failed write the caller gets the task it passed in and
  /// [_verify] reports the divergence it then reads back - a silent success
  /// would retire the check that exists to catch exactly this.
  Future<Task> _syncCapabilities(Habit habit, Task task) async {
    final expected = LegacyHabitCapabilities.fromHabit(habit);
    if (expected.matchesTask(task)) return task;
    final result = await _taskRepository.updateTask(expected.applyTo(task));
    return result.getOrNull() ?? task;
  }

  /// The Stage L1.3 capability bridge: every linked habit's Task holds that
  /// habit's five capability values.
  ///
  /// ## Why this exists alongside [migrateHabit]
  ///
  /// [migrateHabit] writes the capabilities for any habit it processes, but
  /// the production runner is gated on the Stage L0 marker and skips entirely
  /// once that is written. An install that completed L0 before this stage has
  /// Tasks with no capability keys at all, and would never be touched again
  /// while still reading as perfectly migrated. This method is the pass that
  /// reaches them.
  ///
  /// ## Deliberate non-goals
  ///
  ///  * It never creates a Task and never writes a `taskId`. It only corrects
  ///    fields on a Task that already exists; dangling links are a separate
  ///    state machine with their own tests, and quietly resurrecting a Task
  ///    here would hide it.
  ///  * It never writes the Habit. The legacy record remains the writer of
  ///    these five fields until Stage L2 moves the write path, and a bridge
  ///    that wrote both sides would be a second writer with no one to arbitrate
  ///    it.
  ///  * It is idempotent and diff-based rather than marker-gated, so a write
  ///    that fails for any reason is retried on the next launch and a value
  ///    edited after migration is picked up without a second mechanism.
  ///
  /// The retirement condition - and the one thing that must happen before
  /// anything reads these five values from `Task` in production - is recorded
  /// in `docs/ascend-stage-l1-design.md`.
  Future<CapabilitySyncReport> syncTaskCapabilities() async {
    final habitsResult =
        await _habitRepository.getAllHabits(includeArchived: true);
    final habits = habitsResult.getOrNull();
    if (habits == null) {
      throw StateError(
        'capability bridge could not read habits: '
        '${habitsResult.left?.message}',
      );
    }

    var checked = 0;
    var updated = 0;
    var verified = 0;
    var unmatched = 0;
    var failed = 0;

    for (final habit in habits.where((h) => h.taskId != null)) {
      final taskId = habit.taskId!;
      final expected = LegacyHabitCapabilities.fromHabit(habit);

      final task = await _findTask(taskId);
      if (task == null) {
        // Reported, not failed: the link is dangling, which is Stage L1.4's
        // recovery state, and the habit's own capabilities are still intact
        // on the legacy record, so nothing has been lost.
        unmatched++;
        continue;
      }
      checked++;

      if (!expected.matchesTask(task)) {
        final write = await _taskRepository.updateTask(expected.applyTo(task));
        if (write.isLeft) {
          failed++;
          continue;
        }
        updated++;
      }

      final reread = await _findTask(taskId);
      if (reread != null && expected.matchesTask(reread)) {
        verified++;
      } else {
        failed++;
      }
    }

    return CapabilitySyncReport(
      checked: checked,
      updated: updated,
      verified: verified,
      unmatched: unmatched,
      failed: failed,
    );
  }

  /// Reads persisted state back and records what actually holds.
  Future<MigrationVerification> _verify(
    Habit habit,
    Task task,
    LegacyHabitCapabilities expectedCapabilities,
    ({int current, int longest, int total}) originalCounters,
    int tasksCreated,
  ) async {
    final failures = <String>[];

    // Re-read rather than trusting the in-memory copy: the point of
    // verification is to confirm the *write*, which a stale object would happily
    // agree with.
    final persistedTask = await _findTask(task.id);
    if (persistedTask == null) {
      failures.add('Task ${task.id} is not readable after write');
    }

    final persistedHabit = await _findHabit(habit.id);

    // The link is the whole point of the migration, so it is verified as its own
    // condition rather than inferred from the Task having been created. A write
    // that silently dropped `taskId` would otherwise look identical to success
    // and the next launch would start over.
    final linkPersisted = persistedHabit?.taskId == task.id;
    if (!linkPersisted) {
      failures.add(persistedHabit == null
          ? 'habit ${habit.id} is not readable after write'
          : 'habit ${habit.id} was not linked to ${task.id}');
    }

    final taskExists = persistedTask != null;
    final taskIsRecurring = persistedTask?.schedule is Recurring;
    if (taskExists && !taskIsRecurring) {
      failures.add('Task schedule is not recurring');
    }

    final schedulePreserved = persistedTask != null &&
        jsonEncode(persistedTask.schedule.toJson()) ==
            jsonEncode(habit.recurringSchedule.toJson());
    if (taskExists && !schedulePreserved) {
      failures.add('Task schedule does not match the habit recurrence');
    }

    final projectIdPreserved = persistedTask?.projectId == habit.projectId;
    if (taskExists && !projectIdPreserved) {
      failures.add('projectId not preserved');
    }

    final goalIdPreserved = persistedTask?.goalId == habit.goalId;
    if (taskExists && !goalIdPreserved) {
      failures.add('goalId not preserved');
    }

    // An archived habit must land as an archived Task, never as a live one.
    final archivedStatePreserved = persistedTask != null &&
        (habit.isArchived
            ? persistedTask.status == TaskStatus.archived
            : persistedTask.status != TaskStatus.archived);
    if (taskExists && !archivedStatePreserved) {
      failures.add(habit.isArchived
          ? 'archived habit did not produce an archived Task'
          : 'active habit produced an archived Task');
    }

    final capabilitiesNow = persistedHabit == null
        ? null
        : LegacyHabitCapabilities.fromHabit(persistedHabit);
    final lostFields =
        capabilitiesNow?.fieldsLostFrom(habit) ?? const <String>[];
    final legacyCapabilitiesPreserved =
        persistedHabit != null && lostFields.isEmpty;
    if (!legacyCapabilitiesPreserved) {
      failures.add('legacy capabilities lost: ${lostFields.join(', ')}');
    }

    // Stage L1.3: the canonical side must hold the same five values. Compared
    // against [expectedCapabilities] - what this run was asked to move - rather
    // than against [capabilitiesNow], so a divergence between the two
    // representations cannot cancel itself out.
    final taskCapabilitiesLost = persistedTask == null
        ? const <String>[]
        : expectedCapabilities.fieldsLostFromTask(persistedTask);
    final taskCapabilitiesPresent =
        persistedTask != null && taskCapabilitiesLost.isEmpty;
    if (taskExists && !taskCapabilitiesPresent) {
      failures
          .add('task capabilities missing: ${taskCapabilitiesLost.join(', ')}');
    }

    final legacyResult =
        await _habitRepository.getCompletionsForHabit(habit.id);
    final legacy = legacyResult.getOrElse((_) => const <HabitCompletion>[]);
    final allResult = await _habitRepository.getAllCompletions();
    final all = allResult.getOrElse((_) => const <HabitCompletion>[]);
    final taskRows =
        all.where((c) => c.itemId == task.id && c.itemType == 'task').toList();

    // Checked by occurrence rather than by derived id, for the same reason
    // [_copyHistory] writes that way: an adopted Task may already carry rows from
    // an older attempt under ids this run did not and will not generate, and
    // demanding a specific id would report preserved history as missing.
    final available = taskRows.map(_occurrenceKey).toList();
    final missing =
        legacy.where((c) => !available.remove(_occurrenceKey(c))).length;
    final historyPreserved = missing == 0;
    if (!historyPreserved) {
      failures.add('$missing completion row(s) not copied to the Task');
    }

    // The migration must not restate the habit's history; it moves storage, not
    // numbers. See kStreakSemanticsDelta.
    final streakCountersPreserved = persistedHabit != null &&
        _streakCounters(persistedHabit) == originalCounters;
    if (!streakCountersPreserved) {
      failures.add('habit streak counters changed during migration');
    }

    // "No duplicate introduced" is scoped to *this run*: it created at most one Task
    // for this habit. Duplicates left behind by an older attempt are a
    // pre-existing condition, reported separately on the outcome rather than
    // counted here - otherwise adopting one would read as a fresh failure and a
    // retry would never converge.
    final noDuplicateLogicalTask = tasksCreated <= 1;
    if (!noDuplicateLogicalTask) {
      failures.add('migration created $tasksCreated Tasks for one habit');
    }

    // Stage L1.4: a Task this run created must carry the deterministic id
    // ([HabitTaskIdentity.taskIdForHabit]). A Task that was *adopted* (already
    // present, read back before this run created anything) legitimately holds
    // whatever id it has, so the check applies only when `tasksCreated > 0`.
    final deterministicIdentity = tasksCreated == 0 ||
        (persistedTask?.id ?? task.id) ==
            HabitTaskIdentity.taskIdForHabit(habit.id);
    if (!deterministicIdentity) {
      failures
          .add('created Task id is not deterministic for habit ${habit.id}');
    }

    return MigrationVerification(
      taskExists: taskExists,
      taskIsRecurring: taskIsRecurring,
      schedulePreserved: schedulePreserved,
      projectIdPreserved: projectIdPreserved,
      goalIdPreserved: goalIdPreserved,
      archivedStatePreserved: archivedStatePreserved,
      legacyCapabilitiesPreserved: legacyCapabilitiesPreserved,
      legacyCapabilitiesLost: lostFields,
      taskCapabilitiesPresent: taskCapabilitiesPresent,
      taskCapabilitiesLost: taskCapabilitiesLost,
      historyPreserved: historyPreserved,
      historyRowsMissing: missing,
      streakCountersPreserved: streakCountersPreserved,
      noDuplicateLogicalTask: noDuplicateLogicalTask,
      deterministicIdentity: deterministicIdentity,
      failures: failures,
    );
  }

  ({int current, int longest, int total}) _streakCounters(Habit habit) => (
        current: habit.currentStreak,
        longest: habit.longestStreak,
        total: habit.totalCompletions,
      );
}

/// Extension on Result to get value or null.
extension ResultGetOrNull<T> on Result<T> {
  /// `null` when this is a failure, the value otherwise.
  ///
  /// Reads [Either.right] directly instead of `fold((_) => null as T, ...)`:
  /// that cast throws a `TypeError` for every non-nullable `T`, so the "safe
  /// null" accessor crashed instead of returning null. It only ever appeared to
  /// work because each call site so far returned a nullable `T` (`Task?`,
  /// `Habit?`), where the cast happens to succeed.
  T? getOrNull() => isLeft ? null : right;
}
