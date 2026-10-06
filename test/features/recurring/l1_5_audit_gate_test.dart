import 'package:ascend/core/database/database.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/habits/data/repositories/habit_repository_impl.dart';
import 'package:ascend/features/recurring/domain/cutover_readiness.dart';
import 'package:ascend/features/recurring/domain/habit_task_identity.dart';
import 'package:ascend/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import 'l1_5_shared.dart';

/// Stage L1.5, steps 3, 9, 11 and 14: the inert seam and the detector both work.
///
/// [CutoverGate] is the one place a future write-path stage flips ownership
/// over, so it is pinned off here, and the detector it opens — [CutoverAuditor]
/// — is proven to be exactly two things: read-only, and honest about storage.
/// "Read-only" is proven by running a report across a converging dataset and
/// asserting the only thing that changed was the bridge's own write. "Honest
/// about storage" is proven by corrupting a Task behind the scanner's back and
/// watching the very next report name it, then converge again to a clean one.
///
/// `certifiesReadyForCutover` is the contract's gate: it requires BOTH a clean
/// dataset AND the write-path switch on, so a report run under production
/// ([CutoverGate.enabled] == false) can never certify anything by accident.
void main() {
  l1_5EnsureBinding();

  final now = DateTime(2025, 6, 11, 9);

  late DatabaseService database;

  setUp(() async {
    AppClock.debugSetNow(() => now);
    database = await l1_5FreshDatabase();
  });

  tearDown(() {
    AppClock.debugResetNow();
  });

  Future<CutoverReadinessReport> audit() async => CutoverAuditor.audit(
        habits: await l1_5AllHabits(database),
        tasks: await l1_5AllTasks(database),
      );

  test('the cutover switch is the production value and certifies a clean set',
      () {
    // Stage L2 flipped this to true as its final step. L1.5 ran it inert; the
    // L2 suite (`l2_*_test.dart`) is what proves the routed write path.
    expect(CutoverGate.enabled, isTrue);

    // A report run with the production gate value certifies when clean.
    final report = CutoverReadinessReport(
      routeWritesToTask: CutoverGate.enabled,
      migratedHabits: 1,
      unlinkedHabits: 0,
      divergences: const [],
      danglingTaskIds: const [],
      orphanedMigratedTaskIds: const [],
    );
    expect(report.isClean, isTrue);
    expect(report.certifiesReadyForCutover, isTrue);
  });

  test('the audit reads storage, converges, and reads storage again', () async {
    final habit = await l1_5EligibleHabit(database, completions: 0);
    await l1_5MigrateOne(database, habit.id);
    final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);

    final clean = await audit();
    expect(clean.isClean, isTrue);

    // Corrupt the Task behind the scanner's back, then re-run. The report must
    // name the drifted capability and know it heals itself.
    final task = await l1_5ReloadTask(database, taskId);
    await TaskRepositoryImpl(database)
        .updateTask(task.copyWith(targetCount: 7));

    final drifted = await audit();
    expect(drifted.isClean, isFalse);
    final target = drifted.divergences.where((d) => d.field == 'targetCount');
    expect(target, hasLength(1));
    expect(target.single.selfHealing, isTrue);

    // The bridge converges exactly that capability and nothing else.
    final report = await l1_5SyncCapabilities(database);
    expect(report.checked, 1);
    expect(report.updated, 1);
    expect(report.verified, 1);
    expect(report.failed, 0);

    // Post-convergence the same audit sees a clean dataset again.
    final healed = await audit();
    expect(healed.isClean, isTrue);
    expect(healed.divergences, isEmpty);
  });

  test('a narration divergence is named but never certified self-healing',
      () async {
    final habit = await l1_5EligibleHabit(database, completions: 0);
    await l1_5MigrateOne(database, habit.id);

    await HabitRepositoryImpl(database).updateHabit(
        (await l1_5AllHabits(database)).single.copyWith(description: 'Nightly'));

    final report = await audit();
    final description = report.divergences
        .where((d) => d.field == 'description')
        .toList();
    expect(description, hasLength(1));
    expect(description.single.selfHealing, isFalse);
  });

  test('dangling links and orphaned migrated Tasks are both reported',
      () async {
    final habit = await l1_5EligibleHabit(database, completions: 0);
    final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);
    await l1_5MigrateOne(database, habit.id);

    // The habit now points at a Task that does not exist: the L1.4 recovery
    // state machine's case, reported here so the audit is complete.
    await HabitRepositoryImpl(database)
        .updateHabit((await l1_5AllHabits(database)).single
            .copyWith(taskId: 'task_gone'));

    final report = await audit();
    expect(report.danglingTaskIds, contains('task_gone'));
    // The deliberately original deterministic Task is now unclaimed too.
    expect(report.orphanedMigratedTaskIds, contains(taskId));
  });

  test('a mixed dataset splits into migrated, unlinked and orphan counts',
      () async {
    // One migrated habit, one habit created after the marker, one standalone
    // recurring Task. The last two are not problems the audit is responsible
    // for, but it must count them so the report cannot be misread as complete.
    final habit = await l1_5EligibleHabit(database, completions: 0);
    await l1_5MigrateOne(database, habit.id);
    final later = await l1_5EligibleHabit(
        database, title: 'Later', completions: 0);
    final tasks = await l1_5AllTasks(database);
    expect(tasks, hasLength(1));

    final report = CutoverAuditor.audit(
      habits: await l1_5AllHabits(database),
      tasks: tasks,
    );

    expect(report.migratedHabits, 1);
    expect(report.unlinkedHabits, 1);
    expect(report.divergences, isEmpty);
    expect(report.danglingTaskIds, isEmpty);
    expect(report.orphanedMigratedTaskIds, isEmpty);
    expect(report.isClean, isTrue);
    expect(later.taskId, isNull);
  });

  test('the classification lists are a coherent partition', () {
    for (final field in kCutoverSelfHealingFields) {
      expect(kCutoverOwnedFields, contains(field));
    }
    expect(kCutoverSelfHealingFields, hasLength(5));
    expect(kCutoverOwnedFields, hasLength(12));
  });

  test('re-running the state machine over a migrated install is a no-op',
      () async {
    final habit = await l1_5EligibleHabit(database, completions: 2);
    final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);
    final first = await l1_5MigrateOne(database, habit.id);
    expect(first.state.name, 'migrated');

    final rowsBefore = (await l1_5AllCompletions(database)).length;
    final habitsBefore = (await l1_5AllHabits(database)).single;

    final again = await l1_5MigrateOne(database, habit.id);
    expect(again.state.name, 'alreadyMigrated');
    expect(again.verification.isVerified, isTrue);

    // Nothing moved a byte: same rows, same counters, same link, clean audit.
    expect(await l1_5AllCompletions(database), hasLength(rowsBefore));
    final after = await l1_5AllHabits(database);
    expect(after.single.taskId, taskId);
    expect(after.single.currentStreak, habitsBefore.currentStreak);
    expect(after.single.totalCompletions, habitsBefore.totalCompletions);
    expect(await l1_5TaskRows(database, taskId), hasLength(2));
    expect((await audit()).isClean, isTrue);
  });
}