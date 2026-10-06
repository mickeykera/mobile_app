import 'package:flutter_test/flutter_test.dart';
import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/habits/domain/entities/habit_completion.dart';
import 'package:ascend/features/recurring/domain/streak_parity.dart';

/// A habit whose stored counters say "nothing done yet", so each test can state
/// only the history it cares about.
Habit _habit({
  String id = 'habit_1',
  String frequency = 'Daily',
  List<int> customWeekdays = const [],
  int currentStreak = 0,
  int longestStreak = 0,
  int totalCompletions = 0,
  DateTime? lastCompletedAt,
}) =>
    Habit(
      id: id,
      title: 'Read',
      description: '',
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
      isArchived: false,
      streakFreezesUsed: 0,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalCompletions: totalCompletions,
      lastCompletedAt: lastCompletedAt,
    );

/// One completion on [day], at midday so a timezone shift cannot move it.
///
/// [itemType] other than `'habit'` produces a task completion row, which is the
/// shape storage already accepts but nothing writes yet.
HabitCompletion _completion(String habitId, DateTime day,
        {String itemType = 'habit'}) =>
    HabitCompletion(
      id: 'cmp_${habitId}_${day.toIso8601String()}',
      habitId: habitId,
      itemId: itemType == 'habit' ? null : habitId,
      itemType: itemType,
      completedAt: DateTime(day.year, day.month, day.day, 12),
      count: 1,
    );

/// A habit whose stored counters were produced by ticking [days] in order via
/// the real write path, so `agrees` is a genuine like-for-like comparison rather
/// than a tautology.
Habit _habitCompletedOn(List<DateTime> days,
    {String id = 'habit_1', String frequency = 'Daily'}) {
  var habit = _habit(id: id, frequency: frequency);
  for (final day in days) {
    final time = DateTime(day.year, day.month, day.day, 9);
    habit = habit.copyWithCompletion(completed: true, completionTime: time);
  }
  return habit;
}

/// `count` consecutive days ending on [endDay], **oldest first**.
///
/// Ascending, because that is the order history is actually built in:
/// `_calculateNewStreak` compares against `lastCompletedAt`, so feeding it
/// newest-first resets the streak on every tick.
List<DateTime> _days(int count, {int endDay = 20}) => [
      for (var i = count - 1; i >= 0; i--) DateTime(2026, 3, endDay - i),
    ];

void main() {
  group('HabitLogProjection', () {
    test('an empty log derives zeroes', () {
      final projection = HabitLogProjection.from(const [], 'habit_1');

      expect(projection.completedDays, isEmpty);
      expect(projection.totalCompletions, 0);
      expect(projection.currentStreak, 0);
      expect(projection.longestStreak, 0);
    });

    test('counts a day once however many rows it has', () {
      // The stored counters count days, so summing rows would invent
      // completions the streak never tracked.
      final day = DateTime(2026, 3, 20);
      final projection = HabitLogProjection.from([
        _completion('habit_1', day),
        _completion('habit_1', day),
        _completion('habit_1', day),
      ], 'habit_1');

      expect(projection.totalCompletions, 1);
      expect(projection.currentStreak, 1);
    });

    test('sorts completed days newest first', () {
      final projection = HabitLogProjection.from([
        _completion('habit_1', DateTime(2026, 3, 18)),
        _completion('habit_1', DateTime(2026, 3, 20)),
        _completion('habit_1', DateTime(2026, 3, 19)),
      ], 'habit_1');

      expect(
        projection.completedDays.map((d) => d.day),
        [20, 19, 18],
      );
    });

    test('ignores rows belonging to another habit', () {
      final projection = HabitLogProjection.from([
        _completion('habit_1', DateTime(2026, 3, 20)),
        _completion('habit_2', DateTime(2026, 3, 19)),
        _completion('habit_2', DateTime(2026, 3, 18)),
      ], 'habit_1');

      expect(projection.totalCompletions, 1);
      expect(projection.currentStreak, 1);
    });

    test('ignores rows that are not habit completions', () {
      // Completion rows are owner-typed. A row with another itemType belongs to
      // a different work item and must not be counted against a habit.
      final projection = HabitLogProjection.from([
        _completion('habit_1', DateTime(2026, 3, 20)),
        _completion('habit_1', DateTime(2026, 3, 19), itemType: 'task'),
        _completion('habit_1', DateTime(2026, 3, 18), itemType: 'task'),
      ], 'habit_1');

      expect(projection.totalCompletions, 1);
      expect(projection.currentStreak, 1);
    });

    test('a same-day double completion does not grow the streak', () {
      final projection = HabitLogProjection.from([
        _completion('habit_1', DateTime(2026, 3, 20)),
        _completion('habit_1', DateTime(2026, 3, 20)),
        _completion('habit_1', DateTime(2026, 3, 19)),
      ], 'habit_1');

      expect(projection.currentStreak, 2);
      expect(projection.totalCompletions, 2);
    });
  });

  group('streak derivation is day-consecutive', () {
    test('an unbroken run counts up', () {
      final projection = HabitLogProjection.from(
          [for (final d in _days(4)) _completion('habit_1', d)], 'habit_1');

      expect(projection.currentStreak, 4);
      expect(projection.longestStreak, 4);
    });

    test('a multi-day gap breaks the current run', () {
      final projection = HabitLogProjection.from([
        _completion('habit_1', DateTime(2026, 3, 20)),
        _completion('habit_1', DateTime(2026, 3, 19)),
        // gap: 17, 18 missing
        _completion('habit_1', DateTime(2026, 3, 16)),
        _completion('habit_1', DateTime(2026, 3, 15)),
      ], 'habit_1');

      expect(projection.currentStreak, 2);
      expect(projection.longestStreak, 2);
    });

    test('the longest run is found anywhere in the log, not just at the end',
        () {
      final projection = HabitLogProjection.from([
        _completion('habit_1', DateTime(2026, 3, 20)),
        _completion('habit_1', DateTime(2026, 3, 19)),
        // an older, longer run of five
        _completion('habit_1', DateTime(2026, 3, 15)),
        _completion('habit_1', DateTime(2026, 3, 14)),
        _completion('habit_1', DateTime(2026, 3, 13)),
        _completion('habit_1', DateTime(2026, 3, 12)),
        _completion('habit_1', DateTime(2026, 3, 11)),
      ], 'habit_1');

      expect(projection.currentStreak, 2);
      expect(projection.longestStreak, 5);
    });

    test(
        'a non-daily habit derives a day-consecutive streak, not an '
        'occurrence count', () {
      // The fork this definition resolves, made concrete. Mon/Wed/Fri has three
      // scheduled occurrences but three two-day gaps, so day-consecutive is 1 —
      // and so is what the write path stored, because _calculateNewStreak counts
      // calendar days. A scheduled-consecutive derivation would report 3 here
      // and disagree with every non-daily habit on earth.
      final days = [
        DateTime(2026, 3, 16), // Monday
        DateTime(2026, 3, 18), // Wednesday
        DateTime(2026, 3, 20), // Friday
      ];
      final habit = _habitCompletedOn(days, frequency: 'Custom');

      final parity = HabitLogProjection.from(
        [for (final d in days) _completion('habit_1', d)],
        'habit_1',
      ).compareTo(habit);

      expect(parity.loggedCurrentStreak, 1);
      expect(parity.storedCurrentStreak, 1);
      expect(parity.loggedTotalCompletions, 3);
      expect(parity.verdict, ParityVerdict.agrees);
    });
  });

  group('parity', () {
    test('agrees when the log matches counters built by the write path', () {
      final days = _days(6);
      final habit = _habitCompletedOn(days);
      final completions = [for (final d in days) _completion('habit_1', d)];

      final parity =
          HabitLogProjection.from(completions, 'habit_1').compareTo(habit);

      expect(parity.verdict, ParityVerdict.agrees);
      expect(parity.isConsistent, isTrue);
      expect(parity.loggedCurrentStreak, 6);
      expect(parity.storedCurrentStreak, 6);
      expect(parity.loggedTotalCompletions, 6);
    });

    test('agrees for a habit with no history on either side', () {
      final parity =
          HabitLogProjection.from(const [], 'habit_1').compareTo(_habit());

      expect(parity.verdict, ParityVerdict.agrees);
      expect(parity.lastLoggedCompletion, isNull);
    });

    test('agrees after an un-completion shortens both sides by one', () {
      final days = _days(5);
      var habit = _habitCompletedOn(days);
      var completions = [for (final d in days) _completion('habit_1', d)];

      // Drive the same write path and drop the same row, as
      // HabitController.uncompleteHabit does: the most recent day.
      habit = habit.copyWithUncompletion();
      completions = completions.sublist(0, days.length - 1);

      final parity =
          HabitLogProjection.from(completions, 'habit_1').compareTo(habit);

      expect(parity.verdict, ParityVerdict.agrees);
      expect(parity.storedCurrentStreak, 4);
      expect(parity.loggedCurrentStreak, 4);

      // longestStreak is intentionally NOT part of the verdict:
      // copyWithUncompletion keeps it as a high-water mark (the run was achieved)
      // while the log can only re-derive the run that survives the removed row.
      // Comparing the two would flag every un-completion as a divergence.
      expect(parity.storedLongestStreak, 5);
      expect(parity.loggedLongestStreak, 4);
    });

    test('counterAheadOfLog when the counter claims a row that is missing', () {
      final days = _days(4);
      final habit = _habitCompletedOn(days);
      // The log lost its most recent row but the counter kept the streak.
      final completions = [
        for (final d in days) _completion('habit_1', d),
      ]..removeLast();

      final parity =
          HabitLogProjection.from(completions, 'habit_1').compareTo(habit);

      expect(parity.verdict, ParityVerdict.counterAheadOfLog);
      expect(parity.storedCurrentStreak, 4);
      expect(parity.loggedCurrentStreak, 3);
      expect(parity.lastLoggedCompletion, DateTime(2026, 3, 19));
    });

    test('logAheadOfCounter when a row was written without the counter', () {
      final days = _days(3);
      final habit = _habitCompletedOn(days);
      final completions = [
        for (final d in days) _completion('habit_1', d),
        _completion('habit_1', DateTime(2026, 3, 21)),
      ];

      final parity =
          HabitLogProjection.from(completions, 'habit_1').compareTo(habit);

      expect(parity.verdict, ParityVerdict.logAheadOfCounter);
      expect(parity.storedTotalCompletions, 3);
      expect(parity.loggedTotalCompletions, 4);
    });

    test('chainDisagrees when totals balance but the current streak does not',
        () {
      // Two separate two-day runs: the log's current chain is 2, so a counter
      // reading 4 means the gap was mistaken for continuity. currentStreak *is*
      // reconstructible, so unlike longestStreak this is a real inconsistency.
      final completions = [
        _completion('habit_1', DateTime(2026, 3, 20)),
        _completion('habit_1', DateTime(2026, 3, 19)),
        _completion('habit_1', DateTime(2026, 3, 16)),
        _completion('habit_1', DateTime(2026, 3, 15)),
      ];
      final habit = _habit(
        currentStreak: 4,
        longestStreak: 4,
        totalCompletions: 4,
        lastCompletedAt: DateTime(2026, 3, 20, 9),
      );

      final parity =
          HabitLogProjection.from(completions, 'habit_1').compareTo(habit);

      expect(parity.verdict, ParityVerdict.chainDisagrees);
      expect(parity.storedTotalCompletions, parity.loggedTotalCompletions);
      expect(parity.storedCurrentStreak, isNot(parity.loggedCurrentStreak));
    });

    test('catches a habit claiming completions it never logged', () {
      final habit = _habit(
        currentStreak: 9,
        longestStreak: 9,
        totalCompletions: 9,
      );

      final parity =
          HabitLogProjection.from(const [], 'habit_1').compareTo(habit);

      expect(parity.verdict, ParityVerdict.counterAheadOfLog);
      expect(parity.loggedTotalCompletions, 0);
      expect(parity.storedTotalCompletions, 9);
    });
  });

  group('parityReportFor', () {
    test('reports every habit, consistent or not', () {
      final consistent = _habitCompletedOn(_days(2), id: 'habit_ok');
      final broken = _habit(
        id: 'habit_bad',
        currentStreak: 5,
        longestStreak: 5,
        totalCompletions: 5,
      );
      final neverDone = _habit(id: 'habit_new');

      final report = parityReportFor(
        habits: [consistent, broken, neverDone],
        completions: [
          for (final d in _days(2)) _completion('habit_ok', d),
        ],
      );

      expect(
          report.map((p) => p.habitId), ['habit_ok', 'habit_bad', 'habit_new']);
      expect(divergentParities(report).map((p) => p.habitId), ['habit_bad']);
      expect(
        report.firstWhere((p) => p.habitId == 'habit_new').verdict,
        ParityVerdict.agrees,
      );
    });
  });
}
