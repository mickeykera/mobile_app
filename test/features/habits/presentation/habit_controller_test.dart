import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/core/errors/failures.dart';
import 'package:ascend/core/extensions/date_extensions.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/habits/domain/entities/habit_completion.dart';
import 'package:ascend/features/habits/domain/repositories/habit_repository.dart';
import 'package:ascend/features/habits/presentation/controllers/habit_controller.dart';
import 'package:ascend/features/habits/presentation/providers/habit_providers.dart';

class FakeHabitRepository implements HabitRepository {
  FakeHabitRepository({List<Habit>? habits, List<HabitCompletion>? completions})
      : habits = List.of(habits ?? const <Habit>[]),
        completions = List.of(completions ?? const <HabitCompletion>[]);

  final List<Habit> habits;
  final List<HabitCompletion> completions;

  /// Set to simulate a persistence failure on the next write.
  Failure? nextWriteFailure;

  /// How many times the habit list has been read, so timer-driven refreshes can
  /// be observed.
  int getAllHabitsCalls = 0;

  Failure? _consumeFailure() {
    final failure = nextWriteFailure;
    nextWriteFailure = null;
    return failure;
  }

  @override
  Future<Result<List<Habit>>> getAllHabits(
      {bool includeArchived = false}) async {
    getAllHabitsCalls++;
    return Either.right(
        includeArchived ? habits : habits.where((h) => !h.isArchived).toList());
  }

  @override
  Future<Result<Habit?>> getHabitById(String id) async {
    for (final habit in habits) {
      if (habit.id == id) return Either.right(habit);
    }
    return Either.right(null);
  }

  @override
  Future<Result<Habit>> createHabit(Habit habit) async {
    habits.add(habit);
    return Either.right(habit);
  }

  @override
  Future<Result<Habit>> updateHabit(Habit habit) async {
    final failure = _consumeFailure();
    if (failure != null) return Either.left(failure);
    final index = habits.indexWhere((h) => h.id == habit.id);
    if (index >= 0) habits[index] = habit;
    return Either.right(habit);
  }

  @override
  Future<Result<void>> deleteHabit(String id) async {
    habits.removeWhere((h) => h.id == id);
    return Either.right(null);
  }

  @override
  Future<Result<void>> archiveHabit(String id) async {
    final index = habits.indexWhere((h) => h.id == id);
    if (index >= 0) habits[index] = habits[index].copyWith(isArchived: true);
    return Either.right(null);
  }

  @override
  Future<Result<void>> unarchiveHabit(String id) async {
    final index = habits.indexWhere((h) => h.id == id);
    if (index >= 0) habits[index] = habits[index].copyWith(isArchived: false);
    return Either.right(null);
  }

  @override
  Future<Result<void>> reorderHabits(List<String> habitIds) async =>
      Either.right(null);

  @override
  Future<Result<List<HabitCompletion>>> getCompletionsForHabit(
    String habitId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async =>
      Either.right(completions.where((c) => c.habitId == habitId).toList());

  @override
  Future<Result<List<HabitCompletion>>> getCompletionsForDate(
      DateTime date) async {
    return Either.right(completions
        .where((c) => _sameDay(c.completedAt, date))
        .toList(growable: false));
  }

  @override
  Future<Result<List<HabitCompletion>>> getAllCompletions() async {
    return Either.right(List.of(completions));
  }

  @override
  Future<Result<List<HabitCompletion>>> getCompletionsInRange(
      DateTime start, DateTime end) async {
    return Either.right(completions
        .where((c) =>
            !c.completedAt.isBefore(start.startOfDay) &&
            !c.completedAt.isAfter(end.endOfDay))
        .toList(growable: false));
  }

  @override
  Future<Result<HabitCompletion>> createCompletion(
      HabitCompletion completion) async {
    final failure = _consumeFailure();
    if (failure != null) return Either.left(failure);
    completions.add(completion);
    return Either.right(completion);
  }

  @override
  Future<Result<void>> deleteCompletion(String id) async {
    completions.removeWhere((c) => c.id == id);
    return Either.right(null);
  }

  @override
  Future<Result<int>> getCurrentStreak(String habitId) async => Either.right(0);

  @override
  Future<Result<int>> getLongestStreak(String habitId) async => Either.right(0);

  @override
  Future<Result<double>> getCompletionRate(String habitId,
          {DateTime? startDate, DateTime? endDate}) async =>
      Either.right(0.0);

  @override
  Future<Result<Map<DateTime, int>>> getCompletionHeatmap(String habitId,
          {int weeks = 12}) async =>
      Either.right(const {});

  @override
  Future<Result<HabitCompletion>> recordRecurringTaskOccurrence({
    required String taskId,
    required DateTime date,
    required int count,
    Duration? duration,
    String? note,
    int? moodRating,
    int? energyRating,
  }) async {
    final dayStart = date.startOfDay;
    final dayEnd = date.endOfDay;

    // Same-day dedupe
    for (final c in completions) {
      if (c.itemId == taskId &&
          c.itemType == 'task' &&
          !c.completedAt.isBefore(dayStart) &&
          !c.completedAt.isAfter(dayEnd)) {
        return Either.right(c);
      }
    }

    final now = AppClock.now();
    final completedAt = DateTime(
      date.year,
      date.month,
      date.day,
      now.hour,
      now.minute,
    );
    final completion = HabitCompletion.create(
      habitId: null,
      itemId: taskId,
      itemType: 'task',
      count: count,
      duration: duration,
      note: note,
      moodRating: moodRating,
      energyRating: energyRating,
    ).copyWith(completedAt: completedAt);

    completions.add(completion);
    return Either.right(completion);
  }

  @override
  Future<Result<void>> deleteRecurringTaskOccurrence({
    required String taskId,
    required DateTime date,
  }) async {
    final dayStart = date.startOfDay;
    final dayEnd = date.endOfDay;

    completions.removeWhere(
      (c) =>
          c.itemId == taskId &&
          c.itemType == 'task' &&
          !c.completedAt.isBefore(dayStart) &&
          !c.completedAt.isAfter(dayEnd),
    );
    return Either.right(null);
  }

  @override
  Future<Result<void>> reconcileHabitToTask({
    required String habitId,
    required String taskId,
  }) async {
    final habitCompletions = completions
        .where((c) => c.ownerId == habitId && c.isHabitCompletion)
        .toList();

    final taskCompletions = completions
        .where((c) => c.itemId == taskId && c.itemType == 'task')
        .toList();

    final taskByDate = <DateTime, HabitCompletion>{};
    for (final c in taskCompletions) {
      taskByDate[c.completedAt.startOfDay] = c;
    }

    for (final habitCompletion in habitCompletions) {
      final day = habitCompletion.completedAt.startOfDay;
      final existing = taskByDate[day];
      if (existing == null) {
        final newCompletion = HabitCompletion.create(
          habitId: null,
          itemId: taskId,
          itemType: 'task',
          count: habitCompletion.count,
          duration: habitCompletion.duration,
          note: habitCompletion.note,
          moodRating: habitCompletion.moodRating,
          energyRating: habitCompletion.energyRating,
        ).copyWith(completedAt: habitCompletion.completedAt);
        completions.add(newCompletion);
      }
    }

    final habitDates =
        habitCompletions.map((c) => c.completedAt.startOfDay).toSet();
    final orphaned = taskCompletions
        .where((c) => !habitDates.contains(c.completedAt.startOfDay))
        .toList();

    for (final orphan in orphaned) {
      completions.removeWhere((c) => c.id == orphan.id);
    }

    return Either.right(null);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

Habit _buildHabit({
  String title = 'Drink water',
  String frequency = 'Daily',
  List<int> customWeekdays = const [],
  bool isArchived = false,
  int streakFreezesUsed = 0,
  int totalCompletions = 0,
}) {
  final habit = Habit.create(
    title: title,
    category: 'Body',
    frequency: frequency,
    customWeekdays: customWeekdays,
  );
  return habit.copyWith(
    isArchived: isArchived,
    streakFreezesUsed: streakFreezesUsed,
    totalCompletions: totalCompletions,
  );
}

void main() {
  group('HabitController load', () {
    test('loads habits and the completions of the selected day', () async {
      final habit = _buildHabit();
      final completion = HabitCompletion(
        id: 'c1',
        habitId: habit.id,
        completedAt: DateTime.now(),
        count: 1,
      );
      final repository = FakeHabitRepository(
        habits: [habit],
        completions: [completion],
      );

      final controller = HabitController(repository);
      await pumpEventQueue();

      expect(controller.state.habits, hasLength(1));
      expect(controller.state.todaysCompletions, hasLength(1));
      expect(controller.state.isLoading, isFalse);
      expect(controller.getTodaysProgress(), 1.0);
      controller.dispose();
    });
  });

  group('HabitController guards', () {
    test('completing an unknown habit returns NotFoundFailure', () async {
      final repository = FakeHabitRepository(habits: [_buildHabit()]);
      final controller = HabitController(repository);
      await pumpEventQueue();

      final result = await controller.completeHabit('missing');

      expect(result.isLeft, isTrue);
      expect(result.left, isA<NotFoundFailure>());
      controller.dispose();
    });

    test('un-completing an unknown habit returns NotFoundFailure', () async {
      final repository = FakeHabitRepository(habits: [_buildHabit()]);
      final controller = HabitController(repository);
      await pumpEventQueue();

      final result = await controller.uncompleteHabit('missing');

      expect(result.isLeft, isTrue);
      expect(result.left, isA<NotFoundFailure>());
      controller.dispose();
    });

    test('a streak freeze on an unknown habit returns NotFoundFailure',
        () async {
      final repository = FakeHabitRepository(habits: [_buildHabit()]);
      final controller = HabitController(repository);
      await pumpEventQueue();

      final result = await controller.useStreakFreeze('missing');

      expect(result.isLeft, isTrue);
      expect(result.left, isA<NotFoundFailure>());
      controller.dispose();
    });

    test('completing an already completed habit is rejected', () async {
      final habit = _buildHabit();
      final repository = FakeHabitRepository(habits: [habit]);
      final controller = HabitController(repository);
      await pumpEventQueue();

      final first = await controller.completeHabit(habit.id);
      expect(first.isRight, isTrue);

      final second = await controller.completeHabit(habit.id);
      expect(second.isLeft, isTrue);
      expect(second.left, isA<ValidationFailure>());
      expect(controller.state.todaysCompletions, hasLength(1));
      controller.dispose();
    });

    test('streak freezes are capped at the configured maximum', () async {
      final habit = _buildHabit(streakFreezesUsed: 3);
      final repository = FakeHabitRepository(habits: [habit]);
      final controller = HabitController(repository);
      await pumpEventQueue();

      final result = await controller.useStreakFreeze(habit.id);

      expect(result.isLeft, isTrue);
      expect(result.left, isA<ValidationFailure>());
      controller.dispose();
    });
  });
  group('HabitController completion cycle', () {
    test('complete then un-complete leaves no trace', () async {
      final habit = _buildHabit();
      final repository = FakeHabitRepository(habits: [habit]);
      final controller = HabitController(repository);
      await pumpEventQueue();

      await controller.completeHabit(habit.id);
      expect(controller.state.todaysCompletions, hasLength(1));
      expect(controller.state.habits.first.currentStreak, 1);

      final result = await controller.uncompleteHabit(habit.id);
      expect(result.isRight, isTrue);
      expect(controller.state.todaysCompletions, isEmpty);
      expect(controller.state.habits.first.currentStreak, 0);
      expect(controller.state.habits.first.totalCompletions, 0);
      expect(controller.getTodaysProgress(), 0.0);
      controller.dispose();
    });

    test('persistence failure reports the failure without mutating state',
        () async {
      final habit = _buildHabit();
      final repository = FakeHabitRepository(habits: [habit]);
      final controller = HabitController(repository);
      await pumpEventQueue();

      repository.nextWriteFailure = const CacheFailure('disk full');
      final result = await controller.completeHabit(habit.id);

      expect(result.isLeft, isTrue);
      expect(controller.state.todaysCompletions, isEmpty);
      expect(controller.state.habits.first.totalCompletions, 0);
      controller.dispose();
    });
  });

  group('HabitController date selection', () {
    test('completions are loaded for the selected day only', () async {
      final habit = _buildHabit();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final repository = FakeHabitRepository(
        habits: [habit],
        completions: [
          HabitCompletion(
            id: 'old',
            habitId: habit.id,
            completedAt: yesterday,
            count: 1,
          ),
        ],
      );
      final controller = HabitController(repository);
      await pumpEventQueue();

      expect(controller.state.todaysCompletions, isEmpty,
          reason: 'the stale completion belongs to yesterday');

      controller.setSelectedDate(yesterday);
      await pumpEventQueue();
      expect(controller.state.todaysCompletions, hasLength(1));
      expect(controller.getTodaysProgress(), 1.0);
      controller.dispose();
    });
  });

  group('HabitController snooze and reschedule', () {
    // 2025-06-11 is a Wednesday.
    final wednesday = DateTime(2025, 6, 11, 9, 0);

    setUp(() => AppClock.debugSetNow(() => wednesday));
    tearDown(AppClock.debugResetNow);

    test('snoozing removes the habit from the workload without completing it',
        () async {
      final habit = _buildHabit();
      final repository = FakeHabitRepository(habits: [habit]);
      final controller = HabitController(repository);
      await pumpEventQueue();

      final until = wednesday.add(const Duration(hours: 3));
      final result = await controller.snoozeHabit(habit.id, until);

      expect(result.isRight, isTrue);
      expect(controller.state.habits.single.snoozedUntil, until);
      expect(controller.state.habits.single.totalCompletions, 0);
      expect(repository.completions, isEmpty,
          reason: 'a snooze is not a completion');
      expect(controller.getDueHabits(), isEmpty);
      controller.dispose();
    });

    test('a snooze in the past is rejected', () async {
      final habit = _buildHabit();
      final repository = FakeHabitRepository(habits: [habit]);
      final controller = HabitController(repository);
      await pumpEventQueue();

      final result = await controller.snoozeHabit(
          habit.id, wednesday.subtract(const Duration(minutes: 1)));

      expect(result.isLeft, isTrue);
      expect(result.left, isA<ValidationFailure>());
      expect(controller.state.habits.single.snoozedUntil, isNull);
      controller.dispose();
    });

    test('the hold ends and the habit returns when the snooze elapses',
        () async {
      var now = wednesday;
      AppClock.debugSetNow(() => now);
      final habit = _buildHabit();
      final repository = FakeHabitRepository(habits: [habit]);
      final controller = HabitController(repository);
      await pumpEventQueue();

      await controller.snoozeHabit(
          habit.id, wednesday.add(const Duration(hours: 2)));
      expect(controller.getDueHabits(), isEmpty);

      now = wednesday.add(const Duration(hours: 3));
      expect(controller.getDueHabits(), hasLength(1),
          reason: 'the expired hold must stop hiding the habit');
      controller.dispose();
    });

    test('rescheduling overrides recurrence and clears an active snooze',
        () async {
      final habit = _buildHabit(frequency: 'Weekdays');
      final repository = FakeHabitRepository(habits: [habit]);
      final controller = HabitController(repository);
      await pumpEventQueue();

      await controller.snoozeHabit(
          habit.id, wednesday.add(const Duration(hours: 3)));

      final saturday = DateTime(2025, 6, 14, 9);
      final result = await controller.rescheduleHabit(habit.id, saturday);

      expect(result.isRight, isTrue);
      final stored = controller.state.habits.single;
      expect(stored.dueAt, saturday);
      expect(stored.snoozedUntil, isNull);
      expect(stored.isDueOnDate(DateTime(2025, 6, 13)), isFalse);
      expect(stored.isDueOnDate(saturday), isTrue);
      controller.dispose();
    });

    test('a persistence failure leaves the habit untouched', () async {
      final habit = _buildHabit();
      final repository = FakeHabitRepository(habits: [habit]);
      final controller = HabitController(repository);
      await pumpEventQueue();

      repository.nextWriteFailure = const CacheFailure('disk full');
      final result = await controller.snoozeHabit(
          habit.id, wednesday.add(const Duration(hours: 2)));

      expect(result.isLeft, isTrue);
      expect(controller.state.habits.single.snoozedUntil, isNull);
      controller.dispose();
    });

    test('snoozing an unknown habit returns NotFoundFailure', () async {
      final controller = HabitController(FakeHabitRepository());
      await pumpEventQueue();

      final result = await controller.snoozeHabit(
          'missing', wednesday.add(const Duration(hours: 2)));

      expect(result.isLeft, isTrue);
      expect(result.left, isA<NotFoundFailure>());
      controller.dispose();
    });

    test('the expiry timer refreshes the workload when the hold ends',
        () async {
      var now = wednesday;
      AppClock.debugSetNow(() => now);
      final habit = _buildHabit();
      final repository = FakeHabitRepository(habits: [habit]);
      final controller = HabitController(repository);
      await pumpEventQueue();
      expect(controller.getDueHabits(), hasLength(1));

      // A real (tiny) hold, so the scheduled Timer actually fires mid-test.
      now = wednesday.add(const Duration(hours: 3));
      final until = now.add(const Duration(milliseconds: 50));
      await controller.snoozeHabit(habit.id, until);
      expect(controller.getDueHabits(), isEmpty);

      // Let the hold elapse on both clocks: the pinned app clock and the real
      // timer that watches it.
      now = until.add(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await pumpEventQueue();

      expect(controller.getDueHabits(), hasLength(1),
          reason: 'the timer-driven refresh must restore the habit');
      controller.dispose();
    });

    test('disposing the controller cancels a pending expiry timer', () async {
      var now = wednesday;
      AppClock.debugSetNow(() => now);
      final habit = _buildHabit();
      final repository = FakeHabitRepository(habits: [habit]);
      final controller = HabitController(repository);
      await pumpEventQueue();
      final callsBefore = repository.getAllHabitsCalls;

      final until = now.add(const Duration(milliseconds: 50));
      await controller.snoozeHabit(habit.id, until);
      controller.dispose();

      now = until.add(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await pumpEventQueue();

      expect(repository.getAllHabitsCalls, callsBefore,
          reason: 'a disposed controller must not refresh');
    });

    test('replacing a snooze leaves no stale expiry timer', () async {
      var now = wednesday;
      AppClock.debugSetNow(() => now);
      final habit = _buildHabit();
      final repository = FakeHabitRepository(habits: [habit]);
      final controller = HabitController(repository);
      await pumpEventQueue();

      await controller.snoozeHabit(
          habit.id, now.add(const Duration(milliseconds: 50)));

      // Re-snooze before the first hold expires, pushing the deadline out.
      now = wednesday.add(const Duration(minutes: 1));
      await controller.snoozeHabit(habit.id, now.add(const Duration(hours: 2)));
      final callsBefore = repository.getAllHabitsCalls;

      // Wait past the first hold's original deadline. Because that timer was
      // replaced, it must not fire and refresh the workload.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await pumpEventQueue();

      expect(repository.getAllHabitsCalls, callsBefore,
          reason: 'the replaced timer must have been cancelled');
      expect(controller.getDueHabits(), isEmpty);
      controller.dispose();
    });
  });

  group('pure progress helpers', () {
    test('dueHabitsFor drops archived and non-due habits', () {
      final daily = _buildHabit(title: 'daily');
      final weekendOnly = _buildHabit(title: 'weekend', frequency: 'Weekends');
      final archived = _buildHabit(title: 'archived', isArchived: true);
      final monday = DateTime(2024, 1, 8);

      final due = HabitController.dueHabitsFor(
        [daily, weekendOnly, archived],
        monday,
      );

      expect(due.map((h) => h.title), ['daily']);
    });

    test('progressFor counts only due habits that are completed', () {
      final done = _buildHabit(title: 'done');
      final pending = _buildHabit(title: 'pending');
      final monday = DateTime(2024, 1, 8);
      final completion = HabitCompletion(
        id: 'c',
        habitId: done.id,
        completedAt: monday,
        count: 1,
      );

      expect(
        HabitController.progressFor(
          habits: [done, pending],
          completions: [completion],
          date: monday,
        ),
        0.5,
      );

      expect(
        HabitController.progressFor(
          habits: [done],
          completions: [completion],
          date: monday,
        ),
        1.0,
      );
    });

    test('progressFor with nothing due reads as complete', () {
      expect(
        HabitController.progressFor(
          habits: [_buildHabit(frequency: 'Weekends')],
          completions: const [],
          date: DateTime(2024, 1, 8), // Monday
        ),
        1.0,
      );
    });
  });

  group('derived providers stay in sync', () {
    test('todaysProgressProvider recomputes after the state changes', () async {
      final habit = _buildHabit();
      final repository = FakeHabitRepository(habits: [habit]);
      final container = ProviderContainer(
        overrides: [
          habitControllerProvider
              .overrideWith((ref) => HabitController(repository)),
        ],
      );
      addTearDown(container.dispose);
      // Touch the provider so the controller (and its initial load) exists
      // before we start pumping the event queue.
      container.read(habitControllerProvider);
      await pumpEventQueue();

      // Regression: these providers used to watch `...provider.notifier`,
      // which never re-notifies, so the header progress bar stayed frozen.
      expect(container.read(todaysProgressProvider), 0.0);

      await container
          .read(habitControllerProvider.notifier)
          .completeHabit(habit.id);

      expect(container.read(todaysProgressProvider), 1.0);
    });

    test('dueHabitsProvider recomputes after the state changes', () async {
      final habit = _buildHabit();
      final repository = FakeHabitRepository(habits: [habit]);
      final container = ProviderContainer(
        overrides: [
          habitControllerProvider
              .overrideWith((ref) => HabitController(repository)),
        ],
      );
      addTearDown(container.dispose);
      container.read(habitControllerProvider);
      await pumpEventQueue();

      expect(container.read(dueHabitsProvider), hasLength(1));

      await container.read(habitControllerProvider.notifier).refresh();

      expect(container.read(dueHabitsProvider), hasLength(1),
          reason: 'still due after a plain refresh');

      await repository.archiveHabit(habit.id);
      await container.read(habitControllerProvider.notifier).refresh();

      expect(container.read(dueHabitsProvider), isEmpty);
    });
  });
}
