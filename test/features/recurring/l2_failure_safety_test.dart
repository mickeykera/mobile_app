import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/recurring/domain/cutover_readiness.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';

import 'l1_5_shared.dart';
import 'l2_shared.dart';

/// Stage L2 failure safety: the canonical-first + mirror + compensating-rollback
/// contract, and the ordered-delete residue table.
///
/// Every scenario asserts three things: the operation returned `Left`, the pair
/// is in the documented state, and the auditor agrees. A failure that leaves the
/// pair silently diverged is the bug this file exists to catch.
void main() {
  l1_5EnsureBinding();

  final now = DateTime(2025, 6, 11, 9);
  late L2FailingHabitRepository habits;
  late L2FailingTaskRepository tasks;
  late L2Rig rig;
  late Habit linked;

  setUp(() async {
    AppClock.debugSetNow(() => now);
    CutoverGate.enabled = true;
  });

  tearDown(() {
    AppClock.debugResetNow();
    CutoverGate.enabled = false;
  });

  Future<Task?> taskFor(String id) async =>
      (await tasks.getTaskById(id)).fold((_) => null, (t) => t);

  /// Seeds a migrated pair, then builds the rig over the failing repositories.
  Future<void> seedLinked({int completions = 1}) async {
    final database = await l1_5FreshDatabase();
    final seeded =
        await l1_5EligibleHabit(database, completions: completions);
    await l1_5MigrateOne(database, seeded.id);
    linked = await l1_5ReloadHabit(database, seeded.id);
    habits = L2FailingHabitRepository(database);
    tasks = L2FailingTaskRepository(database);
    rig = l2RigOn(database, habitRepository: habits, taskRepository: tasks);
    await rig.ready();
  }

  test('canonical write failure: nothing is touched and the result is Left',
      () async {
    await seedLinked();
    tasks.failUpdate = 1;

    final result = await rig.habitController
        .updateHabit(linked.copyWith(title: 'Doomed', updatedAt: now));

    expect(result.isLeft, isTrue);
    expect((await l1_5ReloadHabit(rig.database, linked.id)).title, 'Read');
    expect((await taskFor(linked.taskId!))!.title, 'Read');
    expect((await rig.audit()).isClean, isTrue);
  });

  test('mirror failure: the canonical write is rolled back and it is Left',
      () async {
    await seedLinked();
    habits.failUpdate = 1;

    final result = await rig.habitController
        .updateHabit(linked.copyWith(title: 'Doomed', updatedAt: now));

    expect(result.isLeft, isTrue);
    // Rollback restored the Task, so both sides still read the old title.
    expect((await taskFor(linked.taskId!))!.title, 'Read');
    expect((await l1_5ReloadHabit(rig.database, linked.id)).title, 'Read');
    expect((await rig.audit()).isClean, isTrue);

    // And the bridge, run the way launch runs it, has nothing to converge.
    final bridge = await l1_5SyncCapabilities(rig.database);
    expect(bridge.updated, 0);
  });

  test('task-side mirror failure rolls the Task back and it is Left', () async {
    await seedLinked();
    final task = (await taskFor(linked.taskId!))!;
    habits.failUpdate = 1;

    final result = await rig.taskController
        .updateTask(task.copyWith(title: 'Doomed', updatedAt: now));

    expect(result.isLeft, isTrue);
    expect((await taskFor(linked.taskId!))!.title, 'Read');
    expect((await l1_5ReloadHabit(rig.database, linked.id)).title, 'Read');
    expect((await rig.audit()).isClean, isTrue);
  });

  test('migrate-on-create failure leaves neither a habit nor a task', () async {
    final database = await l1_5FreshDatabase();
    habits = L2FailingHabitRepository(database);
    tasks = L2FailingTaskRepository(database);
    tasks.failCreate = 1;
    rig = l2RigOn(database, habitRepository: habits, taskRepository: tasks);
    await rig.ready();

    final result = await rig.habitController
        .createHabit(title: 'Doomed', category: 'Mind');

    expect(result.isLeft, isTrue);
    expect(await l1_5AllHabits(database), isEmpty);
    expect(await l1_5AllTasks(database), isEmpty);
  });

  test('delete step 1 failure: nothing changes', () async {
    await seedLinked();
    tasks.failDelete = 1;

    final result = await rig.habitController.deleteHabit(linked.id);

    expect(result.isLeft, isTrue);
    expect(await taskFor(linked.taskId!), isNotNull);
    expect((await l1_5ReloadHabit(rig.database, linked.id)).id, linked.id);
    final audit = await rig.audit();
    expect(audit.isClean, isTrue, reason: '$audit');
  });

  test('delete step 2 failure: dangling link with history intact', () async {
    await seedLinked();
    habits.failDeleteCompletion = 1;

    final result = await rig.habitController.deleteHabit(linked.id);

    expect(result.isLeft, isTrue);
    expect(await taskFor(linked.taskId!), isNull, reason: 'task deleted first');
    expect((await l1_5ReloadHabit(rig.database, linked.id)).id, linked.id);
    expect(await l1_5HabitRows(rig.database, linked.id), isNotEmpty);

    final audit = await rig.audit();
    expect(audit.isClean, isFalse);
    expect(audit.danglingTaskIds, contains(linked.taskId));
  });

  test('delete step 3 failure: task and its rows gone, habit remains', () async {
    await seedLinked();
    habits.failDelete = 1;

    final result = await rig.habitController.deleteHabit(linked.id);

    expect(result.isLeft, isTrue);
    expect(await taskFor(linked.taskId!), isNull);
    expect(await l1_5TaskRows(rig.database, linked.taskId!), isEmpty);
    expect((await l1_5ReloadHabit(rig.database, linked.id)).id, linked.id);
    expect(await l1_5HabitRows(rig.database, linked.id), isNotEmpty);

    final audit = await rig.audit();
    expect(audit.danglingTaskIds, contains(linked.taskId));
  });

  test('archive mirror failure rolls the Task date back', () async {
    await seedLinked();
    habits.failArchive = 1;

    final result = await rig.taskController.archiveTask(linked.taskId!);

    expect(result.isLeft, isTrue);
    expect((await taskFor(linked.taskId!))!.status, TaskStatus.todo);
    expect((await l1_5ReloadHabit(rig.database, linked.id)).isArchived, isFalse);
    expect((await rig.audit()).isClean, isTrue);
  });
}