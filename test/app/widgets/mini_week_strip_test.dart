import 'package:ascend/app/widgets/mini_week_strip.dart';
import 'package:ascend/app/widgets/week_strip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2026-09-28 is a Monday, which makes the Monday-first indexing explicit.
  final monday = DateTime(2026, 9, 28);

  group('deriveWeekStates', () {
    test('returns seven entries', () {
      final days = deriveWeekStates(
        lastCompletedAt: monday,
        currentStreak: 1,
        reference: monday,
      );

      expect(days, hasLength(7));
    });

    test('a day beyond the streak is missed', () {
      // Completed Monday only, streak of 1, viewed on Wednesday.
      final wednesday = monday.add(const Duration(days: 2));
      final days = deriveWeekStates(
        lastCompletedAt: monday,
        currentStreak: 1,
        reference: wednesday,
      );

      expect(days[0], WeekDayState.complete);
      // Tuesday is over and was not kept.
      expect(days[1], WeekDayState.missed);
      // Wednesday is the day being viewed: still in play, so partial.
      expect(days[2], WeekDayState.partial);
    });

    test('a run of N covers N consecutive days back from the completion', () {
      // Completed Wednesday with a 3 day streak covers Mon, Tue and Wed.
      final days = deriveWeekStates(
        lastCompletedAt: monday.add(const Duration(days: 2)),
        currentStreak: 3,
        reference: monday.add(const Duration(days: 2)),
      );

      expect(days[0], WeekDayState.complete);
      expect(days[1], WeekDayState.complete);
      expect(days[2], WeekDayState.complete);
    });

    test('never marks a day complete with a zero streak', () {
      final days = deriveWeekStates(
        lastCompletedAt: monday,
        currentStreak: 0,
        reference: monday,
      );

      expect(days, isNot(contains(WeekDayState.complete)));
    });

    test('a never-started habit is all missed, not complete', () {
      // Mid-week so every day is in the past; nothing is kept.
      final wednesday = monday.add(const Duration(days: 2));
      final days = deriveWeekStates(
        lastCompletedAt: null,
        currentStreak: 0,
        reference: wednesday,
      );

      expect(days, isNot(contains(WeekDayState.complete)));
      expect(days[0], WeekDayState.missed);
      expect(days[1], WeekDayState.missed);
      // Today is still in play even with nothing kept.
      expect(days[2], WeekDayState.partial);
    });

    test('today stays partial when the habit has never been done', () {
      // Monday reference, nothing ever completed.
      final days = deriveWeekStates(
        lastCompletedAt: null,
        currentStreak: 0,
        reference: monday,
      );

      expect(days[0], WeekDayState.partial);
      expect(days.sublist(1), everyElement(WeekDayState.upcoming));
    });

    test('future days of the week are upcoming', () {
      // Monday reference: Tue..Sun have not happened yet.
      final days = deriveWeekStates(
        lastCompletedAt: monday,
        currentStreak: 1,
        reference: monday,
      );

      expect(days[0], WeekDayState.complete);
      expect(days.sublist(1), everyElement(WeekDayState.upcoming));
    });
  });
}
