import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/recurring/domain/recurring_work.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';
import 'package:flutter_test/flutter_test.dart';

Habit _habit({
  String id = 'habit_1',
  String title = 'Read',
  String frequency = 'Daily',
  List<int> customWeekdays = const [],
  String? projectId,
  String? goalId,
  bool isArchived = false,
  DateTime? lastCompletedAt,
}) =>
    Habit(
      id: id,
      title: title,
      description: 'notes',
      category: 'Health',
      frequency: frequency,
      customWeekdays: customWeekdays,
      timeOfDay: 'Morning',
      targetCount: 1,
      targetDuration: const Duration(minutes: 10),
      cue: '',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      sortOrder: 0,
      isArchived: isArchived,
      streakFreezesUsed: 0,
      currentStreak: 0,
      longestStreak: 0,
      totalCompletions: 0,
      projectId: projectId,
      goalId: goalId,
      lastCompletedAt: lastCompletedAt,
    );

Task _task({
  String id = 'task_1',
  String title = 'Water plants',
  TaskSchedule schedule = const Recurring(DailyRecurrence()),
  String? projectId,
  String? goalId,
  bool archived = false,
  DateTime? completedAt,
  int sortOrder = 0,
}) =>
    Task(
      id: id,
      title: title,
      description: 'desc',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      sortOrder: sortOrder,
      status: archived
          ? TaskStatus.archived
          : (completedAt == null ? TaskStatus.todo : TaskStatus.done),
      schedule: schedule,
      projectId: projectId,
      goalId: goalId,
      completedAt: completedAt,
    );

void main() {
  group('RecurringWork.fromHabit', () {
    test('projects a habit through the shared schedule vocabulary', () {
      final work = RecurringWork.fromHabit(_habit());

      expect(work.source, RecurringSource.habit);
      expect(work.schedule, isA<Recurring>());
      expect(work.schedule.rule, isA<DailyRecurrence>());
      expect(work.id, 'habit_1');
      expect(work.title, 'Read');
    });

    test('carries the flat frequency strings into a rule', () {
      // The whole reason conversion is a codec change and not a redesign.
      expect(
        RecurringWork.fromHabit(_habit(frequency: 'Weekdays')).schedule.rule,
        isA<WeekdayRecurrence>(),
      );
      expect(
        RecurringWork.fromHabit(_habit(frequency: 'Weekends')).schedule.rule,
        isA<WeekendRecurrence>(),
      );
      expect(
        RecurringWork.fromHabit(_habit(
          frequency: 'Custom',
          customWeekdays: const [1, 3, 5],
        )).schedule.rule,
        isA<CustomRecurrence>(),
      );
    });

    test('carries the hierarchy links through unchanged', () {
      final work = RecurringWork.fromHabit(
        _habit(projectId: 'proj_1', goalId: 'goal_1'),
      );

      expect(work.projectId, 'proj_1');
      expect(work.goalId, 'goal_1');
    });

    test('reports its last completion and that occurrences are recorded', () {
      final when = DateTime(2026, 3, 20, 8);
      final work = RecurringWork.fromHabit(_habit(lastCompletedAt: when));

      expect(work.lastCompletedAt, when);
      expect(work.occurrenceRecorded, isTrue);
    });
  });

  group('RecurringWork.fromTask', () {
    test('projects a recurring task', () {
      final work = RecurringWork.fromTask(_task());

      expect(work, isNotNull);
      expect(work!.source, RecurringSource.recurringTask);
      expect(work.schedule, isA<Recurring>());
    });

    test('returns null for a one-off task', () {
      // "Repeats" has to mean repeats: folding Once and Unscheduled in would make
      // the shape answer "what does the user intend to do again" with everything.
      expect(
        RecurringWork.fromTask(_task(schedule: Once(DateTime(2026, 3, 20)))),
        isNull,
      );
    });

    test('returns null for an unscheduled task', () {
      expect(
          RecurringWork.fromTask(_task(schedule: const Unscheduled())), isNull);
    });

    test('cannot point at a recorded occurrence, even when marked done', () {
      // A recurring task records an occurrence by flipping its own status to
      // done, which leaves no history. Reporting completedAt here would invite a
      // caller to read "done" as "has a log", which is the assumption Stage G
      // exists to keep honest.
      final task = _task(completedAt: DateTime(2026, 3, 20, 9));

      expect(task.status, TaskStatus.done);
      final work = RecurringWork.fromTask(task)!;
      expect(work.lastCompletedAt, isNull);
      expect(work.occurrenceRecorded, isFalse);
    });
  });

  group('recurringWorkFrom', () {
    test('reads both sources into one list', () {
      final all = recurringWorkFrom(
        habits: [_habit(id: 'habit_1')],
        tasks: [_task(id: 'task_1')],
      );

      expect(all.map((w) => w.source), [
        RecurringSource.habit,
        RecurringSource.recurringTask,
      ]);
    });

    test('excludes archived work unless asked for it', () {
      final habits = [
        _habit(id: 'habit_live'),
        _habit(id: 'habit_archived', isArchived: true),
      ];
      final tasks = [
        _task(id: 'task_live'),
        _task(id: 'task_archived', archived: true),
      ];

      expect(
        recurringWorkFrom(habits: habits, tasks: tasks).map((w) => w.id),
        ['habit_live', 'task_live'],
      );
      expect(
        recurringWorkFrom(habits: habits, tasks: tasks, includeArchived: true)
            .map((w) => w.id),
        ['habit_live', 'habit_archived', 'task_live', 'task_archived'],
      );
    });

    test('drops one-off and unscheduled tasks', () {
      final all = recurringWorkFrom(
        habits: const [],
        tasks: [
          _task(id: 'task_recurring'),
          _task(id: 'task_once', schedule: Once(DateTime(2026, 3, 20))),
          _task(id: 'task_unscheduled', schedule: const Unscheduled()),
        ],
      );

      expect(all.map((w) => w.id), ['task_recurring']);
    });

    test('keeps each source in its own stored order', () {
      // Interleaving two independent orderings would invent a sequence the user
      // never set, so habits come first, then recurring tasks.
      final all = recurringWorkFrom(
        habits: [
          _habit(id: 'habit_b'),
          _habit(id: 'habit_a'),
        ],
        tasks: [
          _task(id: 'task_b', sortOrder: 2),
          _task(id: 'task_a', sortOrder: 1),
        ],
      );

      expect(all.map((w) => w.id), ['habit_b', 'habit_a', 'task_b', 'task_a']);
    });

    test('is empty when there is no recurring work', () {
      expect(
        recurringWorkFrom(habits: const [], tasks: const []),
        isEmpty,
      );
    });
  });

  group('isDueOn', () {
    tearDown(AppClock.debugResetNow);

    test('a habit and a recurring task answer identically for the same rule',
        () {
      // Both sources resolve due-ness through Recurring, so the shared shape is
      // not an approximation of their behaviour — it is their behaviour.
      AppClock.debugSetNow(() => DateTime(2026, 3, 20, 9));
      final now = AppClock.now();

      final habit = RecurringWork.fromHabit(_habit());
      final task = RecurringWork.fromTask(_task())!;

      for (var offset = 0; offset < 7; offset++) {
        final day = now.add(Duration(days: offset));
        expect(habit.isDueOn(day, now: now), isTrue);
        expect(task.isDueOn(day, now: now), isTrue);
      }
    });

    test('honours a non-daily habit rule', () {
      AppClock.debugSetNow(() => DateTime(2026, 3, 16, 9)); // Monday
      final now = AppClock.now();

      final habit = RecurringWork.fromHabit(
        _habit(frequency: 'Custom', customWeekdays: const [1, 5]), // Mon, Fri
      );

      expect(habit.isDueOn(DateTime(2026, 3, 16), now: now), isTrue);
      expect(habit.isDueOn(DateTime(2026, 3, 17), now: now), isFalse);
      expect(habit.isDueOn(DateTime(2026, 3, 20), now: now), isTrue);
    });

    test('agrees with the habit entity\'s own due-ness', () {
      // The read model must not fork the definition of due-ness: it delegates to
      // Habit.recurringSchedule, which is what isDueOnDate uses too.
      AppClock.debugSetNow(() => DateTime(2026, 3, 16, 9));
      final now = AppClock.now();
      final habit = _habit(frequency: 'Custom', customWeekdays: const [1, 3]);

      final work = RecurringWork.fromHabit(habit);
      for (var offset = 0; offset < 14; offset++) {
        final day = now.add(Duration(days: offset));
        expect(work.isDueOn(day, now: now), habit.isDueOnDate(day),
            reason: 'diverged on ${day.toIso8601String()}');
      }
    });
  });

  group('equality', () {
    test('distinguishes ids and sources', () {
      final a = RecurringWork.fromHabit(_habit(id: 'habit_1'));
      final b = RecurringWork.fromHabit(_habit(id: 'habit_2'));
      // Same id string space is impossible today (habit_ / task_ prefixes), but
      // source still has to be part of identity if the namespaces ever align.
      final asTask = RecurringWork.fromTask(_task(id: 'habit_1'))!;

      expect(a, isNot(b));
      expect(a, isNot(asTask));
      expect({a, a}.length, 1);
    });
  });
}
