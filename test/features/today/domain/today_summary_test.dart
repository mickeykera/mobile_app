import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/app/widgets/week_strip.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/focus/domain/entities/focus_session.dart';
import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/habits/domain/entities/habit_completion.dart';
import 'package:ascend/features/today/domain/today_summary.dart';

/// Covers the arithmetic the Today screen is built from.
///
/// These are the functions that decide what the user is told about their own
/// day, and every one of them is wrong in a way a screenshot would not reveal:
/// a streak that counts the wrong habit, a week strip that marks tomorrow as a
/// failure, a focus total that ignores a running session. The screen tests
/// check that it renders; these check that what it renders is true.

/// A Monday, so weekday-dependent behaviour is predictable.
final _monday = DateTime(2025, 6, 2);

Habit _habit(
  String id, {
  String frequency = 'Daily',
  List<int> customWeekdays = const [],
  int streak = 0,
  bool archived = false,
}) =>
    Habit(
      id: id,
      title: id,
      description: '',
      category: 'Mind',
      frequency: frequency,
      customWeekdays: customWeekdays,
      timeOfDay: 'Morning',
      targetCount: 1,
      targetDuration: Duration.zero,
      cue: '',
      createdAt: _monday,
      updatedAt: _monday,
      sortOrder: 0,
      isArchived: archived,
      streakFreezesUsed: 0,
      currentStreak: streak,
      longestStreak: streak,
      totalCompletions: 0,
    );

HabitCompletion _completion(String habitId, DateTime at, {int count = 1}) =>
    HabitCompletion(
      id: '$habitId@${at.toIso8601String()}',
      habitId: habitId,
      completedAt: at,
      count: count,
    );

FocusSession _session(DateTime startedAt, int minutes, {bool active = false}) =>
    FocusSession(
      id: startedAt.toIso8601String(),
      mode: 'Pomodoro',
      workDurationMinutes: 25,
      breakDurationMinutes: 5,
      longBreakDurationMinutes: 15,
      sessionsBeforeLongBreak: 4,
      completedSessions: 1,
      totalWorkMinutes: minutes,
      totalBreakMinutes: 0,
      startedAt: startedAt,
      isActive: active,
      isPaused: false,
      isBreak: false,
    );

void main() {
  group('greetingForHour', () {
    test('changes at noon and at six', () {
      expect(greetingForHour(0), 'Good morning');
      expect(greetingForHour(11), 'Good morning');
      expect(greetingForHour(12), 'Good afternoon');
      expect(greetingForHour(17), 'Good afternoon');
      expect(greetingForHour(18), 'Good evening');
      expect(greetingForHour(23), 'Good evening');
    });
  });

  group('focusMinutesOn', () {
    test('sums only the sessions that started that day', () {
      final minutes = focusMinutesOn(_monday, [
        _session(_monday.add(const Duration(hours: 9)), 25),
        _session(_monday.add(const Duration(hours: 14)), 50),
        _session(_monday.add(const Duration(days: 1)), 25),
      ]);

      expect(minutes, 75);
    });

    test('counts an in-progress session by what it has banked', () {
      // A session that is visibly running and contributes nothing reads as a
      // bug, so its accumulated minutes are included.
      final minutes = focusMinutesOn(_monday, [
        _session(_monday.add(const Duration(hours: 9)), 12, active: true),
      ]);

      expect(minutes, 12);
    });

    test('a day boundary does not leak into the next day', () {
      // 23:30 today and 00:30 tomorrow are different days, however close.
      final minutes = focusMinutesOn(_monday, [
        _session(DateTime(2025, 6, 2, 23, 30), 20),
      ]);

      expect(minutes, 20);
      expect(
          focusMinutesOn(_monday.add(const Duration(days: 1)), [
            _session(DateTime(2025, 6, 3, 0, 30), 20),
          ]),
          20);
    });

    test('no sessions is zero, not null', () {
      expect(focusMinutesOn(_monday, const []), 0);
    });
  });

  group('weekDayStates', () {
    test('a finished Monday is complete and an untouched Tuesday is missed',
        () {
      // Reference is Wednesday: Tuesday has to be genuinely in the past to be
      // missed, because today is always upcoming rather than failed.
      final states = weekDayStates(
        reference: _monday.add(const Duration(days: 2)),
        habits: [_habit('a')],
        completions: [_completion('a', _monday.add(const Duration(hours: 8)))],
      );

      expect(states[0], WeekDayState.complete);
      expect(states[1], WeekDayState.missed);
      expect(states[2], WeekDayState.upcoming);
    });

    test('today with nothing done is not a failure', () {
      // The single most important case: opening the app mid-morning must not
      // report today as missed.
      final states = weekDayStates(
        reference: _monday,
        habits: [_habit('a')],
        completions: const [],
      );

      expect(states[0], WeekDayState.upcoming);
    });

    test('days after today are upcoming, never missed', () {
      final states = weekDayStates(
        reference: _monday,
        habits: [_habit('a')],
        completions: const [],
      );

      expect(states.sublist(1), everyElement(WeekDayState.upcoming));
    });

    test('some-but-not-all due habits gives partial', () {
      final states = weekDayStates(
        reference: _monday.add(const Duration(days: 1)),
        habits: [_habit('a'), _habit('b')],
        completions: [_completion('a', _monday.add(const Duration(hours: 8)))],
      );

      expect(states[0], WeekDayState.partial);
    });

    test('a day with nothing due is skipped rather than counted as missed', () {
      // Nobody should be punished for a rest day.
      final states = weekDayStates(
        reference: _monday.add(const Duration(days: 6)), // Sunday
        habits: [_habit('a', frequency: 'Weekdays')],
        completions: const [],
      );

      expect(states[6], WeekDayState.upcoming);
    });

    test('weekday and custom schedules gate which days count', () {
      final weekdayStates = weekDayStates(
        reference: _monday.add(const Duration(days: 5)), // Saturday
        habits: [_habit('a', frequency: 'Weekdays')],
        completions: const [],
      );
      expect(weekdayStates[5], WeekDayState.upcoming);

      final weekendStates = weekDayStates(
        reference: _monday.add(const Duration(days: 5)), // Saturday
        habits: [_habit('a', frequency: 'Weekends')],
        completions: const [],
      );
      expect(weekendStates[5], WeekDayState.upcoming);

      // Monday is in customWeekdays (DateTime.monday == 1).
      final customStates = weekDayStates(
        reference: _monday.add(const Duration(days: 1)),
        habits: [
          _habit('a', frequency: 'Custom', customWeekdays: const [1])
        ],
        completions: const [],
      );
      expect(customStates[0], WeekDayState.missed);
      expect(customStates[1], WeekDayState.upcoming);
    });

    test('an archived habit is not held against the day', () {
      final states = weekDayStates(
        reference: _monday.add(const Duration(days: 1)),
        habits: [_habit('a', archived: true)],
        completions: const [],
      );

      expect(states[0], WeekDayState.upcoming);
    });

    test('always returns seven days starting Monday', () {
      final states = weekDayStates(
        reference: DateTime(2025, 6, 5), // a Thursday
        habits: const [],
        completions: const [],
      );

      expect(states, hasLength(7));
    });

    test('a completion for another habit does not mark the day done', () {
      final states = weekDayStates(
        reference: _monday.add(const Duration(days: 1)),
        habits: [_habit('a')],
        completions: [_completion('other', _monday)],
      );

      expect(states[0], WeekDayState.missed);
    });
  });

  group('weekCompletionCount', () {
    test('counts habit-days, not rows', () {
      // targetCount: 3 writes a row per tap; that is still one day's work.
      final count = weekCompletionCount(
        reference: _monday,
        completions: [
          _completion('a', _monday.add(const Duration(hours: 8))),
          _completion('a', _monday.add(const Duration(hours: 9))),
          _completion('a', _monday.add(const Duration(hours: 10))),
        ],
      );

      expect(count, 1);
    });

    test('counts distinct habit-days across the week', () {
      final count = weekCompletionCount(
        reference: _monday,
        completions: [
          _completion('a', _monday),
          _completion('a', _monday.add(const Duration(days: 1))),
          _completion('b', _monday),
        ],
      );

      expect(count, 3);
    });

    test('ignores completions outside the week', () {
      final count = weekCompletionCount(
        reference: _monday,
        completions: [
          _completion('a', _monday),
          _completion('a', _monday.subtract(const Duration(days: 1))),
          _completion('a', _monday.add(const Duration(days: 7))),
        ],
      );

      expect(count, 1);
    });
  });

  group('bestCurrentStreak', () {
    test('takes the longest running chain', () {
      final best = bestCurrentStreak([
        _habit('a', streak: 2),
        _habit('b', streak: 12),
        _habit('c', streak: 5),
      ]);

      expect(best, 12);
    });

    test('skips archived habits so a retired chain is not the headline', () {
      final best = bestCurrentStreak([
        _habit('a', streak: 30, archived: true),
        _habit('b', streak: 3),
      ]);

      expect(best, 3);
    });

    test('no habits is zero', () {
      expect(bestCurrentStreak(const []), 0);
    });
  });

  group('weekDayStates agrees with the habit schedule', () {
    // 2025-06-11 is a Wednesday; the week runs Mon 2025-06-09.
    final wednesday = DateTime(2025, 6, 11, 9, 0);

    setUp(() => AppClock.debugSetNow(() => wednesday));
    tearDown(AppClock.debugResetNow);

    test('a snoozed habit does not drag today into partial', () {
      final done = _habit('a');
      final snoozed = _habit('b')
          .copyWith(snoozedUntil: wednesday.add(const Duration(hours: 3)));
      final states = weekDayStates(
        reference: wednesday,
        habits: [done, snoozed],
        completions: [
          _completion('a', wednesday.add(const Duration(hours: 8)))
        ],
      );

      // Only 'a' is actually due, and it is done, so the day is complete.
      expect(states[2], WeekDayState.complete);
    });

    test('a habit rescheduled away does not drag today into partial', () {
      final done = _habit('a');
      final moved =
          _habit('b').copyWith(dueAt: wednesday.add(const Duration(days: 1)));
      final states = weekDayStates(
        reference: wednesday,
        habits: [done, moved],
        completions: [
          _completion('a', wednesday.add(const Duration(hours: 8)))
        ],
      );

      expect(states[2], WeekDayState.complete);
    });

    test('a reschedule only affects today and later, never past days', () {
      final moved =
          _habit('b').copyWith(dueAt: wednesday.add(const Duration(days: 1)));
      final states = weekDayStates(
        reference: wednesday,
        habits: [moved],
        completions: const [],
      );

      // Monday and Tuesday keep their original recurrence (missed, because the
      // daily habit was not completed) - the reschedule is not retroactive.
      expect(states[0], WeekDayState.missed);
      expect(states[1], WeekDayState.missed);
      // Today is hidden by the reschedule, so nothing is pending.
      expect(states[2], WeekDayState.upcoming);
    });
  });
}
