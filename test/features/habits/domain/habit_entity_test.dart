import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/habits/domain/entities/habit.dart';

Habit _habit({
  String frequency = 'Daily',
  List<int> customWeekdays = const [],
  DateTime? lastCompletedAt,
  int currentStreak = 0,
  int longestStreak = 0,
  int totalCompletions = 0,
}) {
  final habit = Habit.create(
    title: 'Drink water',
    category: 'Body',
    frequency: frequency,
    customWeekdays: customWeekdays,
  );
  return habit.copyWith(
    lastCompletedAt: lastCompletedAt,
    currentStreak: currentStreak,
    longestStreak: longestStreak,
    totalCompletions: totalCompletions,
  );
}

void main() {
  group('Habit scheduling', () {
    final monday = DateTime(2024, 1, 8); // 2024-01-08 is a Monday
    final sunday = DateTime(2024, 1, 14);
    final tuesday = DateTime(2024, 1, 9);

    test('Daily is due on every day', () {
      final habit = _habit(frequency: 'Daily');
      expect(habit.isDueOnDate(monday), isTrue);
      expect(habit.isDueOnDate(sunday), isTrue);
    });

    test('Weekdays is due Monday to Friday only', () {
      final habit = _habit(frequency: 'Weekdays');
      expect(habit.isDueOnDate(monday), isTrue);
      expect(habit.isDueOnDate(sunday), isFalse);
    });

    test('Weekends is due Saturday and Sunday only', () {
      final habit = _habit(frequency: 'Weekends');
      expect(habit.isDueOnDate(monday), isFalse);
      expect(habit.isDueOnDate(sunday), isTrue);
    });

    test('Custom honours the configured weekdays', () {
      final habit = _habit(frequency: 'Custom', customWeekdays: const [2]);
      expect(habit.isDueOnDate(tuesday), isTrue);
      expect(habit.isDueOnDate(monday), isFalse);
    });

    test('unknown frequency is never due', () {
      final habit = _habit(frequency: 'Sometimes');
      expect(habit.isDueOnDate(monday), isFalse);
    });

    test('isDueToday delegates to isDueOnDate', () {
      expect(_habit(frequency: 'Daily').isDueToday, isTrue);
      expect(_habit(frequency: 'Sometimes').isDueToday, isFalse);
    });
  });

  group('Habit completion bookkeeping', () {
    test('re-completing on the same day keeps the streak alive', () {
      // Regression: the old `_calculateNewStreak` only recognised "yesterday",
      // so a second completion on the same day reset a 7 day streak to 1.
      final habit = _habit(
        lastCompletedAt: DateTime.now(),
        currentStreak: 7,
        longestStreak: 7,
        totalCompletions: 7,
      );

      final again = habit.copyWithCompletion(completed: true);

      expect(again.currentStreak, 7);
      expect(again.totalCompletions, 8);
    });

    test('completing after yesterday extends the streak', () {
      final habit = _habit(
        lastCompletedAt: DateTime.now().subtract(const Duration(days: 1)),
        currentStreak: 3,
        totalCompletions: 3,
      );

      expect(habit.copyWithCompletion(completed: true).currentStreak, 4);
    });

    test('completing after a gap restarts the streak at 1', () {
      final habit = _habit(
        lastCompletedAt: DateTime.now().subtract(const Duration(days: 3)),
        currentStreak: 9,
        totalCompletions: 12,
      );

      expect(habit.copyWithCompletion(completed: true).currentStreak, 1);
    });

    test('first completion starts the streak at 1', () {
      expect(_habit().copyWithCompletion(completed: true).currentStreak, 1);
    });

    test('un-completing shortens the streak by one and decrements the total',
        () {
      final habit = _habit(
        lastCompletedAt: DateTime.now(),
        currentStreak: 5,
        longestStreak: 5,
        totalCompletions: 9,
      );

      final undone = habit.copyWithUncompletion();

      // The surviving completions are still a chain, so losing the most recent
      // day costs exactly one day. This used to be 0, which threw away a 5-day
      // streak over a single un-tick.
      expect(undone.currentStreak, 4);
      // Regression: the old path kept `totalCompletions`, so `completionRate`
      // stayed inflated after the user undid a completion.
      expect(undone.totalCompletions, 8);
      expect(undone.longestStreak, 5, reason: 'longest streak is historical');

      final viaCopyWith = habit.copyWithCompletion(completed: false);
      expect(viaCopyWith.totalCompletions, 8);
    });

    test('un-completing the last completion clears lastCompletedAt', () {
      final habit = _habit(
        lastCompletedAt: DateTime.now(),
        currentStreak: 1,
        totalCompletions: 1,
      );

      final undone = habit.copyWithUncompletion();
      expect(undone.totalCompletions, 0);
      expect(undone.lastCompletedAt, isNull);
      expect(undone.isCompletedToday, isFalse);
    });

    test('un-completing never drives the counter below zero', () {
      final habit = _habit(currentStreak: 1, totalCompletions: 0);
      expect(habit.copyWithUncompletion().totalCompletions, 0);
    });
  });

  group('Habit snooze and reschedule', () {
    // 2025-06-11 is a Wednesday.
    final wednesday = DateTime(2025, 6, 11, 9, 0);

    setUp(() => AppClock.debugSetNow(() => wednesday));
    tearDown(AppClock.debugResetNow);

    test('an active snooze removes the habit from today and future days', () {
      final habit = _habit()
          .copyWith(snoozedUntil: wednesday.add(const Duration(hours: 3)));

      expect(habit.isSnoozed, isTrue);
      expect(habit.activeSnoozeUntil, isNotNull);
      expect(habit.isDueOnDate(wednesday), isFalse);
      expect(
        habit.isDueOnDate(wednesday.add(const Duration(days: 1))),
        isFalse,
      );
    });

    test('a snooze does not rewrite days already in the past', () {
      final habit = _habit()
          .copyWith(snoozedUntil: wednesday.add(const Duration(hours: 3)));

      expect(
        habit.isDueOnDate(wednesday.subtract(const Duration(days: 1))),
        isTrue,
      );
    });

    test('the habit is due again once the snooze elapses', () {
      var now = wednesday;
      AppClock.debugSetNow(() => now);
      final habit = _habit()
          .copyWith(snoozedUntil: wednesday.add(const Duration(hours: 3)));

      expect(habit.isDueOnDate(wednesday), isFalse);

      now = wednesday.add(const Duration(hours: 4));

      expect(habit.isSnoozed, isFalse);
      expect(habit.activeSnoozeUntil, isNull);
      expect(habit.isDueOnDate(now), isTrue);
    });

    test('a reschedule suppresses the days before it', () {
      // Weekdays habit moved to Saturday 2025-06-14.
      final habit = _habit(frequency: 'Weekdays')
          .copyWith(dueAt: DateTime(2025, 6, 14, 9));

      expect(habit.isDueOnDate(DateTime(2025, 6, 13)), isFalse,
          reason: 'Friday is before the new due date');
    });

    test('a reschedule forces its own day even outside the recurrence', () {
      final habit = _habit(frequency: 'Weekdays')
          .copyWith(dueAt: DateTime(2025, 6, 14, 9)); // Saturday

      expect(habit.isDueOnDate(DateTime(2025, 6, 14)), isTrue,
          reason: 'the rescheduled day is always due');
    });

    test('recurrence resumes once the rescheduled day is past', () {
      final habit = _habit(frequency: 'Weekdays')
          .copyWith(dueAt: DateTime(2025, 6, 14, 9)); // Saturday

      // Sunday is still a non-working day for a Weekdays habit.
      expect(habit.isDueOnDate(DateTime(2025, 6, 15)), isFalse);
      // Monday falls back to the normal recurrence.
      expect(habit.isDueOnDate(DateTime(2025, 6, 16)), isTrue);
    });

    test('a reschedule does not rewrite days already in the past', () {
      // Now is Friday; the reschedule targets the coming Monday.
      AppClock.debugSetNow(() => DateTime(2025, 6, 13, 9));
      final habit =
          _habit(frequency: 'Daily').copyWith(dueAt: DateTime(2025, 6, 16, 9));

      expect(habit.isDueOnDate(DateTime(2025, 6, 12)), isTrue,
          reason: 'yesterday keeps its original recurrence result');
    });

    test('rescheduling to today forces a habit that is not normally due', () {
      // A Weekends habit moved onto a Wednesday is due today.
      final habit = _habit(frequency: 'Weekends').copyWith(dueAt: wednesday);

      expect(habit.isDueOnDate(wednesday), isTrue);
    });

    test('a snooze until tomorrow stays hidden across the day boundary', () {
      final habit = _habit()
          .copyWith(snoozedUntil: DateTime(2025, 6, 12, 9)); // tomorrow 9am

      expect(habit.isDueOnDate(wednesday), isFalse);
      expect(habit.isDueOnDate(DateTime(2025, 6, 12)), isFalse,
          reason: 'the hold covers tomorrow until it elapses');
    });
  });

  group('Habit completion lookup', () {
    test('isCompletedOn only matches the exact day', () {
      final today = DateTime.now();
      final habit = _habit(lastCompletedAt: today);

      expect(habit.isCompletedOn(today), isTrue);
      expect(habit.isCompletedOn(today.subtract(const Duration(days: 1))),
          isFalse);
      expect(habit.isCompletedToday, isTrue);
    });

    test('a habit that was never completed is not completed', () {
      expect(_habit().isCompletedOn(DateTime.now()), isFalse);
      expect(_habit().isCompletedToday, isFalse);
    });
  });

  group('Habit relationship links', () {
    test('default to null', () {
      final habit = Habit.create(title: 'Read', category: 'Mind');
      expect(habit.projectId, isNull);
      expect(habit.goalId, isNull);
    });

    test('linking preserves identity and scheduling', () {
      final habit = Habit.create(title: 'Read', category: 'Mind')
          .copyWith(dueAt: DateTime(2025, 6, 14));

      final linked = habit.copyWith(projectId: 'project_1', goalId: 'goal_1');

      expect(linked.projectId, 'project_1');
      expect(linked.goalId, 'goal_1');
      expect(linked.id, habit.id);
      expect(linked.dueAt, habit.dueAt);
      expect(linked.frequency, habit.frequency);
    });
  });
}
