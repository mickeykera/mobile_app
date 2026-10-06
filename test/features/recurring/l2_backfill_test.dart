import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/habits/data/repositories/habit_repository_impl.dart';
import 'package:ascend/features/recurring/domain/cutover_readiness.dart';
import 'package:ascend/features/recurring/domain/migration.dart';
import 'package:ascend/features/recurring/domain/migration_runner.dart';
import 'package:ascend/features/tasks/data/repositories/task_repository_impl.dart';

import 'l1_5_shared.dart';

/// Stage L2 D4: the gate-gated startup backfill.
///
/// The marker still governs the one-shot migration; the backfill is a separate,
/// every-launch sweep for eligible habits that never got a link. These tests
/// pin that it links them, leaves dangling habits alone, is idempotent, and
/// never rewrites the marker.
void main() {
  l1_5EnsureBinding();

  final now = DateTime(2025, 6, 11, 9);

  setUp(() {
    AppClock.debugSetNow(() => now);
    CutoverGate.enabled = true;
  });

  tearDown(() {
    AppClock.debugResetNow();
    CutoverGate.enabled = false;
  });

  HabitTaskMigrationRunner runnerFor(dynamic database) =>
      HabitTaskMigrationRunner(
        migration: MigrationService(
          HabitRepositoryImpl(database),
          TaskRepositoryImpl(database),
        ),
        database: database,
      );

  test('a late unlinked habit is linked on the next launch', () async {
    final database = await l1_5FreshDatabase();
    await l1_5EligibleHabit(database, completions: 1);

    await runnerFor(database).runIfRequired();

    // A habit that never received a link, as a create-rollback or an older
    // install would leave behind.
    final late =
        await l1_5EligibleHabit(database, title: 'Late arrival', completions: 1);
    final markerBefore = database.getJson('habit_task_migration');

    final second = await runnerFor(database).runIfRequired();

    expect(second.ran, isFalse, reason: 'marker short-circuits the migration');

    final lateReloaded = await l1_5ReloadHabit(database, late.id);
    expect(lateReloaded.taskId, isNotNull);
    expect(database.getJson('habit_task_migration'), equals(markerBefore));

    final tasks = await l1_5AllTasks(database);
    expect(tasks.where((t) => t.id == lateReloaded.taskId).length, 1);
    // The already-linked habit was not re-migrated into a duplicate Task.
    expect(tasks.length, 2);
  });

  test('the backfill is idempotent across launches', () async {
    final database = await l1_5FreshDatabase();
    await l1_5EligibleHabit(database, title: 'Seed', completions: 1);
    final late =
        await l1_5EligibleHabit(database, title: 'Late arrival', completions: 1);

    await runnerFor(database).runIfRequired();
    final afterFirst = (await l1_5AllTasks(database)).length;
    await runnerFor(database).runIfRequired();
    final afterSecond = (await l1_5AllTasks(database)).length;

    expect((await l1_5ReloadHabit(database, late.id)).taskId, isNotNull);
    expect(afterSecond, afterFirst);
    expect(afterSecond, 2);
  });

  test('a dangling link is never resurrected by the backfill', () async {
    final database = await l1_5FreshDatabase();

    // Mark the install complete with no habits at all.
    await runnerFor(database).runIfRequired();

    final seeded = await l1_5EligibleHabit(database, completions: 1);
    final habitRepo = HabitRepositoryImpl(database);
    // Simulate residue from a delete whose Task step succeeded: the link points
    // at a Task that no longer exists.
    await habitRepo.updateHabit(seeded.copyWith(taskId: 'task_hm_gone'));

    await runnerFor(database).runIfRequired();

    expect(await l1_5AllTasks(database), isEmpty);
    expect((await l1_5ReloadHabit(database, seeded.id)).taskId, 'task_hm_gone');
  });

  test('with the gate closed the backfill does not run', () async {
    final database = await l1_5FreshDatabase();
    CutoverGate.enabled = false;

    await runnerFor(database).runIfRequired();

    final late =
        await l1_5EligibleHabit(database, title: 'Late arrival', completions: 1);

    await runnerFor(database).runIfRequired();

    expect((await l1_5ReloadHabit(database, late.id)).taskId, isNull);
    expect(await l1_5AllTasks(database), isEmpty);
  });
}