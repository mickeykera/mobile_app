import 'package:flutter_test/flutter_test.dart';

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

    test('un-completing resets the streak and decrements the total', () {
      final habit = _habit(
        lastCompletedAt: DateTime.now(),
        currentStreak: 5,
        longestStreak: 5,
        totalCompletions: 9,
      );

      final undone = habit.copyWithUncompletion();

      expect(undone.currentStreak, 0);
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
}
