import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/recurring/domain/cutover_readiness.dart';
import 'package:ascend/features/recurring/domain/habit_task_identity.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';

import 'l1_5_shared.dart';
import 'l2_shared.dart';

/// Stage L2 write routing: every D1/D2/D3/D4/D5 decision, proven end to end
/// through the real controllers and the real repositories.
void main() {
  l1_5EnsureBinding();

  final now = DateTime(2025, 6, 11, 9);
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
      (await rig.taskRepository.getTaskById(id)).fold((_) => null, (t) => t);

  Future<Habit> seedLinked() async {
    final database = await l1_5FreshDatabase();
    final seeded = await l1_5EligibleHabit(database, completions: 1);
    await l1_5MigrateOne(database, seeded.id);
    linked = await l1_5ReloadHabit(database, seeded.id);
    rig = l2RigOn(database);
    await rig.ready();
    return linked;
  }

  test('D1: a habit edit writes the canonical Task and mirrors the habit',
      () async {
    await seedLinked();

    final result = await rig.habitController.updateHabit(
      linked.copyWith(title: 'Read More', updatedAt: now),
    );
    expect(result.isRight, isTrue, reason: '${result.left}');

    final task = await taskFor(linked.taskId!);
    expect(task!.title, 'Read More');
    expect((await l1_5ReloadHabit(rig.database, linked.id)).title, 'Read More');

    final audit = await rig.audit();
    expect(audit.isClean, isTrue, reason: '$audit');
  });

  test('D1: a task edit mirrors onto its claiming habit', () async {
    await seedLinked();
    final task = (await taskFor(linked.taskId!))!;

    final result = await rig.taskController
        .updateTask(task.copyWith(title: 'Renamed', updatedAt: now));
    expect(result.isRight, isTrue, reason: '${result.left}');

    expect((await l1_5ReloadHabit(rig.database, linked.id)).title, 'Renamed');
    expect((await taskFor(linked.taskId!))!.title, 'Renamed');

    final audit = await rig.audit();
    expect(audit.isClean, isTrue, reason: '$audit');
  });

  test('D1: an unlinked habit still writes legacy while a path is held',
      () async {
    final database = await l1_5FreshDatabase();
    final pure = await l1_5EligibleHabit(database,
        title: 'Journal', completions: 1);
    rig = l2RigOn(database);
    await rig.ready();

    final result = await rig.habitController.updateHabit(
      pure.copyWith(title: 'Journal Daily', updatedAt: now),
    );
    expect(result.isRight, isTrue);

    expect((await l1_5ReloadHabit(database, pure.id)).title, 'Journal Daily');
    final audit = await rig.audit();
    expect(audit.unlinkedHabits, 1);
    expect(audit.isClean, isTrue);
  });

  test('D2: archiving and unarchiving from the habit side moves the Task',
      () async {
    await seedLinked();

    expect((await rig.habitController.archiveHabit(linked.id)).isRight, isTrue);
    expect((await taskFor(linked.taskId!))!.status, TaskStatus.archived);
    expect((await l1_5ReloadHabit(rig.database, linked.id)).isArchived, isTrue);
    expect((await rig.audit()).isClean, isTrue);

    // A refresh drops archived habits from controller state, so unarchive must
    // resolve the habit from storage - the fallback this test exists for.
    await rig.habitController.refresh();
    expect((await rig.habitController.unarchiveHabit(linked.id)).isRight, isTrue);
    expect((await taskFor(linked.taskId!))!.status, TaskStatus.todo);
    expect((await l1_5ReloadHabit(rig.database, linked.id)).isArchived, isFalse);
    expect((await rig.audit()).isClean, isTrue);
  });

  test('D2: archiving and unarchiving from the task side moves the habit',
      () async {
    await seedLinked();
    final taskId = linked.taskId!;

    expect((await rig.taskController.archiveTask(taskId)).isRight, isTrue);
    expect((await l1_5ReloadHabit(rig.database, linked.id)).isArchived, isTrue);
    expect((await taskFor(taskId))!.status, TaskStatus.archived);
    expect((await rig.audit()).isClean, isTrue);

    expect((await rig.taskController.unarchiveTask(taskId)).isRight, isTrue);
    expect((await l1_5ReloadHabit(rig.database, linked.id)).isArchived, isFalse);
    expect((await taskFor(taskId))!.status, TaskStatus.todo);
    expect((await rig.audit()).isClean, isTrue);
  });

  test('D5: snoozing writes the Task override and mirrors the habit', () async {
    await seedLinked();
    final until = now.add(const Duration(hours: 3));

    final result = await rig.habitController.snoozeHabit(linked.id, until);
    expect(result.isRight, isTrue, reason: '${result.left}');

    final task = await taskFor(linked.taskId!);
    expect((task!.schedule as dynamic).snoozedUntil, until);
    expect((await l1_5ReloadHabit(rig.database, linked.id)).snoozedUntil, until);
    expect((await rig.audit()).isClean, isTrue, reason: '${await rig.audit()}');
  });

  test('D5: rescheduling writes the Task override and mirrors the habit',
      () async {
    await seedLinked();
    final due = now.add(const Duration(days: 2));

    final result = await rig.habitController.rescheduleHabit(linked.id, due);
    expect(result.isRight, isTrue, reason: '${result.left}');

    final task = await taskFor(linked.taskId!);
    expect((task!.schedule as dynamic).dueAt, due);
    expect((await l1_5ReloadHabit(rig.database, linked.id)).dueAt, due);
    expect((await rig.audit()).isClean, isTrue);
  });

  test('streak freeze is canonical and the launch bridge then writes nothing',
      () async {
    await seedLinked();

    expect((await rig.habitController.useStreakFreeze(linked.id)).isRight,
        isTrue);

    final task = await taskFor(linked.taskId!);
    expect(task!.streakFreezeUsage.used, 1);
    expect((await l1_5ReloadHabit(rig.database, linked.id)).streakFreezesUsed,
        1);
    expect((await rig.audit()).isClean, isTrue);

    // The invariant behind keeping the Habit -> Task bridge: after a successful
    // gated write the two sides agree, so the bridge's diff is empty.
    final bridge = await l1_5SyncCapabilities(rig.database);
    expect(bridge.updated, 0);
    expect(bridge.failed, 0);
  });

  test('D4: a habit created while routed is born linked to a Task', () async {
    final database = await l1_5FreshDatabase();
    rig = l2RigOn(database);
    await rig.ready();

    final result = await rig.habitController
        .createHabit(title: 'Stretch', category: 'Body');
    expect(result.isRight, isTrue, reason: '${result.left}');

    final created = result.right!;
    expect(created.taskId, isNotNull);
    final task = await taskFor(created.taskId!);
    expect(task, isNotNull);
    expect(task!.title, 'Stretch');

    final audit = await rig.audit();
    expect(audit.migratedHabits, 1);
    expect(audit.unlinkedHabits, 0);
    expect(audit.isClean, isTrue, reason: '$audit');
  });

  test('D3: deleting from the habit side removes Task, rows, habit and history',
      () async {
    await seedLinked();
    final taskId = linked.taskId!;

    final result = await rig.habitController.deleteHabit(linked.id);
    expect(result.isRight, isTrue, reason: '${result.left}');

    expect(await taskFor(taskId), isNull);
    expect(await l1_5TaskRows(rig.database, taskId), isEmpty);
    expect(
      (await l1_5AllHabits(rig.database)).where((h) => h.id == linked.id),
      isEmpty,
    );
    expect(await l1_5HabitRows(rig.database, linked.id), isEmpty);
  });

  test('D3: deleting from the task side removes the whole pair', () async {
    await seedLinked();
    final taskId = linked.taskId!;

    final result = await rig.taskController.deleteTask(taskId);
    expect(result.isRight, isTrue, reason: '${result.left}');

    expect(await taskFor(taskId), isNull);
    expect(await l1_5TaskRows(rig.database, taskId), isEmpty);
    expect(
      (await l1_5AllHabits(rig.database)).where((h) => h.id == linked.id),
      isEmpty,
    );
  });

  test('D4 identity: the created Task is the deterministic migrated id',
      () async {
    await seedLinked();
    expect(
      linked.taskId,
      HabitTaskIdentity.taskIdForHabit(linked.id),
    );
  });
}