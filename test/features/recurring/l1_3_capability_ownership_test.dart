import 'package:ascend/core/constants/app_constants.dart';
import 'package:ascend/core/database/database.dart';
import 'package:ascend/core/errors/failures.dart';
import 'package:ascend/core/extensions/date_extensions.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/habits/data/repositories/habit_repository_impl.dart';
import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/habits/domain/entities/habit_completion.dart';
import 'package:ascend/features/recurring/domain/habit_task_identity.dart';
import 'package:ascend/features/recurring/domain/migration.dart';
import 'package:ascend/features/recurring/domain/migration_runner.dart';
import 'package:ascend/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/streak_freeze_usage.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stage L1.3 tests: the five legacy capabilities get a canonical home on
/// `Task`, migration copies them there, and the capability bridge keeps that
/// copy in step with the legacy writer.
///
/// Like the L0 suite these run against the **real** repositories over mocked
/// SharedPreferences, because the whole question is what survives persistence:
/// an in-memory fake keeps fields alive on the object it holds, which hides
/// exactly the "moved the field, dropped the serialised value" failure this
/// stage exists to rule out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService database;

  (HabitRepositoryImpl, TaskRepositoryImpl) repos() => (
        HabitRepositoryImpl(database),
        TaskRepositoryImpl(database),
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = DatabaseService();
    await database.close();
    await database.initialize();
  });

  /// A habit whose stored counters agree with its log (the parity gate admits
  /// it) and carrying customisable capabilities.
  Future<Habit> eligibleHabit({
    String title = 'Read',
    String category = 'Mind',
    int completions = 1,
    bool archived = false,
    String frequency = 'Daily',
    List<int> customWeekdays = const [],
    int targetCount = 1,
    int targetDurationMinutes = 0,
    String cue = '',
    String timeOfDay = 'Morning',
    int streakFreezesUsed = 0,
    DateTime? dueAt,
    DateTime? snoozedUntil,
  }) async {
    final habit = Habit.create(
      title: title,
      category: category,
      frequency: frequency,
      customWeekdays: customWeekdays,
      targetCount: targetCount,
      targetDuration: Duration(minutes: targetDurationMinutes),
      cue: cue,
      timeOfDay: timeOfDay,
    ).copyWith(
      streakFreezesUsed: streakFreezesUsed,
      dueAt: dueAt,
      snoozedUntil: snoozedUntil,
    );
    final stored = archived ? habit.copyWith(isArchived: true) : habit;

    final today = AppClock.now().startOfDay;
    final days = [
      for (var i = completions - 1; i >= 0; i--)
        today.subtract(Duration(days: i)).add(const Duration(hours: 9)),
    ];

    var withCounters = stored;
    for (final day in days) {
      withCounters = withCounters.copyWithCompletion(
        completed: true,
        completionTime: day,
      );
    }

    final habitRepo = HabitRepositoryImpl(database);
    await habitRepo.createHabit(withCounters);
    for (final day in days) {
      await habitRepo.createCompletion(HabitCompletion(
        id: 'completion_seed_${withCounters.id}_${day.toIso8601String()}',
        habitId: withCounters.id,
        itemId: withCounters.id,
        itemType: 'habit',
        completedAt: day,
        count: 1,
      ));
    }
    return withCounters;
  }

  List<Map<String, dynamic>> persistedTasks() =>
      database.getJsonList(DatabaseService.tasksKey) ?? const [];

  Map<String, dynamic> persistedTask(String id) =>
      persistedTasks().firstWhere((t) => t['id'] == id);

  /// Simulates a Task written by the Stage L0 build: created under the
  /// deterministic migrated id with no capability keys at all.
  Future<void> seedL0Task(String taskId, Habit habit) async {
    final repo = TaskRepositoryImpl(database);
    await repo.createTask(
      Task.create(
        title: habit.title,
        category: habit.category,
        schedule: habit.recurringSchedule,
      ).copyWith(id: taskId, createdAt: habit.createdAt),
    );
    final stripped = database.getJsonList(DatabaseService.tasksKey)!;
    for (final task in stripped) {
      if (task['id'] != taskId) continue;
      task.removeWhere((k, _) =>
          k == 'targetCount' ||
          k == 'targetDurationMinutes' ||
          k == 'cue' ||
          k == 'timeOfDay' ||
          k == 'streakFreezesUsed');
    }
    await database.setJsonList(DatabaseService.tasksKey, stripped);
  }

  Future<Habit> reloadHabit(String id) async =>
      (await HabitRepositoryImpl(database).getHabitById(id)).right!;

  Future<Task> reloadTask(String id) async =>
      (await TaskRepositoryImpl(database).getTaskById(id)).right!;

  group('1. Task owns the five capabilities', () {
    test('a fresh Task reads back with the legacy defaults', () async {
      final (_, taskRepo) = repos();
      final task = Task.create(title: 'Draft');
      await taskRepo.createTask(task);

      final reloaded =
          (await TaskRepositoryImpl(database).getAllTasks()).right!.single;
      expect(reloaded.targetCount, 1);
      expect(reloaded.targetDuration, Duration.zero);
      expect(reloaded.cue, '');
      expect(reloaded.timeOfDay, AppConstants.timeOfDayMorning);
      expect(reloaded.streakFreezeUsage.used, 0);
    });

    test('all five survive a JSON round-trip on the real repository', () async {
      final (_, taskRepo) = repos();
      final task = Task.create(title: 'Draft').copyWith(
        targetCount: 3,
        targetDuration: const Duration(minutes: 25),
        cue: 'After coffee',
        timeOfDay: 'Evening',
        streakFreezeUsage: const StreakFreezeUsage(2),
      );
      await taskRepo.createTask(task);

      final reloaded =
          (await TaskRepositoryImpl(database).getAllTasks()).right!.single;
      expect(reloaded.targetCount, 3);
      expect(reloaded.targetDuration, const Duration(minutes: 25));
      expect(reloaded.cue, 'After coffee');
      expect(reloaded.timeOfDay, 'Evening');
      expect(reloaded.streakFreezeUsage, const StreakFreezeUsage(2));
    });

    test(
        'a Task written before L1.3 (no capability keys) loads with the '
        'legacy defaults', () async {
      await database.setJsonList(DatabaseService.tasksKey, [
        {
          'id': 'task_hm_a',
          'title': 'Read',
          'createdAt': '2025-06-11T09:00:00.000',
          'updatedAt': '2025-06-11T09:00:00.000',
          'sortOrder': 0,
          'status': 'todo',
          'schedule': {
            'kind': 'recurring',
            'frequency': 'Daily',
            'customWeekdays': <int>[],
          },
        },
      ]);

      final task =
          (await TaskRepositoryImpl(database).getAllTasks()).right!.single;
      expect(task.targetCount, 1);
      expect(task.targetDuration, Duration.zero);
      expect(task.cue, '');
      expect(task.timeOfDay, AppConstants.timeOfDayMorning);
      expect(task.streakFreezeUsage, const StreakFreezeUsage());
    });

    test('a completely old habit record loads instead of throwing', () async {
      // The schema migrations never rewrite habit records, so a record written
      // by a build that predates the capability keys is still in the wild. It
      // must read as defaults, not crash, so the migration can carry it.
      await database.setJsonList(DatabaseService.habitsKey, [
        {
          'id': 'habit_old',
          'title': 'Ancient',
          'description': '',
          'category': 'Mind',
          'frequency': 'Daily',
          'customWeekdays': <int>[],
          'createdAt': '2024-01-01T09:00:00.000',
          'updatedAt': '2024-01-01T09:00:00.000',
          'sortOrder': 0,
          'isArchived': false,
          'currentStreak': 0,
          'longestStreak': 0,
          'totalCompletions': 0,
        },
      ]);

      final habit =
          (await HabitRepositoryImpl(database).getAllHabits()).right!.single;
      expect(habit.targetCount, 1);
      expect(habit.targetDuration, Duration.zero);
      expect(habit.cue, '');
      expect(habit.timeOfDay, AppConstants.timeOfDayMorning);
      expect(habit.streakFreezesUsed, 0);
    });
  });

  group('2. LegacyHabitCapabilities reads both representations', () {
    test('applyTo round-trips: fromTask equals fromHabit', () async {
      final habit = Habit.create(
        title: 'Read',
        category: 'Mind',
        targetCount: 3,
        targetDuration: const Duration(minutes: 25),
        cue: 'After coffee',
        timeOfDay: 'Evening',
      ).copyWith(streakFreezesUsed: 2);
      final task = Task.create(title: 'Read');

      final expected = LegacyHabitCapabilities.fromHabit(habit);
      final applied = expected.applyTo(task);
      expect(expected.matchesTask(applied), isTrue);
      expect(LegacyHabitCapabilities.fromTask(applied), expected);
    });

    test('applyTo touches only the five capability fields', () async {
      final schedule = Recurring(RecurrenceRule.fromFrequency('Daily', []));
      final task = Task.create(
        title: 'Read',
        projectId: 'p1',
        goalId: 'g1',
        category: 'Mind',
        schedule: schedule,
      );
      final withCapabilities = LegacyHabitCapabilities.fromHabit(
        Habit.create(
          title: 'Read',
          category: 'Mind',
          targetCount: 3,
          timeOfDay: 'Evening',
        ),
      ).applyTo(task);

      expect(withCapabilities.title, task.title);
      expect(withCapabilities.description, task.description);
      expect(withCapabilities.projectId, 'p1');
      expect(withCapabilities.goalId, 'g1');
      expect(withCapabilities.schedule, schedule);
      expect(withCapabilities.status, task.status);
      expect(withCapabilities.targetCount, 3);
      expect(withCapabilities.timeOfDay, 'Evening');
    });

    test('fieldsLostFromTask names every missing capability', () async {
      const expected = LegacyHabitCapabilities(
        targetCount: 3,
        targetDuration: Duration(minutes: 25),
        cue: 'Cue',
        timeOfDay: 'Evening',
        streakFreezesUsed: 2,
      );
      final bareTask = Task.create(title: 'Read');

      expect(
        expected.fieldsLostFromTask(bareTask),
        [
          'targetCount',
          'targetDuration',
          'cue',
          'timeOfDay',
          'streakFreezesUsed'
        ],
      );
      expect(expected.matchesTask(bareTask), isFalse);

      final partial = expected
          .applyTo(bareTask)
          .copyWith(streakFreezeUsage: const StreakFreezeUsage());
      expect(expected.fieldsLostFromTask(partial), ['streakFreezesUsed']);
    });
  });

  group('3. migration writes the capabilities onto the Task', () {
    test('all five land on the canonical Task and verify', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(
        targetCount: 3,
        targetDurationMinutes: 25,
        cue: 'After coffee',
        timeOfDay: 'Evening',
        streakFreezesUsed: 2,
      );

      final outcome = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([habit.id]))
          .single;

      expect(outcome.verification.isVerified, isTrue,
          reason: outcome.verification.failures.join('; '));
      expect(outcome.verification.legacyCapabilitiesPreserved, isTrue);
      expect(outcome.verification.taskCapabilitiesPresent, isTrue);
      expect(outcome.verification.taskCapabilitiesLost, isEmpty);

      final task = await reloadTask(outcome.taskId!);
      final capabilities = LegacyHabitCapabilities.fromTask(task);
      expect(capabilities.targetCount, 3);
      expect(capabilities.targetDuration, const Duration(minutes: 25));
      expect(capabilities.cue, 'After coffee');
      expect(capabilities.timeOfDay, 'Evening');
      expect(capabilities.streakFreezesUsed, 2);
      expect(capabilities.matchesHabit(habit), isTrue);
    });

    test('a completely old habit record migrates with the legacy defaults',
        () async {
      await database.setJsonList(DatabaseService.habitsKey, [
        {
          'id': 'habit_old',
          'title': 'Ancient',
          'description': '',
          'category': 'Mind',
          'frequency': 'Daily',
          'customWeekdays': <int>[],
          'createdAt': '2024-01-01T09:00:00.000',
          'updatedAt': '2024-01-01T09:00:00.000',
          'sortOrder': 0,
          'isArchived': false,
          'currentStreak': 0,
          'longestStreak': 0,
          'totalCompletions': 0,
        },
      ]);
      final (habitRepo, taskRepo) = repos();

      final outcome = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits(['habit_old']))
          .single;

      expect(outcome.verification.isVerified, isTrue,
          reason: outcome.verification.failures.join('; '));
      final task = await reloadTask(outcome.taskId!);
      final defaults = LegacyHabitCapabilities.fromHabit(Habit.create(
        title: 'Ancient',
        category: 'Mind',
      ));
      expect(LegacyHabitCapabilities.fromTask(task), defaults);
    });

    test('re-running a migrated habit rewrites nothing', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(
          targetCount: 3, timeOfDay: 'Evening', streakFreezesUsed: 2);
      await MigrationService(habitRepo, taskRepo).migrateHabits([habit.id]);

      final tasksBefore = persistedTasks();

      final (freshHabit, freshTask) = repos();
      await MigrationService(freshHabit, freshTask).migrateHabits([habit.id]);

      expect(persistedTasks(), tasksBefore,
          reason: 'a second pass must not rewrite a converged Task');
    });

    test('a Task created by the Stage L0 build is adopted, not left blank',
        () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(
          completions: 2, targetCount: 3, timeOfDay: 'Evening');
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);
      await seedL0Task(taskId, habit);

      final outcome = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([habit.id]))
          .single;

      expect(outcome.state, MigrationState.adoptedExistingTask);
      expect(outcome.verification.isVerified, isTrue,
          reason: outcome.verification.failures.join('; '));
      final task = await reloadTask(taskId);
      expect(LegacyHabitCapabilities.fromTask(task),
          LegacyHabitCapabilities.fromHabit(habit));
    });
  });

  group('4. the capability bridge keeps already-migrated installs in step', () {
    test('backfills Tasks that predate L1.3 even with the marker set',
        () async {
      final (habitRepo, _) = repos();
      final habit = await eligibleHabit(
          targetCount: 3, timeOfDay: 'Evening', streakFreezesUsed: 2);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);

      // The habit is linked (Stage L0 finished) but its Task was written by a
      // build that carried no capability keys.
      await habitRepo.updateHabit(habit.copyWith(taskId: taskId));
      await seedL0Task(taskId, habit);

      // The L0 marker is already written: the per-habit migration will never
      // run again from the runner, so only the bridge can reach these Tasks.
      await database.setJson('habit_task_migration', {'version': 1});

      final (habitRepo2, taskRepo2) = repos();
      final runner = HabitTaskMigrationRunner(
        migration: MigrationService(habitRepo2, taskRepo2),
        database: database,
      );

      final result = await runner.runIfRequired();

      expect(result.ran, isFalse,
          reason: 'the marker short-circuits the migration itself');
      expect(runner.isComplete, isTrue);

      final taskJson = persistedTask(taskId);
      expect(taskJson['targetCount'], 3);
      expect(taskJson['timeOfDay'], 'Evening');
      expect(taskJson['streakFreezesUsed'], 2);
      expect(taskJson['targetDurationMinutes'], 0);
      expect(taskJson['cue'], '');

      final task = await reloadTask(taskId);
      expect(LegacyHabitCapabilities.fromTask(task),
          LegacyHabitCapabilities.fromHabit(habit));
    });

    test('a second launch of the bridge writes nothing once converged',
        () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(
          targetCount: 3, timeOfDay: 'Evening', streakFreezesUsed: 2);
      await MigrationService(habitRepo, taskRepo).migrateHabits([habit.id]);

      final (h2, t2) = repos();
      await HabitTaskMigrationRunner(
        migration: MigrationService(h2, t2),
        database: database,
      ).runIfRequired();
      final afterFirst = persistedTasks();

      final (h3, t3) = repos();
      await HabitTaskMigrationRunner(
        migration: MigrationService(h3, t3),
        database: database,
      ).runIfRequired();

      expect(persistedTasks(), afterFirst,
          reason: 'a converged install must stay byte-identical');
    });

    test(
        'a value edited after migration is picked up without a second '
        'mechanism', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(targetCount: 3);
      await MigrationService(habitRepo, taskRepo).migrateHabits([habit.id]);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);

      // The form still writes the Habit (the legacy write path), so editing
      // the count after migration changes only the Habit at first.
      final persisted = await reloadHabit(habit.id);
      await HabitRepositoryImpl(database)
          .updateHabit(persisted.copyWith(targetCount: 5));

      final (freshHabit, freshTask) = repos();
      final report =
          await MigrationService(freshHabit, freshTask).syncTaskCapabilities();

      expect(report.updated, 1);
      expect(report.verified, 1);
      expect(report.failed, 0);
      final task = await reloadTask(taskId);
      expect(task.targetCount, 5);
    });

    test('a partially populated Task is topped up, not reset', () async {
      final (habitRepo, _) = repos();
      final habit = await eligibleHabit(
          targetCount: 3, timeOfDay: 'Evening', streakFreezesUsed: 2);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);
      await habitRepo.updateHabit(habit.copyWith(taskId: taskId));

      // An interrupted L1.3 run left exactly one capability key written.
      final repo = TaskRepositoryImpl(database);
      await repo.createTask(
        Task.create(
          title: habit.title,
          category: habit.category,
          schedule: habit.recurringSchedule,
        ).copyWith(id: taskId, createdAt: habit.createdAt),
      );
      final stored = database
          .getJsonList(DatabaseService.tasksKey)!
          .first
          .cast<String, dynamic>();
      stored
        ..removeWhere((k, _) =>
            k == 'targetDurationMinutes' ||
            k == 'cue' ||
            k == 'timeOfDay' ||
            k == 'streakFreezesUsed')
        ..['targetCount'] = habit.targetCount;
      await database.setJsonList(DatabaseService.tasksKey, [stored]);

      final (freshHabit, freshTask) = repos();
      final report =
          await MigrationService(freshHabit, freshTask).syncTaskCapabilities();

      expect(report.updated, 1);
      expect(report.verified, 1);
      final task = await reloadTask(taskId);
      expect(LegacyHabitCapabilities.fromTask(task),
          LegacyHabitCapabilities.fromHabit(habit));
      expect(task.title, habit.title, reason: 'non-capability fields survive');
      expect(task.status, TaskStatus.todo);
    });

    test('a write that fails is reported, never silently swallowed', () async {
      final (habitRepo, _) = repos();
      final habit = await eligibleHabit(targetCount: 3);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);
      await habitRepo.updateHabit(habit.copyWith(taskId: taskId));
      await seedL0Task(taskId, habit);

      final (freshHabit, _) = repos();
      final report = await MigrationService(
        freshHabit,
        FailingUpdateTaskRepository(database),
      ).syncTaskCapabilities();

      expect(report.updated, 0);
      expect(report.verified, 0);
      expect(report.failed, 1);
      expect(report.isClean, isFalse);
    });

    test(
        'an unverifiable capability write surfaces in migration verification '
        'and a retry converges', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(targetCount: 3, timeOfDay: 'Evening');
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);
      await seedL0Task(taskId, habit);

      final broken = (await MigrationService(
        habitRepo,
        FailingUpdateTaskRepository(database),
      ).migrateHabits([habit.id]))
          .single;

      expect(broken.verification.isVerified, isFalse);
      expect(broken.verification.taskCapabilitiesPresent, isFalse);
      expect(
        broken.verification.taskCapabilitiesLost,
        containsAll(['targetCount', 'timeOfDay']),
      );

      // The same idempotent state machine with a healthy repository converges.
      final (freshHabit, freshTask) = repos();
      final retry = (await MigrationService(freshHabit, freshTask)
              .migrateHabits([habit.id]))
          .single;
      expect(retry.verification.isVerified, isTrue,
          reason: retry.verification.failures.join('; '));
      expect(await reloadTask(taskId), isNotNull);
    });

    test('mixed data: only the L0-shaped Task is rewritten', () async {
      final (habitRepo, _) = repos();
      final a = await eligibleHabit(title: 'A', targetCount: 2);
      final b = await eligibleHabit(title: 'B', timeOfDay: 'Evening');
      final taskA = HabitTaskIdentity.taskIdForHabit(a.id);
      final taskB = HabitTaskIdentity.taskIdForHabit(b.id);
      await habitRepo.updateHabit(a.copyWith(taskId: taskA));

      // A fully migrated Task plus an L0-shaped Task for B.
      await MigrationService(habitRepo, repos().$2).migrateHabits([a.id]);
      await habitRepo.updateHabit(b.copyWith(taskId: taskB));
      await seedL0Task(taskB, b);

      final (freshHabit, freshTask) = repos();
      final report =
          await MigrationService(freshHabit, freshTask).syncTaskCapabilities();

      expect(report.checked, 2);
      expect(report.updated, 1, reason: 'only B diverged');
      expect(report.verified, 2);
      expect(report.failed, 0);
      expect(
        LegacyHabitCapabilities.fromHabit(b),
        LegacyHabitCapabilities.fromTask(await reloadTask(taskB)),
      );
    });

    test('the bridge never creates or links a Task', () async {
      final (habitRepo, _) = repos();
      final dangling = await eligibleHabit(title: 'Dangling');
      final unlinked = await eligibleHabit(title: 'Unlinked');
      await habitRepo.updateHabit(dangling.copyWith(taskId: 'task_gone'));
      await database.remove(DatabaseService.tasksKey);

      final (freshHabit, freshTask) = repos();
      final report =
          await MigrationService(freshHabit, freshTask).syncTaskCapabilities();

      expect(report.unmatched, 1);
      expect(report.checked, 0);
      expect(report.updated, 0);
      expect(report.failed, 0);
      expect(report.isClean, isTrue,
          reason: 'a dangling link needs recovery, not a bridge write');
      expect((await freshTask.getAllTasks()).right, isEmpty);
      expect(unlinked.taskId, isNull);
    });
  });

  group('5. targetCount and targetDuration are configuration, not history', () {
    test('migrating a targetCount-3 habit copies its rows, not its target',
        () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(targetCount: 3, completions: 2);

      await MigrationService(habitRepo, taskRepo).migrateHabits([habit.id]);

      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);
      final taskRows = (await habitRepo.getAllCompletions())
          .right!
          .where((c) => c.itemId == taskId && c.itemType == 'task');
      expect(taskRows, hasLength(2),
          reason: 'the target is how much counts as done, not how many rows');
    });

    test('changing the target after migration never rewrites history',
        () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(targetCount: 3, completions: 2);
      await MigrationService(habitRepo, taskRepo).migrateHabits([habit.id]);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);

      final persisted = await reloadHabit(habit.id);
      await HabitRepositoryImpl(database)
          .updateHabit(persisted.copyWith(targetCount: 1));

      final (freshHabit, freshTask) = repos();
      final outcome = (await MigrationService(freshHabit, freshTask)
              .migrateHabits([habit.id]))
          .single;

      expect(outcome.verification.isVerified, isTrue,
          reason: outcome.verification.failures.join('; '));
      final task = await reloadTask(taskId);
      expect(task.targetCount, 1);
      final taskRows = (await freshHabit.getAllCompletions())
          .right!
          .where((c) => c.itemId == taskId && c.itemType == 'task');
      expect(taskRows, hasLength(2),
          reason: 'editing the target must not erase or duplicate history');
    });

    test('the aimed-at duration is not written into the copied history',
        () async {
      final (habitRepo, taskRepo) = repos();
      final habit =
          await eligibleHabit(targetDurationMinutes: 25, completions: 1);
      await MigrationService(habitRepo, taskRepo).migrateHabits([habit.id]);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);

      final task = await reloadTask(taskId);
      expect(task.targetDuration, const Duration(minutes: 25));

      // The copied occurrence rows carry no forced duration: the target stayed
      // on the Task and was not stamped onto every row as if it had happened.
      final rows = (await habitRepo.getAllCompletions())
          .right!
          .where((c) => c.itemId == taskId && c.itemType == 'task');
      expect(rows.every((c) => c.duration == null), isTrue);
    });
  });

  group('6. timeOfDay stays out of scheduling', () {
    test('does not change the underlying recurrence or due-ness', () async {
      final today = AppClock.now().startOfDay;
      final morning = Habit.create(
        title: 'Journal',
        category: 'Mind',
        timeOfDay: 'Morning',
        frequency: 'Daily',
      );
      final evening = morning.copyWith(timeOfDay: 'Evening');

      expect(evening.recurringSchedule, morning.recurringSchedule);
      expect(evening.isDueOnDate(today), morning.isDueOnDate(today));
    });

    test('does not interact with a reschedule or a snooze', () async {
      final now = AppClock.now();
      final morning = Habit.create(
        title: 'Journal',
        category: 'Mind',
        timeOfDay: 'Morning',
        frequency: 'Daily',
      );

      final morningRescheduled =
          morning.copyWith(dueAt: now.startOfDay.add(const Duration(hours: 9)));
      final eveningRescheduled =
          morningRescheduled.copyWith(timeOfDay: 'Evening');
      expect(
        eveningRescheduled.recurringSchedule.isDueOn(now.startOfDay, now: now),
        morningRescheduled.recurringSchedule.isDueOn(now.startOfDay, now: now),
      );

      final eveningSnoozed = morning.copyWith(
        timeOfDay: 'Evening',
        snoozedUntil: now.startOfDay.add(const Duration(hours: 48)),
      );
      expect(eveningSnoozed.isDueOnDate(now.startOfDay), isFalse);
      expect(eveningSnoozed.isDueOnDate(now.startOfDay), isFalse);
    });

    test('migration keeps it on the Task and out of the Task schedule',
        () async {
      final (habitRepo, taskRepo) = repos();
      final habit =
          await eligibleHabit(timeOfDay: 'Evening', dueAt: AppClock.now());
      await MigrationService(habitRepo, taskRepo).migrateHabits([habit.id]);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);

      final task = await reloadTask(taskId);
      expect(task.timeOfDay, 'Evening');
      expect(
        task.schedule.toJson(),
        habit.recurringSchedule.toJson(),
        reason: 'the label must not leak into scheduling JSON',
      );
    });
  });

  group('7. streak freeze usage survives as spent state', () {
    test('migrates verbatim and reads back through StreakFreezeUsage',
        () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(streakFreezesUsed: 2);
      await MigrationService(habitRepo, taskRepo).migrateHabits([habit.id]);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);

      final task = await reloadTask(taskId);
      expect(task.streakFreezeUsage, const StreakFreezeUsage(2));
      expect(LegacyHabitCapabilities.fromTask(task).streakFreezesUsed, 2);
    });

    test('an archived habit carries its freeze use into the archived Task',
        () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(
          archived: true, streakFreezesUsed: 1, completions: 1);
      await MigrationService(habitRepo, taskRepo).migrateHabits([habit.id]);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);

      final task = await reloadTask(taskId);
      expect(task.status, TaskStatus.archived);
      expect(task.streakFreezeUsage, const StreakFreezeUsage(1));
    });

    test('the allowance still limits use after migration', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(streakFreezesUsed: 3);
      await MigrationService(habitRepo, taskRepo).migrateHabits([habit.id]);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);

      final task = await reloadTask(taskId);
      expect(task.streakFreezeUsage.exhausted, isTrue);
      expect(task.streakFreezeUsage.use().used, 3,
          reason: 'cannot spend past the allowance');
    });
  });

  group('8. the canonical side is part of migration verification', () {
    test('taskCapabilitiesPresent is asserted for migrations', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(targetCount: 2);
      final outcome = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([habit.id]))
          .single;
      expect(outcome.verification.taskCapabilitiesPresent, isTrue);
      expect(outcome.verification.taskCapabilitiesLost, isEmpty);
    });
  });
}

/// A task repository whose update path always fails, so the capability write
/// itself is what must be surfaced rather than hidden.
class FailingUpdateTaskRepository extends TaskRepositoryImpl {
  FailingUpdateTaskRepository(super.database);

  @override
  Future<Result<Task>> updateTask(Task task) async =>
      Either.left(const CacheFailure('disk full'));
}
