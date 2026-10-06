import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/habits/domain/entities/habit_completion.dart';
import 'package:ascend/features/habits/presentation/providers/habit_providers.dart';
import 'package:ascend/features/recurring/domain/recurring_work.dart';
import 'package:ascend/features/recurring/domain/streak_parity.dart';
import 'package:ascend/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';
import 'package:ascend/features/tasks/presentation/providers/task_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../habits/presentation/habit_controller_test.dart'
    show FakeHabitRepository;
import '../../tasks/presentation/task_controller_test.dart'
    show FakeTaskRepository;

Habit _habit({
  String id = 'habit_1',
  String? projectId,
  bool isArchived = false,
  int currentStreak = 0,
  int longestStreak = 0,
  int totalCompletions = 0,
}) =>
    Habit(
      id: id,
      title: 'Habit $id',
      description: '',
      category: 'Health',
      frequency: 'Daily',
      customWeekdays: const [],
      timeOfDay: 'Morning',
      targetCount: 1,
      targetDuration: const Duration(minutes: 10),
      cue: '',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      sortOrder: 0,
      isArchived: isArchived,
      streakFreezesUsed: 0,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalCompletions: totalCompletions,
      projectId: projectId,
    );

Task _task({
  String id = 'task_1',
  String? projectId,
  TaskSchedule schedule = const Recurring(DailyRecurrence()),
}) =>
    Task(
      id: id,
      title: 'Task $id',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      sortOrder: 0,
      status: TaskStatus.todo,
      schedule: schedule,
      projectId: projectId,
    );

HabitCompletion _completion(String habitId, DateTime day) => HabitCompletion(
      id: 'cmp_${habitId}_${day.day}',
      habitId: habitId,
      itemType: 'habit',
      completedAt: DateTime(day.year, day.month, day.day, 12),
      count: 1,
    );

ProviderContainer _boot({
  List<Habit> habits = const [],
  List<HabitCompletion> completions = const [],
  List<Task> tasks = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      habitRepositoryProvider.overrideWithValue(
        FakeHabitRepository(habits: habits, completions: completions),
      ),
      taskRepositoryProvider.overrideWithValue(FakeTaskRepository(tasks)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('recurringWorkProvider', () {
    test('reads habits and recurring tasks from both sources', () async {
      final container = _boot(
        habits: [_habit(id: 'habit_1')],
        tasks: [_task(id: 'task_1')],
      );
      await container.read(taskControllerProvider.notifier).refresh();
      await container.read(habitControllerProvider.notifier).refresh();

      final work = container.read(recurringWorkProvider);
      expect(work.map((w) => w.source),
          [RecurringSource.habit, RecurringSource.recurringTask]);
    });

    test('excludes archived habits and archived tasks', () async {
      final container = _boot(
        habits: [
          _habit(id: 'habit_live'),
          _habit(id: 'habit_archived', isArchived: true),
        ],
        tasks: [_task(id: 'task_live')],
      );
      await container.read(taskControllerProvider.notifier).refresh();
      await container.read(habitControllerProvider.notifier).refresh();

      expect(
        container.read(recurringWorkProvider).map((w) => w.id),
        ['habit_live', 'task_live'],
      );
    });

    test('counts each source', () async {
      final container = _boot(
        habits: [_habit(id: 'habit_1'), _habit(id: 'habit_2')],
        tasks: [_task(id: 'task_1')],
      );
      await container.read(taskControllerProvider.notifier).refresh();
      await container.read(habitControllerProvider.notifier).refresh();

      expect(container.read(recurringSourceCountsProvider), {
        RecurringSource.habit: 2,
        RecurringSource.recurringTask: 1,
      });
    });

    test('filters to one project across both sources', () async {
      final container = _boot(
        habits: [
          _habit(id: 'habit_p1', projectId: 'p1'),
          _habit(id: 'habit_p2', projectId: 'p2'),
        ],
        tasks: [
          _task(id: 'task_p1', projectId: 'p1'),
          _task(id: 'task_inbox'),
        ],
      );
      await container.read(taskControllerProvider.notifier).refresh();
      await container.read(habitControllerProvider.notifier).refresh();

      expect(
        container.read(recurringWorkForProjectProvider('p1')).map((w) => w.id),
        ['habit_p1', 'task_p1'],
      );
      expect(container.read(recurringWorkForProjectProvider('nope')), isEmpty);
    });
  });

  group('streakParityReportProvider', () {
    test('agrees for every habit whose log is complete', () async {
      final days = [
        for (var i = 0; i < 3; i++) DateTime(2026, 3, 18 + i),
      ];
      var habit = _habit();
      for (final day in days) {
        habit = habit.copyWithCompletion(
          completed: true,
          completionTime: DateTime(day.year, day.month, day.day, 9),
        );
      }

      final container = _boot(
        habits: [habit],
        completions: [for (final d in days) _completion('habit_1', d)],
      );
      await container.read(habitControllerProvider.notifier).refresh();

      final report = await container.read(streakParityReportProvider.future);
      expect(report, hasLength(1));
      expect(report.single.verdict, ParityVerdict.agrees);
      expect(report.single.isConsistent, isTrue);
      expect(
          await container.read(divergentStreakParityProvider.future), isEmpty);
    });

    test('surfaces the habit whose counters and log disagree', () async {
      final container = _boot(
        habits: [
          _habit(
              id: 'habit_ok',
              currentStreak: 2,
              longestStreak: 2,
              totalCompletions: 2),
          _habit(
              id: 'habit_bad',
              currentStreak: 7,
              longestStreak: 7,
              totalCompletions: 7),
        ],
        completions: [
          _completion('habit_ok', DateTime(2026, 3, 20)),
          _completion('habit_ok', DateTime(2026, 3, 19)),
        ],
      );
      await container.read(habitControllerProvider.notifier).refresh();

      final report = await container.read(streakParityReportProvider.future);
      expect(report.map((p) => p.isConsistent), [true, false]);
      expect(report.last.verdict, ParityVerdict.counterAheadOfLog);

      final divergent =
          await container.read(divergentStreakParityProvider.future);
      expect(divergent.map((p) => p.habitId), ['habit_bad']);
    });

    test('reads the whole log, not a window', () async {
      // A habit whose history reaches back past any recent range still has to be
      // reported as consistent; parity over a partial log would call it divergent.
      final old = DateTime(2025, 1, 5);
      // Counters built by the real write path from a single completion.
      final habit = _habit(id: 'habit_old')
          .copyWithCompletion(completed: true, completionTime: old);

      final container = _boot(
        habits: [habit],
        completions: [_completion('habit_old', old)],
      );
      await container.read(habitControllerProvider.notifier).refresh();

      final report = await container.read(streakParityReportProvider.future);
      expect(report.single.verdict, ParityVerdict.agrees);
      expect(report.single.loggedTotalCompletions, 1);
    });

    test('is empty when there are no habits', () async {
      final container = _boot();
      await container.read(habitControllerProvider.notifier).refresh();

      expect(await container.read(streakParityReportProvider.future), isEmpty);
    });
  });
}
