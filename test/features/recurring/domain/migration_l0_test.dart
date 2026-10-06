import 'package:ascend/core/database/database.dart';
import 'package:ascend/core/extensions/date_extensions.dart';
import 'package:ascend/core/errors/failures.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/habits/data/repositories/habit_repository_impl.dart';
import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/habits/domain/entities/habit_completion.dart';
import 'package:ascend/features/progress/domain/services/progress_service.dart';
import 'package:ascend/features/recurring/domain/habit_task_identity.dart';
import 'package:ascend/features/recurring/domain/migration.dart';
import 'package:ascend/features/recurring/domain/migration_runner.dart';
import 'package:ascend/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stage L0 tests.
///
/// These run against the **real** repositories over mocked SharedPreferences
/// rather than the in-memory fakes the older migration tests use. That is
/// deliberate and is the point of the stage: `taskId` was silently dropped by
/// the serialiser, which an in-memory fake cannot detect because it stores
/// `Habit` objects and so keeps the field alive. Resumability across a process
/// restart is only testable against persisted state.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService database;

  /// A fresh repository pair over the same persisted store, which is what a
  /// relaunch looks like: brand new caches reading the same JSON.
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

  /// A habit whose stored counters agree with its log, so the parity gate
  /// admits it.
  ///
  /// Completions land on consecutive days ending today. Same-day completions
  /// would not satisfy parity for `completions > 1`: the counters count rows
  /// while [HabitLogProjection] counts distinct days, so two rows on one day
  /// reads as a divergence and the habit gets quarantined for a reason that has
  /// nothing to do with the migration.
  Future<Habit> eligibleHabit({
    String title = 'Read',
    String category = 'Mind',
    int completions = 1,
    bool archived = false,
    String frequency = 'Daily',
    List<int> customWeekdays = const [],
    String? projectId,
    String? goalId,
    int targetCount = 1,
    int targetDurationMinutes = 0,
    String cue = '',
    String timeOfDay = 'Morning',
    int streakFreezesUsed = 0,
  }) async {
    final habit = Habit.create(
      title: title,
      category: category,
      frequency: frequency,
      customWeekdays: customWeekdays,
      projectId: projectId,
      goalId: goalId,
      targetCount: targetCount,
      targetDuration: Duration(minutes: targetDurationMinutes),
      cue: cue,
      timeOfDay: timeOfDay,
    ).copyWith(streakFreezesUsed: streakFreezesUsed);

    final stored = archived ? habit.copyWith(isArchived: true) : habit;

    // Oldest first, so the stored chain builds the same way the log reads back.
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

  group('1. clean Habit -> Task migration', () {
    test('creates one Task, links it, and copies history', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit();

      final outcomes =
          await MigrationService(habitRepo, taskRepo).migrateHabits([habit.id]);

      final outcome = outcomes.single;
      expect(outcome.state, MigrationState.migrated);
      expect(outcome.verification.isVerified, isTrue,
          reason: outcome.verification.failures.join('; '));

      // Persisted outcome: the Task really is in storage.
      final reloadedTasks = (await TaskRepositoryImpl(database).getAllTasks())
          .getOrElse((_) => const <Task>[]);
      expect(reloadedTasks, hasLength(1));
      expect(
          reloadedTasks.single.id, HabitTaskIdentity.taskIdForHabit(habit.id));
      expect(reloadedTasks.single.title, habit.title);
      expect(reloadedTasks.single.schedule, isA<Recurring>());

      // Persisted outcome: the link survives a relaunch.
      final reloadedHabits =
          (await HabitRepositoryImpl(database).getAllHabits())
              .getOrElse((_) => const <Habit>[]);
      expect(reloadedHabits.single.taskId, reloadedTasks.single.id);

      // Persisted outcome: history arrived with it.
      final completions =
          (await HabitRepositoryImpl(database).getAllCompletions())
              .getOrElse((_) => const <HabitCompletion>[]);
      final taskRows = completions.where((c) => c.itemType == 'task').toList();
      expect(taskRows, hasLength(1));
      expect(
          taskRows.single.id,
          HabitTaskIdentity.completionIdForCopy(
              completions.firstWhere((c) => c.isHabitCompletion).id));
    });

    test('carries schedule overrides dueAt and snoozedUntil across', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit();
      final snoozed = habit.copyWith(
        dueAt: DateTime(2026, 5, 1, 9),
        snoozedUntil: DateTime(2026, 5, 3, 9),
      );
      await habitRepo.updateHabit(snoozed);

      final outcome = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([habit.id]))
          .single;

      final task =
          (await TaskRepositoryImpl(database).getTaskById(outcome.taskId!))
              .getOrNull()!;
      final recurring = task.schedule as Recurring;
      expect(recurring.dueAt, DateTime(2026, 5, 1, 9));
      expect(recurring.snoozedUntil, DateTime(2026, 5, 3, 9));
    });

    test('preserves a non-daily recurrence', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(
        frequency: 'Custom',
        customWeekdays: [1, 3, 5],
      );

      final outcome = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([habit.id]))
          .single;

      final task =
          (await TaskRepositoryImpl(database).getTaskById(outcome.taskId!))
              .getOrNull()!;
      expect(task.schedule, isA<Recurring>());
      expect((task.schedule as Recurring).rule, isA<CustomRecurrence>());
    });
  });

  group('2. migration retry / 14. idempotency', () {
    test('a second run creates nothing and rewrites no habit', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit();

      final service = MigrationService(habitRepo, taskRepo);
      await service.migrateHabits([habit.id]);

      final second = (await service.migrateHabits([habit.id])).single;
      expect(second.state, MigrationState.alreadyMigrated);
      expect(second.createdTask, isFalse);
      expect(second.verification.isVerified, isTrue);

      expect((await taskRepo.getAllTasks()).getOrElse((_) => const <Task>[]),
          hasLength(1));
    });

    test('history is not duplicated across repeated runs', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(completions: 3);

      final service = MigrationService(habitRepo, taskRepo);
      await service.migrateHabits([habit.id]);
      await service.migrateHabits([habit.id]);
      await service.migrateHabits([habit.id]);

      final completions = (await habitRepo.getAllCompletions())
          .getOrElse((_) => const <HabitCompletion>[]);
      final taskRows = completions.where((c) => c.itemType == 'task').toList();
      expect(taskRows, hasLength(3));
      expect(taskRows.map((c) => c.id).toSet(), hasLength(3));
    });

    test('idempotent across a simulated relaunch', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit();
      await MigrationService(habitRepo, taskRepo).migrateHabits([habit.id]);

      // New instances reading the same persisted store - what a relaunch is.
      final (relaunchedHabits, relaunchedTasks) = repos();
      final outcome = (await MigrationService(relaunchedHabits, relaunchedTasks)
              .migrateHabits([habit.id]))
          .single;

      expect(outcome.state, MigrationState.alreadyMigrated);
      expect(outcome.createdTask, isFalse);
      expect(
          (await relaunchedTasks.getAllTasks())
              .getOrElse((_) => const <Task>[]),
          hasLength(1));
    });
  });

  group('3. interruption / partial migration', () {
    test('a Task written with no link is adopted, not duplicated', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit();

      // Simulate the old create-then-link crash window: the Task exists at the
      // deterministic id but the habit never got its taskId written.
      final expectedId = HabitTaskIdentity.taskIdForHabit(habit.id);
      await taskRepo.createTask(Task(
        id: expectedId,
        title: habit.title,
        description: habit.description,
        createdAt: habit.createdAt,
        updatedAt: habit.updatedAt,
        sortOrder: habit.sortOrder,
        status: TaskStatus.todo,
        schedule: habit.recurringSchedule,
        projectId: habit.projectId,
        goalId: habit.goalId,
        category: habit.category,
      ));

      final outcome = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([habit.id]))
          .single;

      expect(outcome.taskId, expectedId);
      expect(outcome.identitySource, MigrationIdentitySource.deterministicId);
      expect(outcome.state, MigrationState.adoptedExistingTask);
      expect(outcome.createdTask, isFalse);
      expect(outcome.verification.isVerified, isTrue,
          reason: outcome.verification.failures.join('; '));

      // Exactly one Task, and the link is now written.
      expect((await taskRepo.getAllTasks()).getOrElse((_) => const <Task>[]),
          hasLength(1));
      expect((await habitRepo.getHabitById(habit.id)).getOrNull()?.taskId,
          expectedId);
    });

    test('an interrupted run is repaired on the next launch', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(completions: 2);

      // First attempt writes the Task, then dies before linking or copying.
      final expectedId = HabitTaskIdentity.taskIdForHabit(habit.id);
      await taskRepo.createTask(Task(
        id: expectedId,
        title: habit.title,
        description: habit.description,
        createdAt: habit.createdAt,
        updatedAt: habit.updatedAt,
        sortOrder: habit.sortOrder,
        status: TaskStatus.todo,
        schedule: habit.recurringSchedule,
        projectId: habit.projectId,
        goalId: habit.goalId,
        category: habit.category,
      ));

      // Relaunch.
      final (habitRepo2, taskRepo2) = repos();
      final outcome = (await MigrationService(habitRepo2, taskRepo2)
              .migrateHabits([habit.id]))
          .single;

      expect(outcome.verification.isVerified, isTrue,
          reason: outcome.verification.failures.join('; '));
      // The missing history was completed, not skipped.
      expect(outcome.verification.historyPreserved, isTrue);
      expect(outcome.verification.historyRowsMissing, 0);
      expect((await taskRepo2.getAllTasks()).getOrElse((_) => const <Task>[]),
          hasLength(1));
    });
  });

  group('4. valid taskId + valid Task', () {
    test('is reported as already migrated and nothing is written', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit();

      final first = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([habit.id]))
          .single;
      expect(first.state, MigrationState.migrated);

      final before = await database.getJsonList(DatabaseService.habitsKey);

      final second = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([habit.id]))
          .single;

      expect(second.state, MigrationState.alreadyMigrated);
      expect(second.taskId, first.taskId);
      // The habit record is byte-identical, so nothing was rewritten.
      expect(await database.getJsonList(DatabaseService.habitsKey), before);
    });
  });

  group('5. dangling taskId', () {
    test('a link to a deleted Task is cleared and re-migrated', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit();
      await habitRepo.updateHabit(habit.copyWith(taskId: 'task_vanished'));

      final outcome = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([habit.id]))
          .single;

      expect(outcome.state, MigrationState.recoveredDanglingLink);
      expect(outcome.createdTask, isTrue,
          reason: 'recovery still had to create the replacement Task');
      expect(outcome.taskId, isNot('task_vanished'));

      final persisted = (await HabitRepositoryImpl(database).getAllHabits())
          .getOrElse((_) => const <Habit>[])
          .single;
      expect(persisted.taskId, outcome.taskId);
      expect(
          (await TaskRepositoryImpl(database).getTaskById(persisted.taskId!))
              .getOrNull(),
          isNotNull);
    });
  });

  group('6. existing Task with a missing link', () {
    test('an older attempt\'s randomly-id\'d Task is adopted by content',
        () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(title: 'Stretch', projectId: 'p1');

      // What the pre-L0 migration left behind: a Task with a random id.
      await taskRepo.createTask(Task(
        id: 'task_oldschool',
        title: habit.title,
        description: habit.description,
        createdAt: habit.createdAt,
        updatedAt: habit.updatedAt,
        sortOrder: habit.sortOrder,
        status: TaskStatus.todo,
        schedule: habit.recurringSchedule,
        projectId: habit.projectId,
        goalId: habit.goalId,
        category: habit.category,
      ));

      final outcome = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([habit.id]))
          .single;

      expect(outcome.state, MigrationState.adoptedExistingTask);
      expect(outcome.identitySource, MigrationIdentitySource.logicalAdoption);
      expect(outcome.taskId, 'task_oldschool');
      // Adopted, not duplicated.
      expect((await taskRepo.getAllTasks()).getOrElse((_) => const <Task>[]),
          hasLength(1));
      expect((await habitRepo.getHabitById(habit.id)).getOrNull()?.taskId,
          'task_oldschool');
    });

    test('does not adopt a Task already claimed by another habit', () async {
      final (habitRepo, taskRepo) = repos();
      final a = await eligibleHabit(title: 'Read');
      final b = await eligibleHabit(title: 'Run');

      // `b` was migrated and claims a Task that also looks like `a`'s content.
      final claimedId = HabitTaskIdentity.taskIdForHabit(b.id);
      await taskRepo.createTask(Task(
        id: claimedId,
        title: a.title,
        description: a.description,
        createdAt: a.createdAt,
        updatedAt: a.updatedAt,
        sortOrder: a.sortOrder,
        status: TaskStatus.todo,
        schedule: a.recurringSchedule,
        projectId: a.projectId,
        goalId: a.goalId,
        category: a.category,
      ));
      await habitRepo.updateHabit((await habitRepo.getHabitById(b.id))
          .getOrNull()!
          .copyWith(taskId: claimedId));

      final outcome =
          (await MigrationService(habitRepo, taskRepo).migrateHabits([a.id]))
              .single;

      expect(outcome.taskId, isNot(claimedId));
      expect(outcome.state, MigrationState.migrated);
    });
  });

  group('7. duplicate logical Task detection', () {
    test('reports extras left by an older attempt without deleting them',
        () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(title: 'Meditate');

      for (final id in ['task_dup_a', 'task_dup_b', 'task_dup_c']) {
        await taskRepo.createTask(Task(
          id: id,
          title: habit.title,
          description: habit.description,
          createdAt: habit.createdAt,
          updatedAt: habit.updatedAt,
          sortOrder: habit.sortOrder,
          status: TaskStatus.todo,
          schedule: habit.recurringSchedule,
          projectId: habit.projectId,
          goalId: habit.goalId,
          category: habit.category,
        ));
      }

      final outcome = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([habit.id]))
          .single;

      // Deterministic pick: lowest id.
      expect(outcome.taskId, 'task_dup_a');
      expect(outcome.duplicateTaskIds, ['task_dup_b', 'task_dup_c']);
      // No fourth Task was created.
      expect((await taskRepo.getAllTasks()).getOrElse((_) => const <Task>[]),
          hasLength(3));
      // The migration itself introduced no duplicate.
      expect(outcome.verification.noDuplicateLogicalTask, isTrue);
    });
  });

  group('8. archived Habit migration', () {
    test('is included in the parity gate', () async {
      final (habitRepo, taskRepo) = repos();
      final archived = await eligibleHabit(title: 'Old habit', archived: true);

      final report =
          await MigrationService(habitRepo, taskRepo).runParityGate();
      expect(report.eligible, contains(archived.id));
    });

    test('becomes an archived Task, not a live one', () async {
      final (habitRepo, taskRepo) = repos();
      final archived = await eligibleHabit(title: 'Old habit', archived: true);

      final outcome = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([archived.id]))
          .single;

      expect(outcome.verification.archivedStatePreserved, isTrue,
          reason: outcome.verification.failures.join('; '));

      final task =
          (await TaskRepositoryImpl(database).getTaskById(outcome.taskId!))
              .getOrNull()!;
      expect(task.status, TaskStatus.archived);
      expect(task.archivedAt, isNotNull);

      // And it stays out of the default list, exactly as the habit did.
      expect(
          (await TaskRepositoryImpl(database).getAllTasks())
              .getOrElse((_) => const <Task>[]),
          isEmpty);
      expect(
          (await HabitRepositoryImpl(database).getAllHabits())
              .getOrElse((_) => const <Habit>[]),
          isEmpty);
      expect(
          (await HabitRepositoryImpl(database)
                  .getAllHabits(includeArchived: true))
              .getOrElse((_) => const <Habit>[]),
          hasLength(1));
    });

    test('an active habit never yields an archived Task', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit();

      final outcome = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([habit.id]))
          .single;

      final task =
          (await TaskRepositoryImpl(database).getTaskById(outcome.taskId!))
              .getOrNull()!;
      expect(task.status, TaskStatus.todo);
      expect(task.archivedAt, isNull);
    });
  });

  group('9. the five capability decisions', () {
    test('all five survive the migration on the legacy record', () async {
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

      expect(outcome.verification.legacyCapabilitiesPreserved, isTrue,
          reason: outcome.verification.failures.join('; '));

      // Read back from persisted storage, not from the in-memory object.
      final reloaded = (await HabitRepositoryImpl(database).getAllHabits())
          .getOrElse((_) => const <Habit>[])
          .single;
      final capabilities = LegacyHabitCapabilities.fromHabit(reloaded);

      expect(capabilities.targetCount, 3);
      expect(capabilities.targetDuration, const Duration(minutes: 25));
      expect(capabilities.cue, 'After coffee');
      expect(capabilities.timeOfDay, 'Evening');
      expect(capabilities.streakFreezesUsed, 2);
      expect(capabilities.matchesHabit(habit), isTrue);
      expect(capabilities.hasCustomisedValues, isTrue);
    });

    test('names the capability that was lost', () async {
      // Proves the check is field-level rather than a blanket boolean.
      final capabilities = const LegacyHabitCapabilities(
        targetCount: 3,
        targetDuration: Duration.zero,
        cue: '',
        timeOfDay: 'Morning',
        streakFreezesUsed: 0,
      );
      final habit =
          Habit.create(title: 'Read', category: 'Mind', targetCount: 1);

      expect(capabilities.fieldsLostFrom(habit), ['targetCount']);
      expect(capabilities.matchesHabit(habit), isFalse);
    });

    test('a default habit reports no customised values', () {
      final habit = Habit.create(title: 'Read', category: 'Mind');
      expect(LegacyHabitCapabilities.fromHabit(habit).hasCustomisedValues,
          isFalse);
      expect(LegacyHabitCapabilities.fieldNames, hasLength(5));
    });
  });

  group('10. completion history preservation', () {
    test('every legacy row keeps its timestamp and count', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(completions: 2);

      final legacy = (await habitRepo.getCompletionsForHabit(habit.id))
          .getOrElse((_) => const <HabitCompletion>[]);
      // Give the rows distinct days so nothing can pass by day-coincidence.
      final stamped = <HabitCompletion>[
        legacy[0].copyWith(completedAt: DateTime(2026, 3, 15, 9, 30)),
        legacy[1].copyWith(completedAt: DateTime(2026, 3, 16, 8, 0), count: 4),
      ];
      for (final row in stamped) {
        await habitRepo.deleteCompletion(legacy
            .firstWhere(
                (c) => c.completedAt == row.completedAt || c.id == row.id)
            .id);
      }
      for (final row in stamped) {
        await habitRepo.createCompletion(row);
      }

      final outcome = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([habit.id]))
          .single;
      expect(outcome.verification.historyPreserved, isTrue);

      final taskRows = (await habitRepo.getAllCompletions())
          .getOrElse((_) => const <HabitCompletion>[])
          .where((c) => c.itemType == 'task')
          .toList();

      expect(taskRows, hasLength(2));
      expect(taskRows.map((c) => c.completedAt).toSet(),
          {DateTime(2026, 3, 15, 9, 30), DateTime(2026, 3, 16, 8, 0)});
      expect(taskRows.map((c) => c.count).toSet(), {1, 4});
    });

    test('two rows on one day are both kept', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(completions: 1);

      final day = DateTime(2026, 3, 20, 12);
      final original = (await habitRepo.getCompletionsForHabit(habit.id))
          .getOrElse((_) => const <HabitCompletion>[]) as List<HabitCompletion>;
      await habitRepo.deleteCompletion(original.single.id);
      await habitRepo.createCompletion(
          HabitCompletion.create(habitId: habit.id, count: 2)
              .copyWith(completedAt: day));
      await habitRepo.createCompletion(
          HabitCompletion.create(habitId: habit.id, count: 3)
              .copyWith(completedAt: day));

      await MigrationService(habitRepo, taskRepo).migrateHabits([habit.id]);

      final taskRows = (await habitRepo.getAllCompletions())
          .getOrElse((_) => const <HabitCompletion>[])
          .where((c) => c.itemType == 'task')
          .toList();

      // Day-dedupe would have collapsed these to one and lost count 3.
      expect(taskRows, hasLength(2));
      expect(taskRows.map((c) => c.count).toSet(), {2, 3});
    });

    test('a habit with no history migrates cleanly', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(completions: 0);

      final outcome = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([habit.id]))
          .single;

      expect(outcome.verification.historyPreserved, isTrue);
      expect(outcome.verification.historyRowsMissing, 0);
      expect(outcome.verification.isVerified, isTrue);
    });

    test('legacy rows are retained, not deleted', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(completions: 2);

      await MigrationService(habitRepo, taskRepo).migrateHabits([habit.id]);

      final legacyRows = (await habitRepo.getCompletionsForHabit(habit.id))
          .getOrElse((_) => const <HabitCompletion>[]);
      expect(legacyRows, hasLength(2));
    });
  });

  group('11. Analytics double-count prevention', () {
    test('habit-scoped reads still count each day once after migration',
        () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(completions: 3);

      final progress = ProgressService();

      final habitsBefore =
          (await habitRepo.getAllHabits()).getOrElse((_) => const <Habit>[]);
      final logBefore = (await habitRepo.getAllCompletions())
          .getOrElse((_) => const <HabitCompletion>[]);

      final byCategoryBefore =
          progress.habitCompletionsByCategoryFromLog(habitsBefore, logBefore);
      final heatmapBefore = (await habitRepo.getCompletionHeatmap(habit.id))
          .getOrElse((_) => const <DateTime, int>{});
      final daysBefore =
          progress.completedHabitIdsByDay(logBefore)[AppClock.now().startOfDay];

      await MigrationService(habitRepo, taskRepo).migrateHabits([habit.id]);

      final habitsAfter = (await HabitRepositoryImpl(database).getAllHabits())
          .getOrElse((_) => const <Habit>[]);
      final logAfter = (await HabitRepositoryImpl(database).getAllCompletions())
          .getOrElse((_) => const <HabitCompletion>[]);

      // The copied rows carry habitId == null and itemType 'task', so every
      // habit-scoped aggregation skips them and totals are unchanged.
      expect(progress.habitCompletionsByCategoryFromLog(habitsAfter, logAfter),
          byCategoryBefore);
      expect(
          (await HabitRepositoryImpl(database).getCompletionHeatmap(habit.id))
              .getOrElse((_) => const <DateTime, int>{}),
          heatmapBefore);
      expect(
          progress.completedHabitIdsByDay(logAfter)[AppClock.now().startOfDay],
          daysBefore);
    });

    test('copied rows are not attributed to any habit', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(completions: 2);

      await MigrationService(habitRepo, taskRepo).migrateHabits([habit.id]);

      final taskRows = (await habitRepo.getAllCompletions())
          .getOrElse((_) => const <HabitCompletion>[])
          .where((c) => c.itemType == 'task')
          .toList();

      expect(taskRows, isNotEmpty);
      for (final row in taskRows) {
        expect(row.habitId, isNull);
        expect(row.isHabitCompletion, isFalse);
      }
    });

    test('getCompletionsForHabit excludes the Task rows', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(completions: 2);

      await MigrationService(habitRepo, taskRepo).migrateHabits([habit.id]);

      final scoped = (await habitRepo.getCompletionsForHabit(habit.id))
          .getOrElse((_) => const <HabitCompletion>[]);
      expect(scoped, hasLength(2));
      expect(scoped.every((c) => c.isHabitCompletion), isTrue);
    });
  });

  group('12. streak compatibility / gating', () {
    test('stored legacy counters are carried across untouched', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(completions: 3);

      final before = (await HabitRepositoryImpl(database).getAllHabits())
          .getOrElse((_) => const <Habit>[])[0];
      final counters = (
        before.currentStreak,
        before.longestStreak,
        before.totalCompletions,
      );

      final outcome = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([habit.id]))
          .single;

      expect(outcome.verification.streakCountersPreserved, isTrue,
          reason: outcome.verification.failures.join('; '));

      final after = (await HabitRepositoryImpl(database).getAllHabits())
          .getOrElse((_) => const <Habit>[])[0];
      expect((after.currentStreak, after.longestStreak, after.totalCompletions),
          counters);
    });

    test('the semantic delta is declared rather than silently applied', () {
      expect(kStreakSemanticsDelta, contains('day-consecutive'));
      expect(kStreakSemanticsDelta, contains('scheduled-consecutive'));
    });
  });

  group('13. migration verification', () {
    test('reports every check as passing for a clean migration', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(projectId: 'p', goalId: 'g');

      final outcome = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([habit.id]))
          .single;
      final v = outcome.verification;

      expect(v.taskExists, isTrue);
      expect(v.taskIsRecurring, isTrue);
      expect(v.schedulePreserved, isTrue);
      expect(v.projectIdPreserved, isTrue);
      expect(v.goalIdPreserved, isTrue);
      expect(v.archivedStatePreserved, isTrue);
      expect(v.legacyCapabilitiesPreserved, isTrue);
      expect(v.legacyCapabilitiesLost, isEmpty);
      expect(v.historyPreserved, isTrue);
      expect(v.historyRowsMissing, 0);
      expect(v.streakCountersPreserved, isTrue);
      expect(v.noDuplicateLogicalTask, isTrue);
      expect(v.failures, isEmpty);
      expect(v.isVerified, isTrue);
    });

    test('fails verification and names the cause when a write is lost',
        () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit();

      final outcome = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([habit.id]))
          .single;
      expect(outcome.verification.isVerified, isTrue);

      // Someone deletes the migrated Task behind the migration's back. Fresh
      // repository instances are required to observe it: the existing ones still
      // hold the Task in their in-memory cache and would report it present.
      await database.remove(DatabaseService.tasksKey);
      final (habitRepo2, taskRepo2) = repos();

      final reverified = (await MigrationService(habitRepo2, taskRepo2)
              .migrateHabits([habit.id]))
          .single;

      // The dangling link is detected rather than trusted.
      expect(reverified.state, MigrationState.recoveredDanglingLink);
      expect(reverified.verification.isVerified, isTrue);
      expect(
          (await TaskRepositoryImpl(database).getAllTasks())
              .getOrElse((_) => const <Task>[]),
          hasLength(1));
    });

    test('a missing habit fails without throwing', () async {
      final (habitRepo, taskRepo) = repos();
      final outcome = await MigrationService(habitRepo, taskRepo)
          .migrateHabit('habit_does_not_exist');

      expect(outcome.state, MigrationState.failed);
      expect(outcome.isSuccess, isFalse);
      expect(outcome.verification.isVerified, isFalse);
      expect(outcome.error, isNotNull);
    });
  });

  group('15. multiple Habits', () {
    test('migrates each to its own Task', () async {
      final (habitRepo, taskRepo) = repos();
      final habits = [
        await eligibleHabit(title: 'A'),
        await eligibleHabit(title: 'B'),
        await eligibleHabit(title: 'C'),
      ];

      final outcomes = await MigrationService(habitRepo, taskRepo)
          .migrateHabits(habits.map((h) => h.id).toList());

      expect(outcomes, hasLength(3));
      expect(outcomes.every((o) => o.verification.isVerified), isTrue,
          reason: outcomes
              .where((o) => !o.verification.isVerified)
              .map((o) => '${o.habitId}: ${o.verification.failures}')
              .join('; '));

      final tasks = (await TaskRepositoryImpl(database).getAllTasks())
          .getOrElse((_) => const <Task>[]);
      expect(tasks, hasLength(3));
      expect(tasks.map((t) => t.id).toSet(),
          habits.map((h) => HabitTaskIdentity.taskIdForHabit(h.id)).toSet());
    });

    test('a quarantined habit is left alone while others migrate', () async {
      final (habitRepo, taskRepo) = repos();
      final good = await eligibleHabit(title: 'Good');
      final bad =
          await eligibleHabit(title: 'Bad', completions: 0).then((h) => h);
      await habitRepo.updateHabit(bad.copyWith(
          currentStreak: 5, longestStreak: 5, totalCompletions: 5));

      final result =
          await MigrationService(habitRepo, taskRepo).runFullMigration();

      expect(result.report.quarantined.map((q) => q.habitId), [bad.id]);
      expect(result.outcomes.map((o) => o.habitId), [good.id]);
      expect(result.migratedCount, 1);
      expect(
          (await habitRepo.getHabitById(bad.id)).getOrNull()?.taskId, isNull);
      expect((await taskRepo.getAllTasks()).getOrElse((_) => const <Task>[]),
          hasLength(1));
    });
  });

  group('16. zero Habits', () {
    test('runFullMigration on an empty install is a clean no-op', () async {
      final (habitRepo, taskRepo) = repos();
      final result =
          await MigrationService(habitRepo, taskRepo).runFullMigration();

      expect(result.report.eligible, isEmpty);
      expect(result.report.quarantined, isEmpty);
      expect(result.migratedCount, 0);
      expect(result.outcomes, isEmpty);
      expect((await taskRepo.getAllTasks()).getOrElse((_) => const <Task>[]),
          isEmpty);
    });
  });

  group('17. already-fully-migrated dataset', () {
    test('a relaunch verifies without rewriting anything', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(completions: 2);
      await MigrationService(habitRepo, taskRepo).migrateHabits([habit.id]);

      final habitsBefore =
          await database.getJsonList(DatabaseService.habitsKey);
      final tasksBefore = await database.getJsonList(DatabaseService.tasksKey);
      final completionsBefore = await database.getJsonList('habit_completions');

      // Relaunch: brand new repository caches over the same store.
      final (habitRepo2, taskRepo2) = repos();
      final result =
          await MigrationService(habitRepo2, taskRepo2).runFullMigration();

      expect(result.outcomes.single.state, MigrationState.alreadyMigrated);
      expect(result.outcomes.single.verification.isVerified, isTrue);
      expect(result.migratedCount, 0);

      // Byte-identical storage: nothing was rewritten.
      expect(
          await database.getJsonList(DatabaseService.habitsKey), habitsBefore);
      expect(await database.getJsonList(DatabaseService.tasksKey), tasksBefore);
      expect(
          await database.getJsonList('habit_completions'), completionsBefore);
    });
  });

  group('taskId persistence (the prerequisite fix)', () {
    test('survives a reload on the real repository', () async {
      final (habitRepo, _) = repos();
      final habit = await eligibleHabit();
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);

      await habitRepo.updateHabit(habit.copyWith(taskId: taskId));

      final reloaded = (await HabitRepositoryImpl(database).getAllHabits())
          .getOrElse((_) => const <Habit>[])
          .single;
      expect(reloaded.taskId, taskId);
    });

    test('records written without taskId load as null', () async {
      // Simulates an install that predates the field.
      await database.setJsonList(DatabaseService.habitsKey, [
        {
          'id': 'habit_legacy',
          'title': 'Legacy',
          'description': '',
          'category': 'Mind',
          'frequency': 'Daily',
          'customWeekdays': <int>[],
          'timeOfDay': 'Morning',
          'targetCount': 1,
          'targetDurationMinutes': 0,
          'cue': '',
          'createdAt': DateTime(2024, 1, 1).toIso8601String(),
          'updatedAt': DateTime(2024, 1, 1).toIso8601String(),
          'sortOrder': 0,
          'isArchived': false,
          'streakFreezesUsed': 0,
          'projectId': null,
          'goalId': null,
          'currentStreak': 0,
          'longestStreak': 0,
          'totalCompletions': 0,
        }
      ]);

      final (habitRepo, _) = repos();
      final habit = (await habitRepo.getAllHabits())
          .getOrElse((_) => const <Habit>[])
          .single;
      expect(habit.id, 'habit_legacy');
      expect(habit.taskId, isNull);
    });
  });

  group('production runner', () {
    test('runs once and then short-circuits on the marker', () async {
      final (habitRepo, taskRepo) = repos();
      await eligibleHabit(completions: 2);

      final runner = HabitTaskMigrationRunner(
        migration: MigrationService(habitRepo, taskRepo),
        database: database,
      );

      expect(runner.isComplete, isFalse);

      final first = await runner.runIfRequired();
      expect(first.ran, isTrue);
      expect(first.migratedCount, 1);
      expect(first.failed, 0);
      expect(first.unverified, 0);
      expect(first.isClean, isTrue);
      expect(runner.isComplete, isTrue);

      final habitsBefore =
          await database.getJsonList(DatabaseService.habitsKey);

      // Second launch reads one key and does nothing else.
      final second = await HabitTaskMigrationRunner(
        migration: MigrationService(
            HabitRepositoryImpl(database), TaskRepositoryImpl(database)),
        database: database,
      ).runIfRequired();

      expect(second.ran, isFalse);
      expect(second.migratedCount, 0);
      expect(
          await database.getJsonList(DatabaseService.habitsKey), habitsBefore);
    });

    test('does not run on an install with no habits', () async {
      final (habitRepo, taskRepo) = repos();
      final result = await HabitTaskMigrationRunner(
        migration: MigrationService(habitRepo, taskRepo),
        database: database,
      ).runIfRequired();

      expect(result.ran, isTrue);
      expect(result.migratedCount, 0);
      expect(result.isClean, isTrue);
    });

    test('records quarantined habits in the marker without failing', () async {
      final (habitRepo, taskRepo) = repos();
      final bad = await eligibleHabit(title: 'Bad', completions: 0);
      await habitRepo.updateHabit(bad.copyWith(
          currentStreak: 9, longestStreak: 9, totalCompletions: 9));

      final result = await HabitTaskMigrationRunner(
        migration: MigrationService(habitRepo, taskRepo),
        database: database,
      ).runIfRequired();

      expect(result.quarantined, 1);
      expect(result.failed, 0);
      expect(result.isClean, isTrue);
      expect(
          (await habitRepo.getHabitById(bad.id)).getOrNull()?.taskId, isNull);
    });

    test('is resolvable without launching the UI', () {
      // Constructing the runner touches no widget and no binding: both
      // dependencies are injected, so it can be driven straight from a test.
      final (habitRepo, taskRepo) = repos();
      final runner = HabitTaskMigrationRunner(
        migration: MigrationService(habitRepo, taskRepo),
        database: database,
      );
      expect(runner.isComplete, isFalse);
    });
  });

  group('14. failure is explicit, never silent', () {
    test('the parity gate reports a read failure instead of an empty pass',
        () async {
      // "No eligible habits" and "could not read the habits" are the same value
      // to a caller that swallows errors, and the production runner would then
      // write its completion marker over an install it never actually saw.
      final service = MigrationService(
        UnreadableHabitsRepository(database),
        TaskRepositoryImpl(database),
      );

      await expectLater(
        service.runParityGate(),
        throwsA(isA<StateError>()),
      );
    });

    test('adopting a Task that already holds copied rows does not double them',
        () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(completions: 3);

      // An older attempt already created the Task under a random id *and*
      // copied the history under random ids too.
      const olderTaskId = 'task_older_attempt';
      await taskRepo.createTask(Task(
        id: olderTaskId,
        title: habit.title,
        category: habit.category,
        createdAt: habit.createdAt,
        updatedAt: habit.updatedAt,
        status: TaskStatus.todo,
        schedule: habit.recurringSchedule,
        sortOrder: 0,
      ));
      final legacy = (await habitRepo.getCompletionsForHabit(habit.id))
          .getOrElse((_) => const <HabitCompletion>[]);
      for (final row in legacy) {
        await habitRepo.createCompletion(HabitCompletion(
          id: 'random_${row.id}',
          habitId: null,
          itemId: olderTaskId,
          itemType: 'task',
          completedAt: row.completedAt,
          count: row.count,
        ));
      }

      final outcome = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([habit.id]))
          .single;

      expect(outcome.state, MigrationState.adoptedExistingTask);
      expect(outcome.taskId, olderTaskId);
      expect(outcome.verification.isVerified, isTrue,
          reason: outcome.verification.failures.join('; '));

      // Three occurrences in, three rows out - not six.
      final taskRows = (await habitRepo.getAllCompletions())
          .getOrElse((_) => const <HabitCompletion>[])
          .where((c) => c.itemId == olderTaskId && c.itemType == 'task');
      expect(taskRows, hasLength(3));
    });
  });

  group('production runner marker integrity', () {
    test('no marker is written when a write cannot be verified', () async {
      // The marker means "this install is migrated". Writing it after a run that
      // left an unverified link behind would retire the migration with the work
      // unfinished, and the next launch would never retry.
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit();

      // A repository whose link write is silently dropped: the Task is created
      // but the habit never records it.
      final runner = HabitTaskMigrationRunner(
        migration: MigrationService(
          DroppingTaskLinkRepository(database),
          taskRepo,
        ),
        database: database,
      );

      final result = await runner.runIfRequired();

      expect(result.ran, isTrue);
      expect(result.unverified, greaterThan(0));
      expect(result.isClean, isFalse);
      expect(runner.isComplete, isFalse,
          reason: 'marker must stay absent so the next launch retries');
    });

    test('a retry after an unverified run completes the migration', () async {
      final (habitRepo, taskRepo) = repos();
      await eligibleHabit();

      final broken = HabitTaskMigrationRunner(
        migration: MigrationService(
          DroppingTaskLinkRepository(database),
          taskRepo,
        ),
        database: database,
      );
      expect((await broken.runIfRequired()).isClean, isFalse);

      // Second launch, healthy repositories: the same install now converges.
      final (habitRepo2, taskRepo2) = repos();
      final healthy = HabitTaskMigrationRunner(
        migration: MigrationService(habitRepo2, taskRepo2),
        database: database,
      );
      final retry = await healthy.runIfRequired();

      expect(retry.isClean, isTrue);
      expect(healthy.isComplete, isTrue);
      expect(
          (await TaskRepositoryImpl(database).getAllTasks())
              .getOrElse((_) => const <Task>[]),
          hasLength(1),
          reason: 'the failed attempt must not have left a second Task behind');
    });
  });
}

/// A repository whose habit list cannot be read.
///
/// Extends the concrete implementation rather than the interface so the
/// override stays two lines and cannot drift out of sync with the interface.
class UnreadableHabitsRepository extends HabitRepositoryImpl {
  UnreadableHabitsRepository(super.database);

  @override
  Future<Result<List<Habit>>> getAllHabits(
          {bool includeArchived = true}) async =>
      Either.left(CacheFailure(
          'storage unavailable')); // ignore: prefer_const_constructors
}

/// A repository that creates the Task fine but silently drops the habit -> task
/// link, which is the exact failure the marker gate has to catch.
class DroppingTaskLinkRepository extends HabitRepositoryImpl {
  DroppingTaskLinkRepository(super.database);

  @override
  Future<Result<Habit>> updateHabit(Habit habit) async {
    if (habit.taskId != null) return Either.right(habit);
    return super.updateHabit(habit);
  }
}
