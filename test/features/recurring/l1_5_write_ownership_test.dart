import 'package:ascend/core/database/database.dart';
import 'package:ascend/core/errors/failures.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/habits/data/repositories/habit_repository_impl.dart';
import 'package:ascend/features/habits/domain/entities/habit_completion.dart';
import 'package:ascend/features/habits/presentation/controllers/habit_controller.dart';
import 'package:ascend/features/recurring/domain/cutover_readiness.dart';
import 'package:ascend/features/recurring/domain/habit_task_identity.dart';
import 'package:ascend/features/recurring/domain/migration.dart';
import 'package:ascend/features/recurring/domain/migration_runner.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';
import 'package:flutter_test/flutter_test.dart';

import 'l1_5_shared.dart';

/// Stage L1.5, steps 3, 10 look like a failure story; this is the evidence.
///
/// The cutover contract's ownership table says a migrated habit's *write path*
/// is Task-only through [HabitController]. These tests take that claim apart
/// with the real controller and real repositories:
///
///  * completing / un-completing a migrated habit writes to the Task occurrence
///    log and nowhere else — no Habit row, no counter move, no fallback write;
///  * a failed Task write propagates the failure instead of silently degrading
///    onto the Habit path (the atomicity the cutover is betting on);
///  * findings D1–D4 are reproduced against persisted data so the contract's
///    divergence list is real, observed behaviour rather than a survey opinion.
void main() {
  l1_5EnsureBinding();

  final now = DateTime(2025, 6, 11, 9);

  late DatabaseService database;

  setUp(() async {
    AppClock.debugSetNow(() => now);
    // L1.5 documents the legacy regime's observed behaviour, so it pins the
    // gate closed. Stage L2's `l2_*_test.dart` proves the routed behaviour with
    // the gate open; this file must not silently become an L2 test.
    CutoverGate.enabled = false;
    database = await l1_5FreshDatabase();
  });

  tearDown(() {
    AppClock.debugResetNow();
  });

  Task recurringTask() =>
      Task.create(title: 'Reading', schedule: const Recurring(DailyRecurrence()));

  group('single-writer guarantees through the real controller', () {
    test('completeHabit on a migrated habit writes Task log only', () async {
      final habit =
          await l1_5LinkedHabit(database, recurringTask, title: 'Reading');
      final taskId = habit.taskId!;

      final controller = HabitController(HabitRepositoryImpl(database));
      await Future<void>.delayed(Duration.zero);

      final result = await controller.completeHabit(habit.id);
      expect(result.isRight, isTrue);

      expect(await l1_5TaskRows(database, taskId), hasLength(1));
      expect(await l1_5HabitRows(database, habit.id), isEmpty);

      final after = await l1_5ReloadHabit(database, habit.id);
      expect(after.currentStreak, 0);
      expect(after.totalCompletions, 0);
    });

    test('uncompleteHabit on a migrated habit removes the Task row only',
        () async {
      final habit =
          await l1_5LinkedHabit(database, recurringTask, title: 'Reading');
      final taskId = habit.taskId!;

      final controller = HabitController(HabitRepositoryImpl(database));
      await Future<void>.delayed(Duration.zero);

      await controller.completeHabit(habit.id);
      expect(await l1_5TaskRows(database, taskId), hasLength(1));

      final result = await controller.uncompleteHabit(habit.id);
      expect(result.isRight, isTrue);

      expect(await l1_5TaskRows(database, taskId), isEmpty);
      expect(await l1_5HabitRows(database, habit.id), isEmpty);
      final after = await l1_5ReloadHabit(database, habit.id);
      expect(after.currentStreak, 0);
    });

    test('a failing Task write fails loudly instead of falling back to Habit',
        () async {
      final habit =
          await l1_5LinkedHabit(database, recurringTask, title: 'Reading');

      final failing = _FailingTaskWriteRepository(database);
      final controller = HabitController(failing);
      await Future<void>.delayed(Duration.zero);

      final result = await controller.completeHabit(habit.id);

      expect(result.isLeft, isTrue);
      expect(result.left, isA<CacheFailure>());
      // Total rows unchanged: the Task write failed and nothing else wrote.
      expect(await l1_5AllCompletions(database), isEmpty);
      expect(await l1_5AllHabits(database), hasLength(1));
    });
  });

  group('divergence classes D1–D4 are real, observed state', () {
    test('D1: a title edit on the migrated habit never reaches the Task',
        () async {
      final habit = await l1_5EligibleHabit(
          database, title: 'Read', completions: 0);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);
      await l1_5MigrateOne(database, habit.id);

      // The habits screen edits the Habit and nothing else.
      final edited = (await l1_5AllHabits(database)).single
          .copyWith(title: 'Read nightly');
      await HabitRepositoryImpl(database).updateHabit(edited);

final task = await l1_5ReloadTask(database, taskId);
      expect(task.title, 'Read');

      final divergences = CutoverAuditor.pairDivergences(edited, task);
      final title = divergences.where((d) => d.field == 'title').single;
      expect(title.selfHealing, isFalse);

      // The capability bridge explicitly does not cover narration fields.
      final report = await l1_5SyncCapabilities(database);
      expect(report.isClean, isTrue);
      expect((await l1_5ReloadTask(database, taskId)).title, 'Read');
    });

    test('D2: archiving the habit never archives the Task', () async {
      final habit = await l1_5EligibleHabit(database, completions: 0);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);
      await l1_5MigrateOne(database, habit.id);

      await HabitRepositoryImpl(database).archiveHabit(habit.id);

      final task = await l1_5ReloadTask(database, taskId);
      expect(task.status, TaskStatus.todo);

      final audit = CutoverAuditor.audit(
        habits: await l1_5AllHabits(database),
        tasks: await l1_5AllTasks(database),
      );
      final archived = audit.divergences.where((d) => d.field == 'archived');
      expect(archived, hasLength(1));
      expect(archived.single.selfHealing, isFalse);
    });

    test('D3: deleting the habit orphans its canonical Task and its log',
        () async {
      final habit =
          await l1_5EligibleHabit(database, completions: 2);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);
      await l1_5MigrateOne(database, habit.id);
      expect(await l1_5TaskRows(database, taskId), hasLength(2));

      await HabitRepositoryImpl(database).deleteHabit(habit.id);

      // The Task and its occurrence log survive without a claiming habit.
      expect(await l1_5ReloadTask(database, taskId), isNotNull);
      expect(await l1_5TaskRows(database, taskId), hasLength(2));

      final audit = CutoverAuditor.audit(
        habits: await l1_5AllHabits(database),
        tasks: await l1_5AllTasks(database),
      );
      expect(audit.orphanedMigratedTaskIds, contains(taskId));
    });

    test('D4: a habit created after the marker is never migrated', () async {
      final first = await l1_5EligibleHabit(database, completions: 0);
      final runner = HabitTaskMigrationRunner(
        migration:
            MigrationService(l1_5Repos(database).$1, l1_5Repos(database).$2),
        database: database,
      );
      final ran = await runner.runIfRequired();
      expect(ran.ran, isTrue);
      expect((await l1_5ReloadHabit(database, first.id)).taskId, isNotNull);

      // A habit created after the marker - e.g. in this same session.
      final second = await l1_5EligibleHabit(
          database, title: 'Later habit', completions: 0);
      final rerun =
          await HabitTaskMigrationRunner(
        migration:
            MigrationService(l1_5Repos(database).$1, l1_5Repos(database).$2),
        database: database,
      ).runIfRequired();
      expect(rerun.ran, isFalse);

      expect((await l1_5ReloadHabit(database, second.id)).taskId, isNull);

      final audit = CutoverAuditor.audit(
        habits: await l1_5AllHabits(database),
        tasks: await l1_5AllTasks(database),
      );
      expect(audit.unlinkedHabits, 1);
    });
  });
}

/// The real repository with the Task-write seam injected to fail on demand, so
/// the controller's failure handling can be observed without a partial write.
class _FailingTaskWriteRepository extends HabitRepositoryImpl {
  _FailingTaskWriteRepository(super.database);

  @override
  Future<Result<HabitCompletion>> recordRecurringTaskOccurrence({
    required String taskId,
    required DateTime date,
    required int count,
    Duration? duration,
    String? note,
    int? moodRating,
    int? energyRating,
  }) async {
    return Either.left(const CacheFailure('Simulated task write failure'));
  }
}