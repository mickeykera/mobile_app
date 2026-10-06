import 'package:ascend/app/widgets/week_strip.dart';
import 'package:ascend/core/database/database.dart';
import 'package:ascend/core/extensions/date_extensions.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/analytics/data/repositories/analytics_repository_impl.dart';
import 'package:ascend/features/habits/data/repositories/habit_repository_impl.dart';
import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/habits/domain/entities/habit_completion.dart';
import 'package:ascend/features/habits/presentation/controllers/habit_controller.dart';
import 'package:ascend/features/progress/domain/services/progress_service.dart';
import 'package:ascend/features/recurring/domain/migration.dart';
import 'package:ascend/features/recurring/domain/recurring_streak.dart';
import 'package:ascend/features/recurring/domain/streak_parity.dart';
import 'package:ascend/features/recurring/domain/task_streak.dart';
import 'package:ascend/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:ascend/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/today/domain/today_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../focus/presentation/focus_controller_test.dart'
    show FakeFocusRepository;
import '../journal/presentation/journal_controller_test.dart'
    show FakeJournalRepository;

/// Stage L1.2 read-path tests.
///
/// ## Why these run against real persistence
///
/// The whole point of the stage is that a migrated habit's history exists in two
/// places at once: the legacy rows the migration preserved, and the Task
/// occurrence rows it copied them into. An in-memory fake holding `Habit` and
/// `HabitCompletion` objects cannot show the copy step, so it cannot show the
/// double count either. Everything here goes through `DatabaseService` over
/// mocked SharedPreferences, runs the real [MigrationService], and then reads the
/// result back the way a screen would.
///
/// Time is pinned through [AppClock] rather than taken from the wall clock, so
/// "today" means the same thing on every run and the heatmap window is stable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const progress = ProgressService();

  /// A pinned "now": a Wednesday, so a Mon/Wed/Fri schedule has days either
  /// side of today to disagree with.
  final now = DateTime(2025, 6, 11, 9);
  final today = now.startOfDay;

  late DatabaseService database;
  late HabitRepositoryImpl habitRepo;
  late TaskRepositoryImpl taskRepo;

  setUp(() async {
    AppClock.debugSetNow(() => now);
    SharedPreferences.setMockInitialValues({});
    database = DatabaseService();
    await database.close();
    await database.initialize();
    habitRepo = HabitRepositoryImpl(database);
    taskRepo = TaskRepositoryImpl(database);
  });

  tearDown(() {
    AppClock.debugResetNow();
  });

  /// Every habit as the repositories read it back right now, straight from
  /// storage rather than from the object this test last wrote.
  Future<List<Habit>> readHabits() async =>
      (await HabitRepositoryImpl(database).getAllHabits(includeArchived: true))
          .getOrElse((_) => const <Habit>[]);

  Future<List<HabitCompletion>> readCompletions() async =>
      (await HabitRepositoryImpl(database).getAllCompletions())
          .getOrElse((_) => const <HabitCompletion>[]);

  Future<List<Task>> readTasks() async =>
      (await TaskRepositoryImpl(database).getAllTasks())
          .getOrElse((_) => const <Task>[]);

  /// Creates a habit whose stored counters agree with its log.
  ///
  /// Counters are built with `copyWithCompletion` in chronological order, so the
  /// stored chain is exactly the one the log reads back - which is the invariant
  /// the migration's parity gate checks before it will convert a habit. Handing
  /// the gate a habit whose counters disagree would simply quarantine it and the
  /// test would measure nothing.
  Future<Habit> habitWithHistory({
    String title = 'Read',
    String category = 'Mind',
    String frequency = 'Daily',
    List<DateTime>? onDays,
  }) async {
    final days = onDays ??
        [
          for (var i = 2; i >= 0; i--)
            today.subtract(Duration(days: i)).add(const Duration(hours: 9)),
        ];

    var habit = Habit.create(
      title: title,
      category: category,
      frequency: frequency,
    );

    for (final day in days) {
      habit = habit.copyWithCompletion(completed: true, completionTime: day);
      await habitRepo.createCompletion(HabitCompletion(
        id: 'seed_${habit.id}_${day.toIso8601String()}',
        habitId: habit.id,
        itemId: habit.id,
        itemType: 'habit',
        completedAt: day,
        count: 1,
      ));
    }

    await habitRepo.createHabit(habit);
    return habit;
  }

  /// A recurring Task standing on its own, with no habit behind it.
  Future<Task> standaloneTask({
    String title = 'Water plants',
    String category = 'Home',
  }) async {
    final task = Task.create(
      title: title,
      category: category,
      schedule: const Recurring(DailyRecurrence()),
    );
    await taskRepo.createTask(task);
    return task;
  }

  /// Writes a Task occurrence row the way the recurring write path does.
  ///
  /// One row per task per day: a second call on the same day returns the row
  /// that is already there rather than adding another.
  Future<void> recordOccurrence(String taskId, DateTime date) => habitRepo
      .recordRecurringTaskOccurrence(taskId: taskId, date: date, count: 1);

  /// Runs the real migration over [habits] and returns them as read back
  /// afterwards, so `taskId` is the persisted value, not an in-memory one.
  Future<List<Habit>> migrate(List<Habit> habits) async {
    final outcomes = await MigrationService(habitRepo, taskRepo)
        .migrateHabits(habits.map((h) => h.id).toList());
    expect(outcomes.map((o) => o.state), everyElement(MigrationState.migrated),
        reason:
            'every fixture habit must convert, or the test measures nothing');
    return readHabits();
  }

  /// The Task id the migration linked a migrated habit to.
  Future<String> taskIdOf(String habitId) async =>
      (await readHabits()).singleWhere((h) => h.id == habitId).taskId!;

  /// Monday of the pinned week. `now` is a Wednesday, so today sits at index 2.
  final monday = today.subtract(const Duration(days: 2));

  group('1. both sides of the bridge use one definition', () {
    test('a migrated habit and its Task report the same streak', () async {
      // Monday and Wednesday: consecutive as a Mon/Wed/Fri schedule, gapped as
      // calendar days. This is the case the two definitions disagreed on, so
      // agreeing is the assertion.
      final habit = await habitWithHistory(
        frequency: 'Weekdays',
        onDays: [
          monday.add(const Duration(hours: 9)),
          today.add(const Duration(hours: 9)),
        ],
      );
      final tasks = await migrate([habit]);
      final completions = await readCompletions();
      final taskId = tasks.single.taskId!;

      expect(
        RecurringStreak.forTaskLog(completions, taskId).currentStreak,
        RecurringStreak.forHabitLog(completions, tasks.single.id).currentStreak,
      );
      // The schedule is not consulted. Monday to Wednesday is one calendar-day
      // chain even though Tuesday carries no occurrence.
      expect(RecurringStreak.forTaskLog(completions, taskId).currentStreak, 1);
    });

    test('TaskStreakComputer is the canonical projection, not its own rule',
        () async {
      final task = await standaloneTask();
      for (final day in [
        today.subtract(const Duration(days: 2)),
        today.subtract(const Duration(days: 1)),
        today,
      ]) {
        await recordOccurrence(task.id, day);
      }
      final completions = await readCompletions();

      expect(
        TaskStreakComputer(completions: completions, task: task).currentStreak,
        RecurringStreak.forTaskLog(completions, task.id).currentStreak,
      );
      expect(
        TaskStreakComputer(completions: completions, task: task).currentStreak,
        3,
      );
    });

    test('HabitLogProjection agrees with the canonical projection', () async {
      final habit = await habitWithHistory();
      final completions = await readCompletions();

      final projection = HabitLogProjection.from(completions, habit.id);
      final canonical = RecurringStreak.forHabitLog(completions, habit.id);

      expect(projection.currentStreak, canonical.currentStreak);
      expect(projection.longestStreak, canonical.longestStreak);
      expect(projection.totalCompletions, canonical.totalCompletedDays);
      expect(projection.compareTo(habit).verdict, ParityVerdict.agrees);
    });
  });

  group('2. taskStreaksByCategory uses the canonical calculation', () {
    test('agrees with the projection, day for day', () async {
      final task = await standaloneTask(category: 'Home');
      for (final day in [
        today.subtract(const Duration(days: 1)),
        today,
      ]) {
        await recordOccurrence(task.id, day);
      }
      final completions = await readCompletions();

      expect(progress.taskStreaksByCategory(await readTasks(), completions),
          {'Home': 2});
      expect(
        progress.taskStreaksByCategory(await readTasks(), completions)['Home'],
        RecurringStreak.forTaskLog(completions, task.id).currentStreak,
      );
    });

    test('an unscheduled Task is left out', () async {
      await taskRepo.createTask(Task.create(title: 'One-off'));
      final task = await standaloneTask();
      await recordOccurrence(task.id, today);

      expect(
        progress.taskStreaksByCategory(
            await readTasks(), await readCompletions()),
        {'Home': 1},
      );
    });

    test('an uncategorised Task is not bucketed anywhere', () async {
      await taskRepo.createTask(Task.create(
        title: 'Unfiled',
        schedule: const Recurring(DailyRecurrence()),
      ));

      expect(
        progress.taskStreaksByCategory(
            await readTasks(), await readCompletions()),
        isEmpty,
      );
    });

    test('the provider resolves the same numbers over real persistence',
        () async {
      final task = await standaloneTask(category: 'Home');
      for (final day in [
        today.subtract(const Duration(days: 1)),
        today,
      ]) {
        await recordOccurrence(task.id, day);
      }

      final container = ProviderContainer(overrides: [
        databaseServiceProvider.overrideWithValue(database),
      ]);
      addTearDown(container.dispose);

      expect(
        await container.read(taskStreaksByCategoryProvider.future),
        {'Home': 2},
      );
    });
  });

  group('3. a migrated habit is never counted twice', () {
    test('the legacy row and its copy are one day, not two', () async {
      await habitWithHistory();
      await migrate([(await readHabits()).single]);

      final completions = await readCompletions();

      // Both halves are physically present. That is the point of the copy.
      expect(completions.where((c) => c.isHabitCompletion), hasLength(3));
      expect(completions.where((c) => c.itemType == 'task'), hasLength(3));

      final heatmap = progress.recurringCompletionHeatmap(
        habits: await readHabits(),
        completions: completions,
        now: now,
      );

      expect(heatmap[today.subtract(const Duration(days: 1))], 1);
      expect(heatmap.values, everyElement(1));
    });

    test('the category streak is the Task-derived one, once', () async {
      final habit = await habitWithHistory(category: 'Mind');
      final migrated = await migrate([habit]);

      expect(
        progress.recurringStreaksByCategory(
          habits: migrated,
          tasks: await readTasks(),
          completions: await readCompletions(),
        ),
        {'Mind': 3},
      );
    });

    test('the frozen counter is ignored, not added to', () async {
      // The stored counter says 3 because that is what it was when migration ran.
      // The Task log is what the recurring write path now maintains, so an
      // occurrence written after the fact is visible through it while the
      // counter never moves.
      final habit = await habitWithHistory(category: 'Mind');
      final migrated = await migrate([habit]);

      await recordOccurrence(migrated.single.taskId!, today);

      expect(
        progress.recurringStreaksByCategory(
          habits: await readHabits(),
          tasks: await readTasks(),
          completions: await readCompletions(),
        ),
        {'Mind': 3},
      );
    });

    test('lifetime completions count a migrated habit once', () async {
      final habit = await habitWithHistory(category: 'Mind');
      final migrated = await migrate([habit]);

      expect(
        progress.recurringCompletionsByCategory(
          habits: migrated,
          tasks: await readTasks(),
          completions: await readCompletions(),
        ),
        {'Mind': 3},
      );
    });

    test('an un-migrated habit keeps its stored counter', () async {
      final habit = await habitWithHistory(category: 'Mind');

      expect(
        progress.recurringStreaksByCategory(
          habits: [habit],
          tasks: await readTasks(),
          completions: await readCompletions(),
        ),
        {'Mind': habit.currentStreak},
      );
    });
  });

  group('4. migrated and un-migrated habits in one dataset', () {
    test('each contributes under its own category, neither doubled', () async {
      final legacy = await habitWithHistory(title: 'Read', category: 'Mind');
      final moved = await habitWithHistory(title: 'Stretch', category: 'Body');
      await migrate([moved]);

      // Only the un-migrated habit comes from a stored counter; the migrated one
      // is re-derived from its Task log.
      expect(
        progress.recurringStreaksByCategory(
          habits: [legacy],
          tasks: await readTasks(),
          completions: await readCompletions(),
        ),
        {'Mind': legacy.currentStreak, 'Body': 3},
      );
    });

    test('a category with no completions reads as zero, not absent', () async {
      final habit = await habitWithHistory(category: 'Mind', onDays: []);
      final untouched = Habit.create(title: 'Journal', category: 'Mind');

      expect(
        progress.recurringCompletionsByCategory(
          habits: [habit, untouched],
          tasks: const [],
          completions: await readCompletions(),
        ),
        {'Mind': 0},
      );
    });

    test('a standalone recurring Task is counted with no habit twin', () async {
      final habit = await habitWithHistory(category: 'Mind');
      final task = await standaloneTask(category: 'Home');
      await recordOccurrence(task.id, today);

      expect(
        progress.recurringStreaksByCategory(
          habits: [habit],
          tasks: await readTasks(),
          completions: await readCompletions(),
        ),
        {'Mind': 3, 'Home': 1},
      );
    });
  });

  group('5. the Analytics screen reads the canonical path', () {
    late AnalyticsRepositoryImpl analytics;

    setUp(() {
      analytics = AnalyticsRepositoryImpl(
        habitRepo,
        taskRepo,
        FakeFocusRepository(),
        FakeJournalRepository(),
      );
    });

    test('category streaks come from the Task log after migration', () async {
      final habit = await habitWithHistory(category: 'Mind');
      await migrate([habit]);

      // Two more occurrences. The frozen counter knows nothing about them.
      await recordOccurrence(
          await taskIdOf(habit.id), today.add(const Duration(days: 1)));
      await recordOccurrence(
          await taskIdOf(habit.id), today.add(const Duration(days: 2)));

      final data = (await analytics.getHabitStreaksByCategory())
          .getOrElse((_) => const <String, int>{});

      expect(data, {'Mind': 5});
    });

    test('the heatmap keeps counting a migrated habit after migration',
        () async {
      final habit = await habitWithHistory();
      final migrated = await migrate([habit]);

      final before = (await analytics.getHabitHeatmap(weeks: 12))
          .getOrElse((_) => const <DateTime, int>{});
      expect(before[today.subtract(const Duration(days: 1))], 1);

      // A day the migration never copied: written only as a Task row.
      await recordOccurrence(migrated.single.taskId!, today);

      final after = (await analytics.getHabitHeatmap(weeks: 12))
          .getOrElse((_) => const <DateTime, int>{});
      expect(after[today], 1);
      expect(after[today.subtract(const Duration(days: 1))], 1);
    });

    test('lifetime category completions do not double across the bridge',
        () async {
      final habit = await habitWithHistory(category: 'Mind');
      await migrate([habit]);

      final result = await analytics.getHabitCompletionsByCategory();

      expect(result.getOrElse((_) => const <String, int>{}), {'Mind': 3});
    });

    test('a windowed read counts the log, so both halves stay single',
        () async {
      final habit = await habitWithHistory();
      await migrate([habit]);

      final result = await analytics.getHabitCompletionsByCategory(
        startDate: monday,
        endDate: today,
      );

      expect(result.getOrElse((_) => const <String, int>{}), {'Mind': 3});
    });

    test('an un-migrated dataset is unchanged by any of this', () async {
      await habitWithHistory(title: 'Read', category: 'Mind');
      await habitWithHistory(title: 'Stretch', category: 'Body');

      final streaks = (await analytics.getHabitStreaksByCategory())
          .getOrElse((_) => const <String, int>{});
      final completions = (await analytics.getHabitCompletionsByCategory())
          .getOrElse((_) => const <String, int>{});

      expect(streaks, {'Mind': 3, 'Body': 3});
      expect(completions, {'Mind': 3, 'Body': 3});
    });

    test('an empty install reads as empty rather than throwing', () async {
      final streaks = (await analytics.getHabitStreaksByCategory())
          .getOrElse((_) => const <String, int>{});
      final heatmap = (await analytics.getHabitHeatmap())
          .getOrElse((_) => const <DateTime, int>{});

      expect(streaks, isEmpty);
      expect(heatmap, isEmpty);
    });
  });

  group('6. the Today screen counts a migrated habit once', () {
    test('the week total does not double the copied history', () async {
      final habit = await habitWithHistory();
      final migrated = await migrate([habit]);

      expect(
        weekCompletionCount(
          reference: today,
          habits: migrated,
          completions: await readCompletions(),
        ),
        3,
      );
    });

    test('without the habit list a Task row is dropped, not guessed at',
        () async {
      await habitWithHistory();
      await migrate([(await readHabits()).single]);

      // Documented fallback: with nothing to resolve a Task row against it has
      // no owner, and a Task belonging to no habit is not a habit-day. Counting
      // it under its Task id would be the honest-looking wrong answer, since the
      // two halves of a migrated habit would then read as two.
      expect(
        weekCompletionCount(
            reference: today, completions: await readCompletions()),
        3,
      );
    });

    test('the week strip marks a migrated habit done on a Task-only day',
        () async {
      final habit = await habitWithHistory(
          onDays: [monday.add(const Duration(hours: 9))]);
      final migrated = await migrate([habit]);
      await recordOccurrence(migrated.single.taskId!, today);

      final states = weekDayStates(
        reference: today,
        habits: migrated,
        completions: await readCompletions(),
      );

      expect(states[2], WeekDayState.complete);
    });

    test('the header streak is the Task-derived one, not the frozen counter',
        () async {
      // Three days ending yesterday, so the frozen counter is 3 and today's
      // occurrence is the first thing the log can see that the counter cannot.
      final habit = await habitWithHistory(
        category: 'Mind',
        onDays: [
          for (var i = 3; i >= 1; i--)
            today.subtract(Duration(days: i)).add(const Duration(hours: 9)),
        ],
      );
      final migrated = await migrate([habit]);
      await recordOccurrence(migrated.single.taskId!, today);

      expect(migrated.single.currentStreak, 3);
      expect(bestCurrentStreak(migrated, await readCompletions()), 4);
    });

    test('an archived migrated habit is not the headline', () async {
      final habit = await habitWithHistory();
      final migrated = await migrate([habit]);
      final archived = migrated.single.copyWith(isArchived: true);

      expect(bestCurrentStreak([archived], await readCompletions()), 0);
    });

    test('an un-migrated streak still comes from the stored counter', () async {
      final habit = await habitWithHistory();

      expect(bestCurrentStreak([habit], await readCompletions()), 3);
      expect(bestCurrentStreak(const []), 0);
    });
  });

  group('7. the Habits hero measures one consistent set', () {
    test('progress ignores a migrated Task row without the ownership map',
        () async {
      final habit = await habitWithHistory(onDays: []);
      final migrated = await migrate([habit]);
      await recordOccurrence(migrated.single.taskId!, today);

      final completions = await readCompletions();

      // Unresolved: the occurrence row carries no habitId, so the migrated
      // habit looks undone.
      expect(
        HabitController.progressFor(habits: migrated, completions: completions),
        0.0,
      );
      expect(
        HabitController.progressFor(
          habits: migrated,
          completions: completions,
          taskIdToHabitId: ProgressService.habitIdByTaskId(migrated),
        ),
        1.0,
      );
    });

    test('a standalone Task row beside a habit does not inflate it', () async {
      final habit = await habitWithHistory();
      final task = await standaloneTask(category: 'Home');
      await recordOccurrence(task.id, today);

      // The Task belongs to no habit, so it is not a habit day and must not
      // count toward this habit's progress.
      expect(
        HabitController.progressFor(
          habits: [habit],
          completions: await readCompletions(),
        ),
        1.0,
      );
    });
  });

  group('8. longest streak stays the stored high-water mark', () {
    test('the migration leaves it untouched', () async {
      final habit = await habitWithHistory();
      final stored = habit.longestStreak;

      final migrated = await migrate([habit]);

      expect(migrated.single.longestStreak, stored);
      expect(migrated.single.longestStreak, 3);
    });

    test('the canonical read reports longest without writing it back',
        () async {
      final habit = await habitWithHistory();
      final migrated = await migrate([habit]);
      final before = (await readHabits()).single.longestStreak;

      // Reading it is a pure projection. It must not touch storage.
      final derived = RecurringStreak.forTaskLog(
        await readCompletions(),
        migrated.single.taskId!,
      ).longestStreak;

      expect(derived, 3);
      expect((await readHabits()).single.longestStreak, before);
    });

    test('a derived longest is not a substitute for the stored one', () async {
      // Un-completing today shortens the log but not the stored mark, because
      // the run was achieved. Reading the log cannot reproduce that, which is
      // exactly why the two are not interchangeable.
      final habit = await habitWithHistory();
      final stored = habit.longestStreak;
      final withoutToday = (await readCompletions())
          .where((c) => c.completedAt.startOfDay != today)
          .toList();

      expect(
        RecurringStreak.forHabitLog(withoutToday, habit.id).longestStreak,
        lessThan(stored),
      );
      expect(stored, 3);
    });
  });

  group('9. the legacy read paths are untouched', () {
    test('habit-scoped repository reads still skip Task rows', () async {
      // L0's guarantee, restated because L1.2 rewires the reads around it.
      final habit = await habitWithHistory();
      await migrate([habit]);

      final rows = (await habitRepo.getCompletionsForHabit(habit.id))
          .getOrElse((_) => const <HabitCompletion>[]);

      expect(rows, hasLength(3));
      expect(rows.every((r) => r.isHabitCompletion), isTrue);
    });

    test('the parity gate still passes for an un-migrated dataset', () async {
      await habitWithHistory(title: 'Read', category: 'Mind');
      await habitWithHistory(title: 'Stretch', category: 'Body');

      final report = parityReportFor(
        habits: await readHabits(),
        completions: await readCompletions(),
      );

      expect(report, hasLength(2));
      expect(divergentParities(report), isEmpty);
    });

    test('the declared semantics delta names both definitions', () {
      // The migration's own assertion: the difference is stated, not applied
      // silently. Both words stay because the delta is what it reconciles.
      expect(kStreakSemanticsDelta, contains('day-consecutive'));
      expect(kStreakSemanticsDelta, contains('scheduled-consecutive'));
    });
  });

  group('10. boundaries', () {
    test('a chain across a month boundary is one streak', () async {
      final task = await standaloneTask(category: 'Home');
      for (final day in [
        DateTime(2025, 5, 31),
        DateTime(2025, 6, 1),
      ]) {
        await recordOccurrence(task.id, day);
      }

      expect(
        progress.taskStreaksByCategory(
            await readTasks(), await readCompletions()),
        {'Home': 2},
      );
    });

    test('the day on the heatmap window edge is counted', () async {
      final habit = await habitWithHistory();
      await migrate([habit]);
      final edge = now.subtract(const Duration(days: 7 * 12));

      await recordOccurrence(await taskIdOf(habit.id), edge);

      final heatmap = progress.recurringCompletionHeatmap(
        habits: await readHabits(),
        completions: await readCompletions(),
        weeks: 12,
        now: now,
      );

      expect(heatmap[edge.startOfDay], 1);
    });

    test('a day past the heatmap window is not counted', () async {
      final habit = await habitWithHistory();
      await migrate([habit]);

      await recordOccurrence(
        await taskIdOf(habit.id),
        now.subtract(const Duration(days: 7 * 12 + 1)),
      );

      final heatmap = progress.recurringCompletionHeatmap(
        habits: await readHabits(),
        completions: await readCompletions(),
        weeks: 12,
        now: now,
      );

      expect(heatmap[now.subtract(const Duration(days: 7 * 12 + 1)).startOfDay],
          isNull);
      // The days inside the window are untouched by the one outside it.
      expect(heatmap[today], 1);
      expect(heatmap.values, everyElement(1));
    });

    test('an empty log reads as zero everywhere, not as an error', () {
      expect(progress.taskStreaksByCategory(const [], const []), isEmpty);
      expect(
        progress.recurringStreaksByCategory(
          habits: const [],
          tasks: const [],
          completions: const [],
        ),
        isEmpty,
      );
      expect(
        progress.recurringCompletionHeatmap(
          habits: const [],
          completions: const [],
          now: now,
        ),
        isEmpty,
      );
      expect(progress.completedHabitIdsByDay(const []), isEmpty);
    });

    test('a deleted Task stops contributing to its category', () async {
      final task = await standaloneTask(category: 'Home');
      await recordOccurrence(task.id, today);
      expect(
        progress.taskStreaksByCategory(
            await readTasks(), await readCompletions()),
        {'Home': 1},
      );

      await taskRepo.deleteTask(task.id);

      // The rows outlive the Task. With no Task to attribute them to there is no
      // category to put them in, so they are dropped rather than guessed at.
      expect(
        progress.taskStreaksByCategory(
            await readTasks(), await readCompletions()),
        isEmpty,
      );
    });
  });
}
