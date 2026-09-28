import 'package:ascend/core/extensions/date_extensions.dart';
import 'package:ascend/features/focus/domain/entities/focus_session.dart';
import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/habits/domain/entities/habit_completion.dart';
import 'package:ascend/features/journal/domain/entities/journal_entry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for bugs found in a full review pass.
void main() {
  group('entity ids are unique', () {
    // Ids used to be `DateTime.now().millisecondsSinceEpoch`, so two entities
    // built inside the same millisecond shared an id. Creating a second habit
    // then silently overwrote the first, because the repository keys by id.
    test('two habits built back to back get different ids', () {
      final a = Habit.create(title: 'A', category: 'Mind');
      final b = Habit.create(title: 'B', category: 'Mind');
      expect(a.id, isNot(b.id));
    });

    test('two completions built back to back get different ids', () {
      final a = HabitCompletion.create(habitId: 'h1');
      final b = HabitCompletion.create(habitId: 'h1');
      expect(a.id, isNot(b.id));
    });

    test('two focus sessions built back to back get different ids', () {
      final a = FocusSession.create(mode: 'Pomodoro');
      final b = FocusSession.create(mode: 'Pomodoro');
      expect(a.id, isNot(b.id));
    });

    test('two journal entries built back to back get different ids', () {
      final a = JournalEntry.createMorning(date: DateTime.now(), responses: {});
      final b = JournalEntry.createMorning(date: DateTime.now(), responses: {});
      expect(a.id, isNot(b.id));
    });

    test('ids keep their entity prefix so they stay readable in storage', () {
      expect(
          Habit.create(title: 'A', category: 'Mind').id, startsWith('habit_'));
      expect(
          HabitCompletion.create(habitId: 'h').id, startsWith('completion_'));
      expect(FocusSession.create(mode: 'Pomodoro').id, startsWith('session_'));
      expect(JournalEntry.createMorning(date: DateTime.now(), responses: {}).id,
          startsWith('entry_'));
    });
  });

  group('un-completing preserves the surviving streak', () {
    Habit habitWithStreak(int days) {
      var h = Habit.create(title: 'A', category: 'Mind');
      for (var i = 0; i < days; i++) {
        h = h.copyWithCompletion(
            completed: true, completionTime: DateTime(2026, 3, i + 1));
      }
      return h;
    }

    test('a 3-day streak drops to 2, not 0', () {
      // Regression: the old code reset `currentStreak` to 0, so un-ticking one
      // box threw away the whole chain.
      final h = habitWithStreak(3);
      expect(h.currentStreak, 3);

      final undone = h.copyWithUncompletion();
      expect(undone.currentStreak, 2);
      expect(undone.totalCompletions, 2);
    });

    test('a long streak survives losing its most recent day', () {
      final undone = habitWithStreak(30).copyWithUncompletion();
      expect(undone.currentStreak, 29);
      expect(undone.longestStreak, 30,
          reason: 'the historical best is not erased by an undo');
    });

    test('a 1-day streak correctly falls back to 0 and clears the timestamp',
        () {
      final undone = habitWithStreak(1).copyWithUncompletion();
      expect(undone.currentStreak, 0);
      expect(undone.totalCompletions, 0);
      expect(undone.lastCompletedAt, isNull);
    });

    test('the streak never goes negative', () {
      final h = Habit.create(title: 'A', category: 'Mind')
          .copyWith(currentStreak: 0, totalCompletions: 0)
          .copyWithUncompletion();
      expect(h.currentStreak, 0);
      expect(h.totalCompletions, 0);
    });
  });

  group('formatRelative', () {
    test('a future date does not report "Just now"', () {
      // Regression: a negative duration fell through every branch and returned
      // "Just now" for a date three days ahead.
      // The extra hours keep the value clear of a day boundary, which would
      // otherwise truncate while the test is running.
      final future = DateTime.now().add(const Duration(days: 3, hours: 6));
      expect(future.formatRelative(), 'in 3d');
    });

    test('a far-future date is reported in years', () {
      final future = DateTime.now().add(const Duration(days: 800, hours: 6));
      expect(future.formatRelative(), 'in 2y');
    });

    test('a few minutes in the future is reported in minutes', () {
      final future =
          DateTime.now().add(const Duration(minutes: 5, seconds: 30));
      expect(future.formatRelative(), 'in 5m');
    });

    test('a past date still reads as past', () {
      final past = DateTime.now().subtract(const Duration(hours: 3));
      expect(past.formatRelative(), '3h ago');
    });

    test('now reads as "Just now"', () {
      expect(DateTime.now().formatRelative(), 'Just now');
    });
  });

  group('endOfWeek covers the whole final day', () {
    test('ends on the last millisecond of Sunday', () {
      final monday = DateTime(2026, 9, 28); // a Monday
      final eow = monday.endOfWeek;

      expect(eow.weekday, DateTime.sunday);
      expect(eow.hour, 23);
      expect(eow.minute, 59);
      expect(eow.second, 59);
      // Regression: this used to be .000, a millisecond short of `endOfDay`
      // and inconsistent with `endOfMonth`.
      expect(eow.millisecond, 999);
    });

    test('is after every other instant on the final day', () {
      final sundayNoon = DateTime(2026, 10, 4, 12);
      expect(sundayNoon.endOfWeek.isAfter(sundayNoon), isTrue);
    });

    test('holds across a DST transition', () {
      // US DST ends on 2026-11-01, mid-week. Adding a fixed number of days is
      // safe here because the range is built from calendar fields, not 24h
      // blocks, but the endpoint still has to land on the Sunday.
      final dstWeek = DateTime(2026, 11, 1);
      expect(dstWeek.endOfWeek.weekday, DateTime.sunday);
      expect(dstWeek.endOfWeek.millisecond, 999);
    });
  });
}
