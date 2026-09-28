import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_completion.dart';
import '../../domain/repositories/habit_repository.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';

part 'habit_controller.freezed.dart';

// Helper functions for Either shortcuts
Either<L, R> left<L, R>(L value) => Either<L, R>.left(value);
Either<L, R> right<L, R>(R value) => Either<L, R>.right(value);

@freezed
abstract class HabitState with _$HabitState {
  const factory HabitState({
    @Default([]) List<Habit> habits,
    @Default([]) List<HabitCompletion> todaysCompletions,
    @Default(false) bool isLoading,
    @Default(false) bool isCreating,
    @Default(false) bool isUpdating,
    String? error,
    DateTime? selectedDate,
  }) = _HabitState;
}

class HabitController extends StateNotifier<HabitState> {
  final HabitRepository _repository;

  HabitController(this._repository) : super(const HabitState()) {
    _loadInitialData();
  }

  /// The day the loaded completion list refers to: the user-selected date, or
  /// today when the user has not picked one.
  DateTime get targetDate => state.selectedDate ?? DateTime.now();

  /// Habits that are active and scheduled on [date]. Pure so the providers and
  /// the controller can never disagree.
  static List<Habit> dueHabitsFor(List<Habit> habits, DateTime date) =>
      habits.where((h) => !h.isArchived && h.isDueOnDate(date)).toList();

  /// Share of the habits due on [date] that already have a completion.
  static double progressFor({
    required List<Habit> habits,
    required List<HabitCompletion> completions,
    DateTime? date,
  }) {
    final due = dueHabitsFor(habits, date ?? DateTime.now());
    if (due.isEmpty) return 1.0;
    final dueIds = due.map((h) => h.id).toSet();
    final completedDue =
        completions.map((c) => c.habitId).toSet().intersection(dueIds).length;
    return (completedDue / due.length).clamp(0.0, 1.0);
  }

  Habit? _findHabit(String habitId) {
    for (final habit in state.habits) {
      if (habit.id == habitId) return habit;
    }
    return null;
  }

  Future<void> _loadInitialData() async {
    state = state.copyWith(isLoading: true, error: null);

    final habitsResult = await _repository.getAllHabits();
    final completionsResult =
        await _repository.getCompletionsForDate(targetDate);
    // The provider can be disposed while the load is in flight; writing state
    // afterwards throws `Bad state`.
    if (!mounted) return;

    if (habitsResult.isLeft) {
      state = state.copyWith(
          isLoading: false, error: habitsResult.left!.userMessage);
      return;
    }
    final habits = habitsResult.right!;

    if (completionsResult.isLeft) {
      state = state.copyWith(
        isLoading: false,
        habits: habits,
        error: completionsResult.left!.userMessage,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        habits: habits,
        todaysCompletions: completionsResult.right!,
      );
    }
  }

  Future<void> refresh() async {
    await _loadInitialData();
  }

  Future<Result<Habit>> createHabit({
    required String title,
    required String category,
    String description = '',
    String frequency = 'Daily',
    List<int> customWeekdays = const [],
    String timeOfDay = 'Morning',
    int targetCount = 1,
    Duration targetDuration = const Duration(minutes: 0),
    String cue = '',
  }) async {
    state = state.copyWith(isCreating: true, error: null);

    final habit = Habit.create(
      title: title,
      category: category,
      description: description,
      frequency: frequency,
      customWeekdays: customWeekdays,
      timeOfDay: timeOfDay,
      targetCount: targetCount,
      targetDuration: targetDuration,
      cue: cue,
      sortOrder: state.habits.length,
    );

    final result = await _repository.createHabit(habit);

    if (result.isLeft) {
      state =
          state.copyWith(isCreating: false, error: result.left!.userMessage);
    } else {
      state = state.copyWith(
        isCreating: false,
        habits: [...state.habits, result.right!]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      );
    }

    return result;
  }

  Future<Result<Habit>> updateHabit(Habit habit) async {
    state = state.copyWith(isUpdating: true, error: null);

    final result = await _repository.updateHabit(habit);

    if (result.isLeft) {
      state =
          state.copyWith(isUpdating: false, error: result.left!.userMessage);
    } else {
      state = state.copyWith(
        isUpdating: false,
        habits: state.habits
            .map<Habit>((h) => h.id == result.right!.id ? result.right! : h)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      );
    }

    return result;
  }

  Future<Result<void>> deleteHabit(String id) async {
    state = state.copyWith(isUpdating: true, error: null);

    final result = await _repository.deleteHabit(id);

    if (result.isLeft) {
      state =
          state.copyWith(isUpdating: false, error: result.left!.userMessage);
    } else {
      state = state.copyWith(
        isUpdating: false,
        habits: state.habits.where((h) => h.id != id).toList(),
        todaysCompletions:
            state.todaysCompletions.where((c) => c.habitId != id).toList(),
      );
    }

    return result;
  }

  Future<Result<void>> archiveHabit(String id) async {
    final result = await _repository.archiveHabit(id);

    if (result.isLeft) {
      state = state.copyWith(error: result.left!.userMessage);
    } else {
      state = state.copyWith(
        habits: state.habits
            .map((h) => h.id == id ? h.copyWith(isArchived: true) : h)
            .toList(),
      );
    }

    return result;
  }

  Future<Result<void>> unarchiveHabit(String id) async {
    final result = await _repository.unarchiveHabit(id);

    if (result.isLeft) {
      state = state.copyWith(error: result.left!.userMessage);
    } else {
      state = state.copyWith(
        habits: state.habits
            .map((h) => h.id == id ? h.copyWith(isArchived: false) : h)
            .toList(),
      );
    }

    return result;
  }

  Future<Result<void>> reorderHabits(int oldIndex, int newIndex) async {
    if (oldIndex < 0 ||
        oldIndex >= state.habits.length ||
        newIndex < 0 ||
        newIndex >= state.habits.length) {
      return Either.left(const ValidationFailure('Invalid indices'));
    }

    final habits = List<Habit>.from(state.habits);
    final habit = habits.removeAt(oldIndex);
    habits.insert(newIndex, habit);

    final habitIds = habits.map((h) => h.id).toList();
    final result = await _repository.reorderHabits(habitIds);

    if (result.isLeft) {
      state = state.copyWith(error: result.left!.userMessage);
    } else {
      final updatedHabits = habits.asMap().entries.map((entry) {
        final index = entry.key;
        final h = entry.value;
        return h.copyWith(sortOrder: index);
      }).toList();
      state = state.copyWith(habits: updatedHabits);
    }

    return result;
  }

  Future<Result<HabitCompletion>> completeHabit(
    String habitId, {
    int count = 1,
    Duration? duration,
    String? note,
    int? moodRating,
    int? energyRating,
  }) async {
    final habit = _findHabit(habitId);
    if (habit == null) {
      return Either.left(NotFoundFailure('Habit $habitId not found'));
    }

    // Completions are loaded for the selected day, so the guard must check
    // that list too instead of only `isCompletedToday`.
    final isAlreadyCompleted = habit.isCompletedOn(targetDate) ||
        state.todaysCompletions.any((c) => c.habitId == habitId);

    if (isAlreadyCompleted) {
      return Either.left(
          ValidationFailure('${habit.title} is already completed'));
    }

    final completion = HabitCompletion.create(
      habitId: habitId,
      count: count,
      duration: duration,
      note: note,
      moodRating: moodRating,
      energyRating: energyRating,
    );

    final completionResult = await _repository.createCompletion(completion);

    if (completionResult.isLeft) {
      return Either.left(completionResult.left!);
    }

    final created = completionResult.right!;
    final updatedHabit = habit.copyWithCompletion(
      completed: true,
      completionTime: created.completedAt,
    );
    await _repository.updateHabit(updatedHabit);

    state = state.copyWith(
      habits:
          state.habits.map((h) => h.id == habitId ? updatedHabit : h).toList(),
      todaysCompletions: [...state.todaysCompletions, created],
    );

    return Either.right(created);
  }

  Future<Result<void>> uncompleteHabit(String habitId) async {
    final habit = _findHabit(habitId);
    if (habit == null) {
      return Either.left(NotFoundFailure('Habit $habitId not found'));
    }

    HabitCompletion? completion;
    for (final candidate in state.todaysCompletions) {
      if (candidate.habitId == habitId) {
        completion = candidate;
        break;
      }
    }
    if (completion == null) {
      return Either.left(
          NotFoundFailure('${habit.title} has no completion to undo'));
    }

    final deleteResult = await _repository.deleteCompletion(completion.id);

    if (deleteResult.isLeft) {
      return Either.left(deleteResult.left!);
    }

    final updatedHabit = habit.copyWithUncompletion();
    await _repository.updateHabit(updatedHabit);

    state = state.copyWith(
      habits:
          state.habits.map((h) => h.id == habitId ? updatedHabit : h).toList(),
      todaysCompletions:
          state.todaysCompletions.where((c) => c.habitId != habitId).toList(),
    );

    return Either.right(null);
  }

  Future<Result<void>> useStreakFreeze(String habitId) async {
    final habit = _findHabit(habitId);
    if (habit == null) {
      return Either.left(NotFoundFailure('Habit $habitId not found'));
    }

    if (habit.streakFreezesUsed >= AppConstants.maxStreakFreezes) {
      return Either.left(
          const ValidationFailure('Maximum streak freezes reached'));
    }

    final updatedHabit = habit.useStreakFreeze();
    final result = await _repository.updateHabit(updatedHabit);

    if (result.isLeft) {
      state = state.copyWith(error: result.left!.userMessage);
    } else {
      state = state.copyWith(
        habits: state.habits
            .map((h) => h.id == habitId ? updatedHabit : h)
            .toList(),
      );
    }

    return result;
  }

  void setSelectedDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
    _loadCompletionsForDate(date);
  }

  Future<void> _loadCompletionsForDate(DateTime date) async {
    // The completion list always belongs to `selectedDate`: clear it first so
    // the previous day's entries can not inflate the progress bar while the
    // newly selected day is still loading.
    state = state.copyWith(todaysCompletions: const [], error: null);
    final result = await _repository.getCompletionsForDate(date);
    if (!mounted) return;
    if (result.isLeft) {
      state = state.copyWith(error: result.left!.userMessage);
    } else {
      state = state.copyWith(todaysCompletions: result.right!);
    }
  }

  List<Habit> getHabitsForCategory(String category) {
    return state.habits
        .where((h) => h.category == category && !h.isArchived)
        .toList();
  }

  List<Habit> getDueHabits({DateTime? date}) =>
      dueHabitsFor(state.habits, date ?? targetDate);

  int getCompletionCount({DateTime? date}) {
    final checkDate = date ?? targetDate;
    final dueIds =
        dueHabitsFor(state.habits, checkDate).map((h) => h.id).toSet();
    return state.todaysCompletions
        .map((c) => c.habitId)
        .toSet()
        .intersection(dueIds)
        .length;
  }

  int getDueCount({DateTime? date}) => getDueHabits(date: date).length;

  double getTodaysProgress() => progressFor(
        habits: state.habits,
        completions: state.todaysCompletions,
        date: targetDate,
      );
}
