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
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stage L1.4 tests: harden the migration parity boundary before any final
/// history cutover.
///
/// Four jobs, all against the **real** repositories over mocked
/// SharedPreferences so every assertion is about what persisted:
///
///  1. the parity gate proves, per eligible habit, that its Task holds the
///     deterministic identity, the right status/archive state, the L1.3
///     capability values, the schedule, the link, and all of its history;
///  2. the dangling-`taskId` recovery path is exercised across launches and
///     never fabricates duplicates;
///  3. repeated migration across many launches is idempotent and data-safe;
///  4. failure/crash injection at each write boundary leaves the marker absent
///     and the install retryable, and moves the marker only after full
///     verification.
///
/// The parity-quarantine hold and the L1.3 capability bridge are preserved
/// unchanged: this stage detects and reports, it does not rewrite the deferred
/// repair workflow, and it does not delete anything.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService database;

  /// A fresh repository pair over the same persisted store, which is what a
  /// relaunch looks like.
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
  /// admits it, carrying every field the boundary cares about.
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
    DateTime? dueAt,
    DateTime? snoozedUntil,
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
  Future<void> seedTask(
    String taskId,
    Habit habit, {
    List<String> stripKeys = const [],
    Map<String, Object> addKeys = const {},
  }) async {
    final repo = TaskRepositoryImpl(database);
    await repo.createTask(Task.create(
      title: habit.title,
      category: habit.category,
      schedule: habit.recurringSchedule,
    ).copyWith(id: taskId, createdAt: habit.createdAt));
    final stored = database.getJsonList(DatabaseService.tasksKey)!;
    for (final task in stored) {
      if (task['id'] != taskId) continue;
      for (final key in stripKeys) {
        task.remove(key);
      }
      task.addAll(addKeys);
    }
    await database.setJsonList(DatabaseService.tasksKey, stored);
  }

  /// Simulates a Task written by the Stage L0 build: deterministic migrated id,
  /// no capability keys at all.
  Future<void> seedL0Task(String taskId, Habit habit) async {
    await seedTask(taskId, habit, stripKeys: [
      'targetCount',
      'targetDurationMinutes',
      'cue',
      'timeOfDay',
      'streakFreezesUsed'
    ], addKeys: const {});
  }

  /// Simulates a Task an interrupted run left half-written: capability keys
  /// present but incomplete, exercising the "malformed capability data" path.
  Future<void> seedPartialCapabilitiesTask(
    String taskId,
    Habit habit, {
    Map<String, Object> addKeys = const {},
  }) async {
    await seedTask(taskId, habit,
        stripKeys: [
          'targetDurationMinutes',
          'cue',
          'timeOfDay',
          'streakFreezesUsed'
        ],
        addKeys: addKeys);
  }

  Future<Habit> reloadHabit(String id) async =>
      (await HabitRepositoryImpl(database).getHabitById(id)).right!;

  Future<Task> reloadTask(String id) async =>
      (await TaskRepositoryImpl(database).getTaskById(id)).right!;

  Future<List<HabitCompletion>> persistedCompletions() async {
    final all = await HabitRepositoryImpl(database).getAllCompletions();
    return all.fold((_) => const <HabitCompletion>[], (r) => r);
  }

  Future<List<HabitCompletion>> taskRowsFor(String taskId,
          [List<HabitCompletion>? rows]) async =>
      (rows ?? await persistedCompletions())
          .where((c) => c.itemId == taskId && c.itemType == 'task')
          .toList();

  ({int current, int longest, int total}) countersOf(Habit h) => (
        current: h.currentStreak,
        longest: h.longestStreak,
        total: h.totalCompletions,
      );

  group('1. the parity gate proves each boundary guarantee', () {
    test('every guarantee is asserted for a fully-customised migration',
        () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(
        title: 'Stretch',
        category: 'Health',
        completions: 2,
        frequency: 'Custom',
        customWeekdays: [1, 3, 5],
        projectId: 'proj_1',
        goalId: 'goal_1',
        targetCount: 3,
        targetDurationMinutes: 25,
        cue: 'After coffee',
        timeOfDay: 'Evening',
        streakFreezesUsed: 2,
        dueAt: DateTime(2026, 6, 1, 9),
        snoozedUntil: DateTime(2026, 6, 3, 9),
      );

      final outcome = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([habit.id]))
          .single;
      final v = outcome.verification;

      expect(v.isVerified, isTrue, reason: v.failures.join('; '));
      expect(v.taskExists, isTrue);
      expect(v.taskIsRecurring, isTrue);
      expect(v.schedulePreserved, isTrue);
      expect(v.projectIdPreserved, isTrue);
      expect(v.goalIdPreserved, isTrue);
      expect(v.archivedStatePreserved, isTrue);
      expect(v.legacyCapabilitiesPreserved, isTrue);
      expect(v.taskCapabilitiesPresent, isTrue);
      expect(v.historyPreserved, isTrue);
      expect(v.historyRowsMissing, 0);
      expect(v.streakCountersPreserved, isTrue);
      expect(v.noDuplicateLogicalTask, isTrue);
      expect(v.deterministicIdentity, isTrue);

      // The persisted Task id is the deterministic one this run may use.
      expect(outcome.taskId, HabitTaskIdentity.taskIdForHabit(habit.id));
    });

    test('a Task this run created must carry the deterministic id', () async {
      final (habitRepo, _) = repos();
      final habit = await eligibleHabit();

      final outcome = (await MigrationService(
                  habitRepo, RenamingCreateTaskRepository(database))
              .migrateHabits([habit.id]))
          .single;

      expect(outcome.verification.deterministicIdentity, isFalse);
      expect(outcome.verification.isVerified, isFalse);
      expect(
        outcome.verification.failures,
        contains(contains('not deterministic')),
      );
    });

    test('the parity gate fails loudly when completions cannot be read',
        () async {
      final (_, taskRepo) = repos();
      await eligibleHabit();

      final service = MigrationService(
        UnreadableCompletionsRepository(database),
        taskRepo,
      );

      await expectLater(
        service.runParityGate(),
        throwsA(isA<StateError>()),
      );
    });

    test('a sabotaged archive state is detected, not accepted', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(archived: true);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);
      await MigrationService(habitRepo, taskRepo).migrateHabits([habit.id]);

      // Someone unarchives the migrated Task behind the migration's back. The
      // legacy habit is still the writer, so this stores a live Task beside an
      // archived habit - which the boundary must report rather than bless.
      final stored = await reloadTask(taskId);
      await TaskRepositoryImpl(database)
          .updateTask(stored.copyWith(status: TaskStatus.todo));

      final (h2, t2) = repos();
      final reverified =
          (await MigrationService(h2, t2).migrateHabits([habit.id])).single;

      expect(reverified.verification.archivedStatePreserved, isFalse);
      expect(reverified.verification.failures,
          contains('archived habit did not produce an archived Task'));
      expect(reverified.verification.isVerified, isFalse);
    });

    test('a sabotaged missing history row is detected and repaired on retry',
        () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(completions: 2);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);
      await MigrationService(habitRepo, taskRepo).migrateHabits([habit.id]);

      // Delete one copied row behind the migration's back.
      final rowsBefore = await taskRowsFor(taskId);
      await HabitRepositoryImpl(database).deleteCompletion(rowsBefore.first.id);

      final (h2, t2) = repos();
      final reverified =
          (await MigrationService(h2, t2).migrateHabits([habit.id])).single;

      // The gap is reported on the first pass and repaired by the same
      // idempotent copy on the retry.
      expect(reverified.verification.historyPreserved, isTrue,
          reason: reverified.verification.failures.join('; '));
      expect(await taskRowsFor(taskId), hasLength(2));
    });
  });

  group('2. dangling taskId recovery', () {
    test('a habit whose Task is gone is recovered deterministically', () async {
      final (habitRepo, _) = repos();
      final habit = await eligibleHabit(completions: 2);
      await habitRepo.updateHabit(habit.copyWith(taskId: 'task_gone'));

      final runner = HabitTaskMigrationRunner(
        migration: MigrationService(repos().$1, repos().$2),
        database: database,
      );
      final first = await runner.runIfRequired();

      expect(first.ran, isTrue);
      expect(first.failed, 0);
      expect(runner.isComplete, isTrue);

      final expectedId = HabitTaskIdentity.taskIdForHabit(habit.id);
      final tasks = (await repos().$2.getAllTasks()).right!;
      expect(tasks, hasLength(1));
      expect(tasks.single.id, expectedId);
      expect((await reloadHabit(habit.id)).taskId, expectedId);
      expect(await taskRowsFor(expectedId), hasLength(2));
    });

    test('recovery is safe across repeated launches', () async {
      final (habitRepo, _) = repos();
      final habit = await eligibleHabit();
      await habitRepo.updateHabit(habit.copyWith(taskId: 'task_gone'));

      await HabitTaskMigrationRunner(
        migration: MigrationService(repos().$1, repos().$2),
        database: database,
      ).runIfRequired();

      final tasksBefore = persistedTasks();
      final habitsBefore = database.getJsonList(DatabaseService.habitsKey);

      // Second launch: marker present; bridge must find one converged Task and
      // write nothing.
      final (h2, t2) = repos();
      final second = await HabitTaskMigrationRunner(
        migration: MigrationService(h2, t2),
        database: database,
      ).runIfRequired();
      final report = await MigrationService(
        HabitRepositoryImpl(database),
        TaskRepositoryImpl(database),
      ).syncTaskCapabilities();

      expect(second.ran, isFalse);
      expect(report.checked, 1);
      expect(report.verified, 1);
      expect(report.updated, 0);
      expect(report.failed, 0);
      expect(persistedTasks(), tasksBefore);
      expect(database.getJsonList(DatabaseService.habitsKey), habitsBefore);
    });

    test('recovery adopts an orphan Task instead of fabricating one', () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(title: 'Jog');
      await habitRepo.updateHabit(habit.copyWith(taskId: 'task_gone'));

      // Two pre-existing orphan Tasks from an older attempt, plus the dead link.
      for (final id in ['task_orphan_a', 'task_orphan_b']) {
        await taskRepo.createTask(Task.create(
          title: habit.title,
          category: habit.category,
          schedule: habit.recurringSchedule,
        ).copyWith(id: id, createdAt: habit.createdAt));
      }

      final outcome = (await MigrationService(habitRepo, taskRepo)
              .migrateHabits([habit.id]))
          .single;

      // The dead link is cleared (which outranks the adoption label in the
      // state machine), the lowest-id orphan is adopted, the other is reported -
      // never a third Task, never an auto-delete.
      expect(outcome.state, MigrationState.recoveredDanglingLink);
      expect(outcome.identitySource, MigrationIdentitySource.logicalAdoption);
      expect(outcome.taskId, 'task_orphan_a');
      expect(outcome.duplicateTaskIds, ['task_orphan_b']);
      expect(outcome.verification.isVerified, isTrue,
          reason: outcome.verification.failures.join('; '));
      expect((await taskRepo.getAllTasks()).right, hasLength(2));
    });

    test('a Task with incomplete capability data is repaired, not trusted',
        () async {
      final (habitRepo, _) = repos();
      final habit = await eligibleHabit(
          targetCount: 3, timeOfDay: 'Evening', completions: 2);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);
      await habitRepo.updateHabit(habit.copyWith(taskId: taskId));
      await seedPartialCapabilitiesTask(taskId, habit,
          addKeys: {'targetCount': 3});

      // Already-linked, so the state machine labels it alreadyMigrated - but
      // the per-habit capability sync must still complete the malformed record.
      final outcome = (await MigrationService(repos().$1, repos().$2)
              .migrateHabits([habit.id]))
          .single;

      expect(outcome.state, MigrationState.alreadyMigrated);
      expect(outcome.verification.isVerified, isTrue,
          reason: outcome.verification.failures.join('; '));
      final task = await reloadTask(taskId);
      expect(task.timeOfDay, 'Evening');
      expect(LegacyHabitCapabilities.fromTask(task),
          LegacyHabitCapabilities.fromHabit(habit));
    });
  });

  group('3. repeated migration is idempotent and data-safe', () {
    test('after the first run every later launch rewrites nothing', () async {
      await eligibleHabit(title: 'A', completions: 2);
      await eligibleHabit(title: 'B', archived: true, completions: 1);

      final runner = HabitTaskMigrationRunner(
        migration: MigrationService(repos().$1, repos().$2),
        database: database,
      );
      final first = await runner.runIfRequired();
      expect(first.ran, isTrue);
      expect(first.migratedCount, 2);
      expect(runner.isComplete, isTrue);

      final habitsAfter = database.getJsonList(DatabaseService.habitsKey);
      final tasksAfter = persistedTasks();
      final completionsAfter = database.getJsonList('habit_completions');

      for (var launch = 0; launch < 2; launch++) {
        final (h, t) = repos();
        final result = await HabitTaskMigrationRunner(
          migration: MigrationService(h, t),
          database: database,
        ).runIfRequired();
        expect(result.ran, isFalse,
            reason: 'marker short-circuits launch $launch');
        expect(database.getJsonList(DatabaseService.habitsKey), habitsAfter);
        expect(persistedTasks(), tasksAfter);
        expect(database.getJsonList('habit_completions'), completionsAfter);
      }
    });

    test('mixed migrated and unmigrated habits: only the gap is filled',
        () async {
      final (habitRepo, taskRepo) = repos();
      final migrated = await eligibleHabit(title: 'A');
      final unmigrated = await eligibleHabit(title: 'B', completions: 2);
      await MigrationService(habitRepo, taskRepo).migrateHabits([migrated.id]);

      final tasksBefore = persistedTasks();

      final result = await HabitTaskMigrationRunner(
        migration: MigrationService(repos().$1, repos().$2),
        database: database,
      ).runIfRequired();

      expect(result.ran, isTrue);
      expect(result.migratedCount, 1);
      final taskIds = persistedTasks().map((t) => t['id']).toList();
      expect(
          taskIds, contains(HabitTaskIdentity.taskIdForHabit(unmigrated.id)));
      expect(taskIds, contains(HabitTaskIdentity.taskIdForHabit(migrated.id)));
      // A's Task was not rewritten by the run that migrated B.
      expect(persistedTask(HabitTaskIdentity.taskIdForHabit(migrated.id)),
          tasksBefore.first);
    });

    test('streak counters, legacy rows and unrelated Tasks all survive',
        () async {
      final (habitRepo, taskRepo) = repos();
      final habit = await eligibleHabit(title: 'Read', completions: 3);
      final before = await reloadHabit(habit.id);
      final countersBefore = countersOf(before);
      final legacyBefore =
          (await habitRepo.getCompletionsForHabit(habit.id)).right!;

      // An unrelated manual Task: nothing may touch it during the migration or
      // the capability bridge.
      final unrelated = Task.create(
        title: 'Manual task',
        projectId: 'proj_x',
        schedule: Recurring(RecurrenceRule.fromFrequency('Daily', [])),
      );
      await taskRepo.createTask(unrelated);
      final unrelatedBefore = persistedTask(unrelated.id);

      await HabitTaskMigrationRunner(
        migration: MigrationService(repos().$1, repos().$2),
        database: database,
      ).runIfRequired();

      final after = await reloadHabit(habit.id);
      expect(countersOf(after), countersBefore);
      final legacyAfter =
          (await HabitRepositoryImpl(database).getCompletionsForHabit(habit.id))
              .right!;
      expect(legacyAfter, legacyBefore,
          reason: 'legacy completion/history must remain intact');

      expect(persistedTask(unrelated.id), unrelatedBefore,
          reason: 'the unrelated Task must be byte-identical');
    });

    test('no duplicate Task or completion rows across any number of runs',
        () async {
      final habit = await eligibleHabit(completions: 3);
      final runner = HabitTaskMigrationRunner(
        migration: MigrationService(repos().$1, repos().$2),
        database: database,
      );
      for (var i = 0; i < 3; i++) {
        final (h, t) = repos();
        await HabitTaskMigrationRunner(
          migration: MigrationService(h, t),
          database: database,
        ).runIfRequired();
      }
      expect(runner.isComplete, isTrue);

      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);
      expect(persistedTasks(), hasLength(1));
      final rows = await taskRowsFor(taskId);
      expect(rows, hasLength(3));
      expect(rows.map((c) => c.id).toSet(), hasLength(3));
    });
  });

  group('4. failure and crash injection', () {
    test('a Task creation failure leaves no Task, no marker, then converges',
        () async {
      final habit = await eligibleHabit(completions: 2);

      final broken = HabitTaskMigrationRunner(
        migration: MigrationService(
          HabitRepositoryImpl(database),
          FailingCreateTaskRepository(database),
        ),
        database: database,
      );
      final failed = await broken.runIfRequired();

      expect(failed.isClean, isFalse);
      expect(failed.failed, 1);
      expect(broken.isComplete, isFalse, reason: 'marker stays absent');
      expect(persistedTasks(), isEmpty, reason: 'no half-created Task');
      // The legacy habit was never written (no link was created), so nothing
      // about it changed either.
      expect((await reloadHabit(habit.id)).taskId, isNull);
      expect(countersOf(await reloadHabit(habit.id)), countersOf(habit));

      final (h2, t2) = repos();
      final healthy = HabitTaskMigrationRunner(
        migration: MigrationService(h2, t2),
        database: database,
      );
      final retry = await healthy.runIfRequired();
      expect(retry.isClean, isTrue, reason: retry.error ?? '');
      expect(healthy.isComplete, isTrue);
      expect(persistedTasks(), hasLength(1));
      expect(await taskRowsFor(HabitTaskIdentity.taskIdForHabit(habit.id)),
          hasLength(2));
    });

    test(
        'a completion copy failure partway through is detected, repairs on '
        'retry without duplicates', () async {
      final habit = await eligibleHabit(completions: 3);

      final broken = HabitTaskMigrationRunner(
        migration: MigrationService(
          FailingCompletionsAfterFirstRepository(database),
          TaskRepositoryImpl(database),
        ),
        database: database,
      );
      final first = await broken.runIfRequired();

      // Migration "succeeded" but verification saw two rows never arrive.
      expect(first.unverified, greaterThan(0));
      expect(broken.isComplete, isFalse, reason: 'marker stays absent');

      final (h2, t2) = repos();
      final healthy = HabitTaskMigrationRunner(
        migration: MigrationService(h2, t2),
        database: database,
      );
      final retry = await healthy.runIfRequired();
      expect(retry.isClean, isTrue, reason: retry.error ?? '');
      expect(healthy.isComplete, isTrue);

      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);
      final rows = await taskRowsFor(taskId);
      expect(rows, hasLength(3),
          reason: 'the first attempt copied one row; the retry must not copy '
              'it again');
      expect(rows.map((c) => c.id).toSet(), hasLength(3));
    });

    test('a marker write failure leaves the install retryable', () async {
      final habit = await eligibleHabit(completions: 2);

      final broken = MarkerWriteFailsRunner(
        migration: MigrationService(repos().$1, repos().$2),
        database: database,
      );
      final first = await broken.runIfRequired();

      expect(first.isClean, isFalse);
      expect(first.error, isNotNull);
      expect(broken.isComplete, isFalse,
          reason: 'a marker that did not land reads as unmigrated');

      final (h2, t2) = repos();
      final healthy = HabitTaskMigrationRunner(
        migration: MigrationService(h2, t2),
        database: database,
      );
      final retry = await healthy.runIfRequired();
      expect(retry.isClean, isTrue, reason: retry.error ?? '');
      expect(healthy.isComplete, isTrue);
      expect(persistedTasks(), hasLength(1),
          reason: 'the retry must not duplicate the already-written Task');
      expect(await taskRowsFor(HabitTaskIdentity.taskIdForHabit(habit.id)),
          hasLength(2));
    });

    test('a capability sync failure on a later launch is contained', () async {
      final (habitRepo, _) = repos();
      final habit = await eligibleHabit(targetCount: 3);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);
      await habitRepo.updateHabit(habit.copyWith(taskId: taskId));
      await seedL0Task(taskId, habit);
      await database.setJson('habit_task_migration', {'version': 1});

      // Broken task update path: the bridge's write fails, the runner must not
      // crash, and the marker must stay intact.
      final broken = HabitTaskMigrationRunner(
        migration: MigrationService(
          HabitRepositoryImpl(database),
          FailingUpdateTaskRepository(database),
        ),
        database: database,
      );
      final result = await broken.runIfRequired();
      expect(result.ran, isFalse);
      expect(broken.isComplete, isTrue,
          reason: 'a bridge failure is not a migration failure');

      // The next healthy launch converges without any extra mechanism.
      final (h2, t2) = repos();
      await HabitTaskMigrationRunner(
        migration: MigrationService(h2, t2),
        database: database,
      ).runIfRequired();
      expect(LegacyHabitCapabilities.fromTask(await reloadTask(taskId)),
          LegacyHabitCapabilities.fromHabit(habit));
    });
  });

  group('5. parity quarantine is preserved', () {
    test(
        'quarantined habits do not block the marker and are never claimed '
        'migrated', () async {
      final (habitRepo, _) = repos();
      final good = await eligibleHabit(title: 'Good');
      final bad = await eligibleHabit(title: 'Bad', completions: 0);
      await habitRepo.updateHabit(bad.copyWith(
          currentStreak: 9, longestStreak: 9, totalCompletions: 9));
      final badBefore = await reloadHabit(bad.id);

      final runner = HabitTaskMigrationRunner(
        migration: MigrationService(
            HabitRepositoryImpl(database), TaskRepositoryImpl(database)),
        database: database,
      );
      final result = await runner.runIfRequired();

      expect(result.quarantined, 1);
      expect(result.failed, 0);
      expect(result.isClean, isTrue);
      expect(runner.isComplete, isTrue,
          reason: 'quarantine is a deliberate hold, not a failed write');
      expect((await reloadHabit(good.id)).taskId, isNotNull);
      expect((await reloadHabit(bad.id)).taskId, isNull);
      expect(database.getJson('habit_task_migration')?['quarantined'], 1);

      // The marker does not claim the quarantined habit migrated, and the
      // habit is left byte-identical so a future decision can act on it.
      final badAfter = await reloadHabit(bad.id);
      expect(countersOf(badAfter), countersOf(badBefore));
      expect(badAfter.taskId, isNull);
    });

    test('a quarantined habit stays detectable on a later launch', () async {
      final (habitRepo, _) = repos();
      final bad = await eligibleHabit(title: 'Bad', completions: 0);
      await habitRepo.updateHabit(bad.copyWith(
          currentStreak: 9, longestStreak: 9, totalCompletions: 9));

      await HabitTaskMigrationRunner(
        migration: MigrationService(
            HabitRepositoryImpl(database), TaskRepositoryImpl(database)),
        database: database,
      ).runIfRequired();

      // It still fails the parity gate exactly as before - nothing pretends
      // the divergence resolved itself.
      final report = await MigrationService(
        HabitRepositoryImpl(database),
        TaskRepositoryImpl(database),
      ).runParityGate();
      expect(report.quarantined.map((q) => q.habitId), [bad.id]);
      expect(report.eligible, isEmpty);
    });
  });

  group('6. data-safety assertions', () {
    test('no double counting: habit-scoped days and rows are unchanged',
        () async {
      final habit = await eligibleHabit(completions: 3);
      final legacyBefore =
          (await HabitRepositoryImpl(database).getCompletionsForHabit(habit.id))
              .right!;
      final daysBefore =
          legacyBefore.map((c) => c.completedAt.startOfDay).toSet();

      await HabitTaskMigrationRunner(
        migration: MigrationService(repos().$1, repos().$2),
        database: database,
      ).runIfRequired();

      final all = await persistedCompletions();
      // The copied rows are owner-isolated (habitId null, itemType task).
      expect(await taskRowsFor(HabitTaskIdentity.taskIdForHabit(habit.id), all),
          hasLength(3));
      final legacyAfter =
          (await HabitRepositoryImpl(database).getCompletionsForHabit(habit.id))
              .right!;
      expect(
          legacyAfter.map((c) => c.completedAt.startOfDay).toSet(), daysBefore);
      expect(legacyAfter, hasLength(3));
    });

    test('capability synchronization remains retryable after a failure',
        () async {
      final (habitRepo, _) = repos();
      final habit = await eligibleHabit(targetCount: 3, timeOfDay: 'Evening');
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);
      await habitRepo.updateHabit(habit.copyWith(taskId: taskId));
      await seedL0Task(taskId, habit);

      final (h, _) = repos();
      final failed =
          await MigrationService(h, FailingUpdateTaskRepository(database))
              .syncTaskCapabilities();
      expect(failed.failed, 1);
      expect(failed.isClean, isFalse);

      final (h2, t2) = repos();
      final retry = await MigrationService(h2, t2).syncTaskCapabilities();
      expect(retry.updated, 1);
      expect(retry.verified, 1);
      expect(retry.failed, 0);
      expect(LegacyHabitCapabilities.fromTask(await reloadTask(taskId)),
          LegacyHabitCapabilities.fromHabit(habit));
    });
  });
}

/// A task repository that renames every created Task, breaking the
/// deterministic-identity guarantee the parity boundary must catch.
class RenamingCreateTaskRepository extends TaskRepositoryImpl {
  RenamingCreateTaskRepository(super.database);

  @override
  Future<Result<Task>> createTask(Task task) async =>
      super.createTask(task.copyWith(id: 'task_hm_renamed'));
}

/// A repository whose completion log cannot be read.
class UnreadableCompletionsRepository extends HabitRepositoryImpl {
  UnreadableCompletionsRepository(super.database);

  @override
  Future<Result<List<HabitCompletion>>> getAllCompletions() async =>
      Either.left(const CacheFailure('storage unavailable'));
}

/// A task repository whose create path always fails.
class FailingCreateTaskRepository extends TaskRepositoryImpl {
  FailingCreateTaskRepository(super.database);

  @override
  Future<Result<Task>> createTask(Task task) async =>
      Either.left(const CacheFailure('disk full'));
}

/// A habit repository whose first completion copy succeeds and every later one
/// fails, simulating a crash in the middle of history copying.
class FailingCompletionsAfterFirstRepository extends HabitRepositoryImpl {
  FailingCompletionsAfterFirstRepository(super.database);

  var _writes = 0;

  @override
  Future<Result<HabitCompletion>> createCompletion(
      HabitCompletion completion) async {
    _writes++;
    if (_writes > 1) {
      return Either.left(const CacheFailure('disk full'));
    }
    return super.createCompletion(completion);
  }
}

/// A task repository whose update path always fails, so the capability write
/// itself is what must be surfaced rather than hidden.
class FailingUpdateTaskRepository extends TaskRepositoryImpl {
  FailingUpdateTaskRepository(super.database);

  @override
  Future<Result<Task>> updateTask(Task task) async =>
      Either.left(const CacheFailure('disk full'));
}

/// A runner whose marker write always throws, proving a marker that did not
/// land leaves the install unmigrated and retryable.
class MarkerWriteFailsRunner extends HabitTaskMigrationRunner {
  MarkerWriteFailsRunner({
    required super.migration,
    required super.database,
  });

  @override
  Future<void> writeMarker(Map<String, dynamic> payload) async {
    throw StateError('marker write failed');
  }
}
