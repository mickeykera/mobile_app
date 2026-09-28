import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/core/errors/failures.dart';
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

  Failure? _consumeFailure() {
    final failure = nextWriteFailure;
    nextWriteFailure = null;
    return failure;
  }

  @override
  Future<Result<List<Habit>>> getAllHabits(
          {bool includeArchived = false}) async =>
      Either.right(includeArchived
          ? habits
          : habits.where((h) => !h.isArchived).toList());

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
