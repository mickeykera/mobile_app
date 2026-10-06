import 'package:ascend/features/habits/domain/entities/habit_completion.dart';
import 'package:ascend/features/recurring/domain/recurring_streak.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for the canonical recurring streak projection.
///
/// Pure and fixed-date: no clock, no repository, no migration. The bridge
/// behaviour - what happens when a habit's history exists in two logs at once -
/// is in `l1_2_read_path_test.dart`, against real persistence.
void main() {
  /// 2025-06-09 is a Monday, so offsets below line up with weekday schedules.
  final monday = DateTime(2025, 6, 9);
  DateTime day(int offset, {int hour = 9}) =>
      DateTime(2025, 6, 9 + offset, hour);

  HabitCompletion habitRow(String habitId, DateTime at, {int count = 1}) =>
      HabitCompletion(
        id: 'h-$habitId-${at.toIso8601String()}',
        habitId: habitId,
        itemId: habitId,
        itemType: 'habit',
        completedAt: at,
        count: count,
      );

  HabitCompletion taskRow(String taskId, DateTime at, {int count = 1}) =>
      HabitCompletion(
        id: 't-$taskId-${at.toIso8601String()}',
        itemId: taskId,
        itemType: 'task',
        completedAt: at,
        count: count,
      );

  /// Curried row builders, so a list of days can be mapped straight into rows.
  HabitCompletion Function(DateTime) habitRow2(String habitId) =>
      (at) => habitRow(habitId, at);

  HabitCompletion Function(DateTime) taskRow2(String taskId) =>
      (at) => taskRow(taskId, at);

  group('forHabitLog', () {
    test('an empty log is a zero streak with no last completion', () {
      final streak = RecurringStreak.forHabitLog(const [], 'h1');

      expect(streak.currentStreak, 0);
      expect(streak.longestStreak, 0);
      expect(streak.totalCompletedDays, 0);
      expect(streak.occurrenceCount, 0);
      expect(streak.lastCompletedAt, isNull);
    });

    test('a single day is a streak of one', () {
      final streak =
          RecurringStreak.forHabitLog([habitRow('h1', day(0))], 'h1');

      expect(streak.currentStreak, 1);
      expect(streak.longestStreak, 1);
    });

    test('counts calendar days, not rows', () {
      // Three taps of a targetCount: 3 habit are one day's work.
      final streak = RecurringStreak.forHabitLog([
        habitRow('h1', day(0, hour: 8)),
        habitRow('h1', day(0, hour: 9)),
        habitRow('h1', day(0, hour: 10)),
      ], 'h1');

      expect(streak.totalCompletedDays, 1);
      expect(streak.occurrenceCount, 3);
      expect(streak.currentStreak, 1);
    });

    test('an un-broken chain of days is one streak', () {
      final streak = RecurringStreak.forHabitLog([
        habitRow('h1', day(0)),
        habitRow('h1', day(1)),
        habitRow('h1', day(2)),
        habitRow('h1', day(3)),
      ], 'h1');

      expect(streak.currentStreak, 4);
      expect(streak.longestStreak, 4);
      expect(streak.totalCompletedDays, 4);
    });

    test('a gap splits the run into two streaks', () {
      final streak = RecurringStreak.forHabitLog([
        habitRow('h1', day(0)),
        habitRow('h1', day(1)),
        // day 2 missing
        habitRow('h1', day(3)),
        habitRow('h1', day(4)),
        habitRow('h1', day(5)),
      ], 'h1');

      // Days are newest first, so the chain walks back from day 5.
      expect(streak.currentStreak, 3);
      expect(streak.longestStreak, 3);
      expect(streak.totalCompletedDays, 5);
    });

    test('longest is the best run anywhere, not the current one', () {
      final streak = RecurringStreak.forHabitLog([
        habitRow('h1', day(0)),
        habitRow('h1', day(1)),
        habitRow('h1', day(2)),
        habitRow('h1', day(3)),
        habitRow('h1', day(4)),
        // Long break.
        habitRow('h1', day(8)),
      ], 'h1');

      expect(streak.currentStreak, 1);
      expect(streak.longestStreak, 5);
    });

    test('months and years roll over without breaking a chain', () {
      final streak = RecurringStreak.forHabitLog([
        habitRow('h1', DateTime(2025, 1, 31)),
        habitRow('h1', DateTime(2025, 2, 1)),
        habitRow('h1', DateTime(2025, 2, 2)),
      ], 'h1');

      expect(streak.currentStreak, 3);
    });

    test('a streak is not aged by the passage of time', () {
      // The most recent completion is months old and the streak is still its
      // full length: ageing is a separate feature and neither side applies it.
      final streak = RecurringStreak.forHabitLog([
        habitRow('h1', DateTime(2025, 1, 1)),
        habitRow('h1', DateTime(2025, 1, 2)),
      ], 'h1');

      expect(streak.currentStreak, 2);
      expect(streak.lastCompletedAt, DateTime(2025, 1, 2));
    });

    test('another habit\'s rows are not counted', () {
      final streak = RecurringStreak.forHabitLog([
        habitRow('h1', day(0)),
        habitRow('h2', day(1)),
        habitRow('h2', day(2)),
      ], 'h1');

      expect(streak.totalCompletedDays, 1);
      expect(streak.currentStreak, 1);
    });

    test('Task rows sharing the table are not counted', () {
      final streak = RecurringStreak.forHabitLog([
        habitRow('h1', day(0)),
        taskRow('t1', day(1)),
        taskRow('t1', day(2)),
      ], 'h1');

      expect(streak.totalCompletedDays, 1);
      expect(streak.currentStreak, 1);
    });
  });

  group('forTaskLog', () {
    test('counts Task occurrence rows only', () {
      final streak = RecurringStreak.forTaskLog([
        taskRow('t1', day(0)),
        taskRow('t1', day(1)),
        // Same id, wrong type: a habit row that happens to share the id.
        HabitCompletion(
          id: 'x',
          habitId: 'h1',
          itemId: 't1',
          itemType: 'habit',
          completedAt: day(2),
          count: 1,
        ),
      ], 't1');

      expect(streak.totalCompletedDays, 2);
      expect(streak.currentStreak, 2);
    });

    test('another Task\'s rows are not counted', () {
      final streak = RecurringStreak.forTaskLog([
        taskRow('t1', day(0)),
        taskRow('t2', day(1)),
        taskRow('t2', day(2)),
      ], 't1');

      expect(streak.totalCompletedDays, 1);
    });

    test('a Mon/Wed/Fri Task completed on those days scores 1, not 3', () {
      // The bug this type exists to end. Scheduled-consecutive reading skipped
      // the unscheduled days and reported 3 here, while the same log read as a
      // Habit reported 1. Canonical is the calendar-day chain.
      final streak = RecurringStreak.forTaskLog([
        taskRow('t1', DateTime(2025, 6, 9)), // Monday
        taskRow('t1', DateTime(2025, 6, 11)), // Wednesday
        taskRow('t1', DateTime(2025, 6, 13)), // Friday
      ], 't1');

      expect(streak.currentStreak, 1);
      expect(streak.longestStreak, 1);
      expect(streak.totalCompletedDays, 3);
    });
  });

  group('day-consecutive versus scheduled-consecutive', () {
    Task recurringTask(String id, String frequency) => Task(
          id: id,
          title: id,
          createdAt: monday,
          updatedAt: monday,
          sortOrder: 0,
          status: TaskStatus.todo,
          category: 'Mind',
          schedule: Recurring(RecurrenceRule.fromFrequency(frequency)),
        );

    test('a daily Task and a weekday Task agree on a Mon-Fri run', () {
      final rows = [
        taskRow('daily', DateTime(2025, 6, 9)),
        taskRow('daily', DateTime(2025, 6, 10)),
        taskRow('daily', DateTime(2025, 6, 11)),
        taskRow('weekday', DateTime(2025, 6, 9)),
        taskRow('weekday', DateTime(2025, 6, 10)),
        taskRow('weekday', DateTime(2025, 6, 11)),
      ];

      expect(
        RecurringStreak.forTaskLog(rows, 'daily').currentStreak,
        RecurringStreak.forTaskLog(rows, 'weekday').currentStreak,
      );
    });

    test('the schedule does not change the answer', () {
      // Three consecutive calendar days: Monday to Wednesday. Under the
      // scheduled rule a Weekdays Task would score 3 and a Weekends Task 0, so
      // this is the assertion that the schedule is genuinely not consulted.
      final rows = [
        taskRow('t1', DateTime(2025, 6, 9)),
        taskRow('t1', DateTime(2025, 6, 10)),
        taskRow('t1', DateTime(2025, 6, 11)),
      ];

      for (final frequency in ['Daily', 'Weekdays', 'Weekends', 'Custom']) {
        final task = recurringTask('t1', frequency);
        expect(
          RecurringStreak.forTaskLog(rows, task.id).currentStreak,
          3,
          reason: 'schedule $frequency changed the streak',
        );
      }
    });

    test('the habit log and the task log agree on identical history', () {
      // The same days recorded through each owner: one definition, two logs.
      final rows = [
        DateTime(2025, 6, 9),
        DateTime(2025, 6, 10),
        DateTime(2025, 6, 12),
      ];

      expect(
        RecurringStreak.forTaskLog(rows.map(taskRow2('t1')).toList(), 't1')
            .currentStreak,
        RecurringStreak.forHabitLog(rows.map(habitRow2('h1')).toList(), 'h1')
            .currentStreak,
      );
    });
  });

  group('isCompletedOn', () {
    test('matches on the calendar day, whatever the hour', () {
      final streak = RecurringStreak.forTaskLog([
        taskRow('t1', DateTime(2025, 6, 9, 23, 59)),
      ], 't1');

      expect(streak.isCompletedOn(DateTime(2025, 6, 9)), isTrue);
      expect(streak.isCompletedOn(DateTime(2025, 6, 9, 0, 0)), isTrue);
      expect(streak.isCompletedOn(DateTime(2025, 6, 10)), isFalse);
    });
  });

  group('longest is diagnostic only', () {
    test('an un-completion hides the run from the log but not from the store',
        () {
      // Five days achieved, the newest one un-completed. The log's longest
      // collapse to 4 because the evidence is gone; `Habit.longestStreak`
      // deliberately stays at 5, because the run *was* achieved. That gap is
      // why no read path may write the derived value back over the stored one.
      final rows = [
        taskRow('t1', DateTime(2025, 6, 9)),
        taskRow('t1', DateTime(2025, 6, 10)),
        taskRow('t1', DateTime(2025, 6, 11)),
        taskRow('t1', DateTime(2025, 6, 12)),
        taskRow('t1', DateTime(2025, 6, 13)),
      ];

      expect(RecurringStreak.forTaskLog(rows, 't1').longestStreak, 5);
      expect(
        RecurringStreak.forTaskLog(rows.take(4).toList(), 't1').longestStreak,
        4,
      );
    });
  });
}
