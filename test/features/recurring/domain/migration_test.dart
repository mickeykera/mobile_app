import 'package:ascend/core/errors/failures.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/habits/domain/entities/habit_completion.dart';
import 'package:ascend/features/habits/presentation/controllers/habit_controller.dart';
import '../../habits/presentation/habit_controller_test.dart'
    show FakeHabitRepository;
import 'package:ascend/features/recurring/domain/migration.dart';
import 'package:ascend/features/recurring/domain/streak_parity.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';
import 'package:ascend/features/tasks/presentation/controllers/task_controller.dart';
import '../../tasks/presentation/task_controller_test.dart'
    show FakeTaskRepository;
import 'package:flutter_test/flutter_test.dart';

/// A FakeHabitRepository that can simulate write failures for testing dual-write
/// recovery scenarios.
class _FailingHabitRepository extends FakeHabitRepository {
  _FailingHabitRepository({super.habits, super.completions});

  bool _failNextTaskWrite = false;

  void setFailNextTaskWrite(bool value) => _failNextTaskWrite = value;

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
    if (_failNextTaskWrite) {
      _failNextTaskWrite = false;
      return Either.left(CacheFailure('Simulated task write failure'));
    }
    return super.recordRecurringTaskOccurrence(
      taskId: taskId,
      date: date,
      count: count,
      duration: duration,
      note: note,
      moodRating: moodRating,
      energyRating: energyRating,
    );
  }

  @override
  Future<Result<void>> deleteRecurringTaskOccurrence({
    required String taskId,
    required DateTime date,
  }) async {
    if (_failNextTaskWrite) {
      _failNextTaskWrite = false;
      return Either.left(CacheFailure('Simulated task delete failure'));
    }
    return super.deleteRecurringTaskOccurrence(taskId: taskId, date: date);
  }
}

void main() {
  group('MigrationService', () {
    late FakeHabitRepository habitRepository;
    late FakeTaskRepository taskRepository;
    late MigrationService migrationService;

    setUp(() {
      habitRepository = FakeHabitRepository();
      taskRepository = FakeTaskRepository();
      migrationService = MigrationService(habitRepository, taskRepository);
    });

    group('runParityGate', () {
      test('eligible when habit has perfect parity', () async {
        // Create a habit with completions that match its stored counters
        final habit = Habit.create(
          title: 'Read',
          category: 'Health',
        ).copyWithCompletion(completed: true, completionTime: AppClock.now());

        final completion = HabitCompletion.create(
          habitId: habit.id,
          count: 1,
        );

        await habitRepository.createHabit(habit);
        await habitRepository.createCompletion(completion);

        final report = await migrationService.runParityGate();

        expect(report.eligible, contains(habit.id));
        expect(report.quarantined, isEmpty);
      });

      test('quarantines habit with counterAheadOfLog', () async {
        final habit = Habit.create(
          title: 'Read',
          category: 'Health',
        ).copyWith(
          currentStreak: 5,
          longestStreak: 5,
          totalCompletions: 5,
        );

        // No completions in the log
        await habitRepository.createHabit(habit);

        final report = await migrationService.runParityGate();

        expect(report.eligible, isEmpty);
        expect(report.quarantined, hasLength(1));
        expect(report.quarantined.first.habitId, habit.id);
        expect(
            report.quarantined.first.verdict, ParityVerdict.counterAheadOfLog);
      });

      test('quarantines habit with logAheadOfCounter', () async {
        final habit = Habit.create(
          title: 'Read',
          category: 'Health',
        );

        // Log has completions but habit counters are zero
        final completion = HabitCompletion.create(habitId: habit.id);

        await habitRepository.createHabit(habit);
        await habitRepository.createCompletion(completion);

        final report = await migrationService.runParityGate();

        expect(report.eligible, isEmpty);
        expect(report.quarantined, hasLength(1));
        expect(
            report.quarantined.first.verdict, ParityVerdict.logAheadOfCounter);
      });
    });

    group('copyEligibleToTasks', () {
      test('creates Task and copies completions for eligible habit', () async {
        final habit = Habit.create(
          title: 'Read',
          category: 'Health',
          frequency: 'Daily',
          projectId: 'proj_1',
          goalId: 'goal_1',
        );

        final completion = HabitCompletion.create(habitId: habit.id);

        await habitRepository.createHabit(habit);
        await habitRepository.createCompletion(completion);

        final count = await migrationService.copyEligibleToTasks([habit.id]);

        expect(count, 1);

        // Verify Task was created
        final tasksResult = await taskRepository.getAllTasks();
        final tasks = tasksResult.getOrElse((_) => const <Task>[]);
        expect(tasks, hasLength(1));
        final task = tasks.first;
        expect(task.title, 'Read');
        expect(task.projectId, 'proj_1');
        expect(task.goalId, 'goal_1');
        expect(task.schedule, isA<Recurring>());

        // Verify completion was copied
        final allCompletions = await habitRepository.getAllCompletions();
        final taskCompletions = allCompletions
            .getOrElse((_) => const <HabitCompletion>[])
            .where((c) => c.itemId == task.id && c.itemType == 'task')
            .toList();
        expect(taskCompletions, hasLength(1));

        // Verify Habit was updated with taskId
        final updatedHabit = await habitRepository.getHabitById(habit.id);
        expect(updatedHabit.getOrNull()?.taskId, task.id);
      });

      test('recovers a dangling taskId instead of trusting it', () async {
        // A `taskId` pointing at a Task that no longer exists is the case the
        // Stage L audit called out: the old implementation skipped on
        // `taskId != null` without looking the Task up, so a deleted Task left
        // the habit permanently un-migratable. Stage L0 resolves the link, so
        // this now migrates and the assertion is the opposite of what it was.
        final habit = Habit.create(
          title: 'Read',
          category: 'Health',
          taskId: 'task_that_no_longer_exists',
        );

        await habitRepository.createHabit(habit);

        final count = await migrationService.copyEligibleToTasks([habit.id]);

        expect(count, 1);

        final tasks = (await taskRepository.getAllTasks())
            .getOrElse((_) => const <Task>[]);
        expect(tasks, hasLength(1));

        // The link is rewritten to the live Task, not left dangling.
        final updated =
            (await habitRepository.getHabitById(habit.id)).getOrNull();
        expect(updated?.taskId, tasks.single.id);
        expect(updated?.taskId, isNot('task_that_no_longer_exists'));
      });

      test('copies multiple completions with correct counts', () async {
        final habit = Habit.create(
          title: 'Read',
          category: 'Health',
        );

        final c1 = HabitCompletion.create(habitId: habit.id, count: 2);
        final c2 = HabitCompletion.create(habitId: habit.id, count: 1);

        await habitRepository.createHabit(habit);
        await habitRepository.createCompletion(c1);
        await habitRepository.createCompletion(c2);

        await migrationService.copyEligibleToTasks([habit.id]);

        final allCompletions = await habitRepository.getAllCompletions();
        final taskCompletions = allCompletions
            .getOrElse((_) => const <HabitCompletion>[])
            .where((c) => c.itemType == 'task')
            .toList();

        expect(taskCompletions, hasLength(2));
        expect(taskCompletions.map((c) => c.count), [2, 1]);
      });
    });

    group('runFullMigration', () {
      test('runs parity gate and copies eligible habits', () async {
        // Habit with perfect parity - should be migrated
        // Create habit, then complete it through the write path so counters match log
        var goodHabit = Habit.create(title: 'Good', category: 'Health');
        await habitRepository.createHabit(goodHabit);
        // Complete through repository so counters stay in sync
        final goodCompletion = HabitCompletion.create(habitId: goodHabit.id);
        await habitRepository.createCompletion(goodCompletion);
        goodHabit = goodHabit.copyWithCompletion(
            completed: true, completionTime: goodCompletion.completedAt);
        await habitRepository.updateHabit(goodHabit);

        // Habit with divergent parity - should be quarantined
        final badHabit = Habit.create(title: 'Bad', category: 'Health')
            .copyWith(currentStreak: 5, longestStreak: 5, totalCompletions: 5);
        await habitRepository.createHabit(badHabit);

        final result = await migrationService.runFullMigration();

        expect(result.report.eligible, contains(goodHabit.id));
        expect(result.report.quarantined, hasLength(1));
        expect(result.report.quarantined.first.habitId, badHabit.id);
        expect(result.migratedCount, 1);
      });
    });
  });

  group('Migration parity — additional guarantees', () {
    late FakeHabitRepository habitRepository;
    late FakeTaskRepository taskRepository;
    late MigrationService migrationService;

    setUp(() {
      habitRepository = FakeHabitRepository();
      taskRepository = FakeTaskRepository();
      migrationService = MigrationService(habitRepository, taskRepository);
    });

    test('runParityGate quarantines chainDisagrees verdict', () async {
      // Chain disagrees: totals match but currentStreak doesn't
      // Stored: currentStreak=4, totalCompletions=4
      // Logged: 4 completions on days 20,19,17,16 (gap on 18) -> loggedCurrent=2, loggedTotal=4
      // So chainMatches=false (4 != 2), totals match (4==4) -> chainDisagrees
      final habit = Habit.create(title: 'Read', category: 'Health')
          .copyWith(currentStreak: 4, longestStreak: 4, totalCompletions: 4);
      // Two separate 2-day runs: days 20,19 and 17,16 (gap on 18)
      final completions = [
        HabitCompletion.create(habitId: habit.id)
            .copyWith(completedAt: DateTime(2026, 3, 20, 12)),
        HabitCompletion.create(habitId: habit.id)
            .copyWith(completedAt: DateTime(2026, 3, 19, 12)),
        HabitCompletion.create(habitId: habit.id)
            .copyWith(completedAt: DateTime(2026, 3, 17, 12)),
        HabitCompletion.create(habitId: habit.id)
            .copyWith(completedAt: DateTime(2026, 3, 16, 12)),
      ];
      await habitRepository.createHabit(habit);
      for (final c in completions) {
        await habitRepository.createCompletion(c);
      }

      final report = await migrationService.runParityGate();

      expect(report.eligible, isEmpty);
      expect(report.quarantined, hasLength(1));
      expect(report.quarantined.first.verdict, ParityVerdict.chainDisagrees);
    });

    test('runParityGate produces deterministic report with reason', () async {
      final habit = Habit.create(title: 'Read', category: 'Health')
          .copyWith(currentStreak: 9, longestStreak: 9, totalCompletions: 9);
      await habitRepository.createHabit(habit);

      final report = await migrationService.runParityGate();

      expect(report.quarantined, hasLength(1));
      expect(report.quarantined.first.habitId, habit.id);
      expect(report.quarantined.first.reason, 'counterAheadOfLog');
    });

    test('runFullMigration quarantines divergent habits without migration',
        () async {
      // Divergent habit should NOT be migrated even when runFullMigration is called
      final badHabit = Habit.create(title: 'Bad', category: 'Health')
          .copyWith(currentStreak: 5, longestStreak: 5, totalCompletions: 5);
      await habitRepository.createHabit(badHabit);

      final result = await migrationService.runFullMigration();

      expect(result.report.quarantined, hasLength(1));
      expect(result.report.quarantined.first.habitId, badHabit.id);
      expect(result.migratedCount, 0);

      // Verify no Task was created for the quarantined habit
      final tasksResult = await taskRepository.getAllTasks();
      expect(tasksResult.getOrElse((_) => const <Task>[]), isEmpty);
    });

    test('runFullMigration is deterministic — second run produces same report',
        () async {
      var goodHabit = Habit.create(title: 'Good', category: 'Health');
      await habitRepository.createHabit(goodHabit);
      final goodCompletion = HabitCompletion.create(habitId: goodHabit.id);
      await habitRepository.createCompletion(goodCompletion);
      goodHabit = goodHabit.copyWithCompletion(
          completed: true, completionTime: goodCompletion.completedAt);
      await habitRepository.updateHabit(goodHabit);

      final r1 = await migrationService.runFullMigration();
      final r2 = await migrationService.runFullMigration();

      expect(r1.report.eligible, r2.report.eligible);
      expect(r1.report.quarantined.map((q) => q.habitId),
          r2.report.quarantined.map((q) => q.habitId));
      // Second run migrates 0 (already migrated) — idempotent
      expect(r2.migratedCount, 0);
    });

    test(
        'copyEligibleToTasks is idempotent — running twice produces same result',
        () async {
      final habit = Habit.create(title: 'Read', category: 'Health');
      final completion = HabitCompletion.create(habitId: habit.id);
      await habitRepository.createHabit(habit);
      await habitRepository.createCompletion(completion);

      await migrationService.copyEligibleToTasks([habit.id]);
      final count2 = await migrationService.copyEligibleToTasks([habit.id]);

      expect(count2, 0); // Second run migrates 0 (already migrated)

      // Verify only one Task exists
      final tasksResult = await taskRepository.getAllTasks();
      expect(tasksResult.getOrElse((_) => const <Task>[]), hasLength(1));

      // Verify only one set of Task completions exists
      final allCompletions = await habitRepository.getAllCompletions();
      final taskCompletions = allCompletions
          .getOrElse((_) => const <HabitCompletion>[])
          .where((c) => c.itemType == 'task')
          .toList();
      expect(taskCompletions, hasLength(1));
    });

    test('migration report is deterministic — same order for same input',
        () async {
      final h1 = Habit.create(title: 'A', category: 'Health');
      final h2 = Habit.create(title: 'B', category: 'Health');
      await habitRepository.createHabit(h1);
      await habitRepository.createHabit(h2);
      await habitRepository
          .createCompletion(HabitCompletion.create(habitId: h1.id));
      await habitRepository
          .createCompletion(HabitCompletion.create(habitId: h2.id));
      await habitRepository.updateHabit(h1.copyWithCompletion(
          completed: true, completionTime: AppClock.now()));
      await habitRepository.updateHabit(h2.copyWithCompletion(
          completed: true, completionTime: AppClock.now()));

      final r1 = await migrationService.runParityGate();
      final r2 = await migrationService.runParityGate();

      expect(r1.eligible, r2.eligible);
      expect(r1.quarantined.map((q) => q.habitId),
          r2.quarantined.map((q) => q.habitId));
    });
  });

  group('Migration completeness — copy verifies Task integrity', () {
    late FakeHabitRepository habitRepository;
    late FakeTaskRepository taskRepository;
    late MigrationService migrationService;

    setUp(() {
      habitRepository = FakeHabitRepository();
      taskRepository = FakeTaskRepository();
      migrationService = MigrationService(habitRepository, taskRepository);
    });

    test('copyEligibleToTasks validates Task.schedule == Recurring', () async {
      final habit = Habit.create(
        title: 'Read',
        category: 'Health',
        frequency: 'Daily',
        projectId: 'proj_1',
        goalId: 'goal_1',
      );
      final completion = HabitCompletion.create(habitId: habit.id);

      await habitRepository.createHabit(habit);
      await habitRepository.createCompletion(completion);

      await migrationService.copyEligibleToTasks([habit.id]);

      final tasksResult = await taskRepository.getAllTasks();
      final tasks = tasksResult.getOrElse((_) => const <Task>[]);
      expect(tasks, hasLength(1));
      final task = tasks.first;

      // Verify schedule is Recurring (not Once/Unscheduled)
      expect(task.schedule, isA<Recurring>());

      // Verify recurrence rule matches habit's frequency
      final recurring = task.schedule as Recurring;
      expect(recurring.rule, isA<DailyRecurrence>());
    });

    test('copyEligibleToTasks preserves projectId, goalId, category', () async {
      final habit = Habit.create(
        title: 'Read',
        category: 'Health',
        frequency: 'Weekdays',
        projectId: 'proj_xyz',
        goalId: 'goal_abc',
      );
      await habitRepository.createHabit(habit);

      await migrationService.copyEligibleToTasks([habit.id]);

      final tasksResult = await taskRepository.getAllTasks();
      final task = tasksResult.getOrElse((_) => const <Task>[]).single;
      expect(task.projectId, 'proj_xyz');
      expect(task.goalId, 'goal_abc');
      expect(task.category, 'Health');
    });

    test('copyEligibleToTasks preserves createdAt, updatedAt set to now',
        () async {
      final oldDate = DateTime(2024, 1, 1);
      final habit = Habit.create(
        title: 'Read',
        category: 'Health',
      ).copyWith(createdAt: oldDate, updatedAt: oldDate);
      await habitRepository.createHabit(habit);

      await migrationService.copyEligibleToTasks([habit.id]);

      final tasksResult = await taskRepository.getAllTasks();
      final task = tasksResult.getOrElse((_) => const <Task>[]).single;
      expect(task.createdAt, oldDate);
      // updatedAt should be recent (AppClock.now())
      expect(task.updatedAt, isNot(oldDate));
    });

    test(
        'copyEligibleToTasks sets Task status = todo (recurring tasks never use done)',
        () async {
      final habit = Habit.create(title: 'Read', category: 'Health');
      await habitRepository.createHabit(habit);

      await migrationService.copyEligibleToTasks([habit.id]);

      final tasksResult = await taskRepository.getAllTasks();
      final task = tasksResult.getOrElse((_) => const <Task>[]).single;
      expect(task.status, TaskStatus.todo);
      expect(task.completedAt, isNull);
    });

    test(
        'copyEligibleToTasks copies all completions with exact same completedAt',
        () async {
      final habit = Habit.create(title: 'Read', category: 'Health');
      final c1 = HabitCompletion.create(
        habitId: habit.id,
        count: 1,
      ).copyWith(completedAt: DateTime(2026, 3, 15, 9, 30));
      final c2 = HabitCompletion.create(
        habitId: habit.id,
        count: 2,
      ).copyWith(completedAt: DateTime(2026, 3, 16, 8, 0));

      await habitRepository.createHabit(habit);
      await habitRepository.createCompletion(c1);
      await habitRepository.createCompletion(c2);

      await migrationService.copyEligibleToTasks([habit.id]);

      final allCompletions = await habitRepository.getAllCompletions();
      final taskCompletions = allCompletions
          .getOrElse((_) => const <HabitCompletion>[])
          .where((c) => c.itemType == 'task')
          .toList();

      expect(taskCompletions, hasLength(2));
      // Verify exact timestamps preserved
      final dates = taskCompletions.map((c) => c.completedAt).toSet();
      expect(dates, contains(DateTime(2026, 3, 15, 9, 30)));
      expect(dates, contains(DateTime(2026, 3, 16, 8, 0)));
      // Verify count preserved
      expect(taskCompletions.map((c) => c.count).toSet(), {1, 2});
    });
  });

  group('HabitController dual-write', () {
    late FakeHabitRepository habitRepository;
    late HabitController controller;

    setUp(() async {
      habitRepository = FakeHabitRepository();
      controller = HabitController(habitRepository);
      await Future<void>.delayed(Duration.zero); // Wait for initial load
    });

    test('completeHabit dual-writes to Task when habit has taskId', () async {
      final habit = Habit.create(
        title: 'Read',
        category: 'Health',
        taskId: 'task_123',
      );
      await habitRepository.createHabit(habit);
      await controller.refresh();

      final result = await controller.completeHabit(habit.id);

      expect(result.isRight, isTrue);

      // Verify Task occurrence was recorded
      final completions = await habitRepository.getAllCompletions();
      final taskCompletions = completions
          .getOrElse((_) => const <HabitCompletion>[])
          .where((c) => c.itemId == 'task_123' && c.itemType == 'task')
          .toList();
      expect(taskCompletions, hasLength(1));
    });

    test('uncompleteHabit dual-deletes from Task when habit has taskId',
        () async {
      final habit = Habit.create(
        title: 'Read',
        category: 'Health',
        taskId: 'task_123',
      );
      await habitRepository.createHabit(habit);

      // First complete
      final completion = HabitCompletion.create(
        habitId: habit.id,
        itemId: 'task_123',
        itemType: 'task',
      );
      await habitRepository.createCompletion(completion);

      await controller.refresh();

      // Now uncomplete
      await controller.uncompleteHabit(habit.id);

      // Verify Task occurrence was deleted
      final completions = await habitRepository.getAllCompletions();
      final taskCompletions = completions
          .getOrElse((_) => const <HabitCompletion>[])
          .where((c) => c.itemId == 'task_123' && c.itemType == 'task')
          .toList();
      expect(taskCompletions, isEmpty);
    });

    test('no dual-write when habit has no taskId', () async {
      final habit = Habit.create(title: 'Read', category: 'Health');
      await habitRepository.createHabit(habit);
      await controller.refresh();

      await controller.completeHabit(habit.id);

      // No Task occurrence should be created
      final completions = await habitRepository.getAllCompletions();
      final taskCompletions = completions
          .getOrElse((_) => const <HabitCompletion>[])
          .where((c) => c.itemType == 'task')
          .toList();
      expect(taskCompletions, isEmpty);
    });
  });

  group('TaskController recordOccurrence', () {
    late FakeTaskRepository taskRepository;
    late FakeHabitRepository habitRepository;
    late TaskController controller;

    setUp(() async {
      taskRepository = FakeTaskRepository();
      habitRepository = FakeHabitRepository();
      controller = TaskController(taskRepository, habitRepository);
      await Future<void>.delayed(Duration.zero);
    });

    test('records occurrence for recurring task', () async {
      final task = Task.create(
        title: 'Water plants',
        schedule: const Recurring(DailyRecurrence()),
      );
      await taskRepository.createTask(task);
      await controller.refresh();

      final result =
          await controller.recordOccurrence(task.id, date: AppClock.now());

      expect(result.isRight, isTrue);

      // Verify HabitCompletion was created with itemType 'task'
      final completions = await habitRepository.getAllCompletions();
      final taskCompletions = completions
          .getOrElse((_) => const <HabitCompletion>[])
          .where((c) => c.itemId == task.id && c.itemType == 'task')
          .toList();
      expect(taskCompletions, hasLength(1));
    });

    test('rejects occurrence for non-recurring task', () async {
      final task = Task.create(title: 'One-off task');
      await taskRepository.createTask(task);
      await controller.refresh();

      final result =
          await controller.recordOccurrence(task.id, date: AppClock.now());

      expect(result.isLeft, isTrue);
      expect(result.left, isA<ValidationFailure>());
    });

    test('idempotent: same-day double call returns existing row', () async {
      final task = Task.create(
        title: 'Water plants',
        schedule: const Recurring(DailyRecurrence()),
      );
      await taskRepository.createTask(task);
      await controller.refresh();

      final result1 =
          await controller.recordOccurrence(task.id, date: AppClock.now());
      final result2 =
          await controller.recordOccurrence(task.id, date: AppClock.now());

      expect(result1.isRight, isTrue);
      expect(result2.isRight, isTrue);
      expect(result1.right!.id, result2.right!.id);

      // Only one row should exist
      final completions = await habitRepository.getAllCompletions();
      final taskCompletions = completions
          .getOrElse((_) => const <HabitCompletion>[])
          .where((c) => c.itemId == task.id && c.itemType == 'task')
          .toList();
      expect(taskCompletions, hasLength(1));
    });

    test('deleteOccurrence removes the occurrence', () async {
      final task = Task.create(
        title: 'Water plants',
        schedule: const Recurring(DailyRecurrence()),
      );
      await taskRepository.createTask(task);
      await controller.refresh();

      await controller.recordOccurrence(task.id, date: AppClock.now());

      await controller.deleteOccurrence(task.id, date: AppClock.now());

      final completions = await habitRepository.getAllCompletions();
      final taskCompletions = completions
          .getOrElse((_) => const <HabitCompletion>[])
          .where((c) => c.itemId == task.id && c.itemType == 'task')
          .toList();
      expect(taskCompletions, isEmpty);
    });

    test('rejects delete for non-recurring task', () async {
      final task = Task.create(title: 'One-off task');
      await taskRepository.createTask(task);
      await controller.refresh();

      final result =
          await controller.deleteOccurrence(task.id, date: AppClock.now());

      expect(result.isLeft, isTrue);
      expect(result.left, isA<ValidationFailure>());
    });
  });

  group('HabitRepository reconcileHabitToTask', () {
    late FakeHabitRepository habitRepository;
    late FakeTaskRepository taskRepository;

    setUp(() {
      habitRepository = FakeHabitRepository();
      taskRepository = FakeTaskRepository();
    });

    test('creates missing Task occurrences from Habit history', () async {
      final habit = Habit.create(title: 'Read', category: 'Health');
      await habitRepository.createHabit(habit);

      final c1 = HabitCompletion.create(habitId: habit.id);
      final c2 = HabitCompletion.create(habitId: habit.id);
      await habitRepository.createCompletion(c1);
      await habitRepository.createCompletion(c2);

      final task = Task.create(
          title: 'Read', schedule: const Recurring(DailyRecurrence()));
      await taskRepository.createTask(task);

      await habitRepository.reconcileHabitToTask(
          habitId: habit.id, taskId: task.id);

      final allCompletions = await habitRepository.getAllCompletions();
      final taskCompletions = allCompletions
          .getOrElse((_) => const <HabitCompletion>[])
          .where((c) => c.itemId == task.id && c.itemType == 'task')
          .toList();

      expect(taskCompletions, hasLength(2));
    });

    test('removes orphaned Task occurrences (no corresponding Habit row)',
        () async {
      final habit = Habit.create(title: 'Read', category: 'Health');
      await habitRepository.createHabit(habit);

      // Task has an extra occurrence that Habit doesn't have
      final taskCompletion = HabitCompletion.create(
        habitId: null,
        itemId: 'task_123',
        itemType: 'task',
      );
      await habitRepository.createCompletion(taskCompletion);

      await habitRepository.reconcileHabitToTask(
          habitId: habit.id, taskId: 'task_123');

      final allCompletions = await habitRepository.getAllCompletions();
      final taskCompletions = allCompletions
          .getOrElse((_) => const <HabitCompletion>[])
          .where((c) => c.itemId == 'task_123' && c.itemType == 'task')
          .toList();

      expect(taskCompletions, isEmpty);
    });

    test('idempotent: running twice converges to same state', () async {
      final habit = Habit.create(title: 'Read', category: 'Health');
      await habitRepository.createHabit(habit);

      final c1 = HabitCompletion.create(habitId: habit.id);
      await habitRepository.createCompletion(c1);

      final task = Task.create(
          title: 'Read', schedule: const Recurring(DailyRecurrence()));
      await taskRepository.createTask(task);

      await habitRepository.reconcileHabitToTask(
          habitId: habit.id, taskId: task.id);
      await habitRepository.reconcileHabitToTask(
          habitId: habit.id, taskId: task.id);

      final allCompletions = await habitRepository.getAllCompletions();
      final taskCompletions = allCompletions
          .getOrElse((_) => const <HabitCompletion>[])
          .where((c) => c.itemId == task.id && c.itemType == 'task')
          .toList();

      expect(taskCompletions, hasLength(1));
    });
  });
}
