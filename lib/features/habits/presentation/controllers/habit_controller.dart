import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/app_clock.dart';
import '../../../recurring/domain/cutover_write_path.dart';
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

  /// The Stage L2 canonical write path, when the cutover gate is open.
  ///
  /// Null means this controller is a legacy controller by construction: every
  /// write goes to the Habit repository exactly as before. A non-null path
  /// routes only *linked* habits (`taskId != null`) and creates through the
  /// canonical Task, so a quarantined habit still writes legacy.
  final CutoverWritePath? _cutover;

  /// Fires once when the soonest active snooze elapses, so a habit held out of
  /// the workload comes back without the user having to navigate away.
  Timer? _snoozeTimer;

  HabitController(this._repository, {CutoverWritePath? cutover})
      : _cutover = cutover,
        super(const HabitState()) {
    _loadInitialData();
  }

  /// The day the loaded completion list refers to: the user-selected date, or
  /// today when the user has not picked one.
  DateTime get targetDate => state.selectedDate ?? AppClock.now();

  /// Habits that are active and scheduled on [date]. Pure so the providers and
  /// the controller can never disagree.
  static List<Habit> dueHabitsFor(List<Habit> habits, DateTime date) =>
      habits.where((h) => !h.isArchived && h.isDueOnDate(date)).toList();

  /// Share of the habits due on [date] that already have a completion.
  ///
  /// Pass [taskIdToHabitId] — from `ProgressService.habitIdByTaskId` — when the
  /// completion list can hold Task occurrence rows. A migrated habit's
  /// completions are written against its Task, so without the map they are
  /// invisible here and the habit shows as unfinished on a day it was in fact
  /// done. With no map the behaviour is unchanged, which is what every legacy
  /// caller wants.
  static double progressFor({
    required List<Habit> habits,
    required List<HabitCompletion> completions,
    DateTime? date,
    Map<String, String> taskIdToHabitId = const {},
  }) {
    final due = dueHabitsFor(habits, date ?? AppClock.now());
    if (due.isEmpty) return 1.0;
    final dueIds = due.map((h) => h.id).toSet();
    final completedDue =
        _completedIds(completions, taskIdToHabitId).intersection(dueIds).length;
    return (completedDue / due.length).clamp(0.0, 1.0);
  }

  /// The habit ids [completions] credits, resolving Task rows through
  /// [taskIdToHabitId].
  static Set<String> _completedIds(
    List<HabitCompletion> completions,
    Map<String, String> taskIdToHabitId,
  ) {
    final ids = <String>{};
    for (final completion in completions) {
      if (completion.isHabitCompletion) {
        final habitId = completion.habitId;
        if (habitId != null) ids.add(habitId);
      } else if (completion.itemType == 'task') {
        final habitId = taskIdToHabitId[completion.itemId];
        if (habitId != null) ids.add(habitId);
      }
    }
    return ids;
  }

  Habit? _findHabit(String habitId) {
    for (final habit in state.habits) {
      if (habit.id == habitId) return habit;
    }
    return null;
  }

  /// Resolves a habit by id, falling back to storage for one not in [state].
  ///
  /// Archive/unarchive can be asked for an archived habit, which the default
  /// load excludes from [state]; without this fallback a linked archived habit
  /// would silently take the legacy write path on unarchive (Stage L2, D2).
  Future<Habit?> _lookupHabit(String habitId) async {
    final inState = _findHabit(habitId);
    if (inState != null) return inState;
    final result = await _repository.getHabitById(habitId);
    return result.fold((_) => null, (habit) => habit);
  }

  /// Writes [habit] through the canonical path when it is linked and a path is
  /// held, else through the legacy repository.
  Future<Result<Habit>> _writeHabit(Habit habit) {
    final cutover = _cutover;
    if (cutover != null && habit.taskId != null) {
      return cutover.updateMigrated(habit);
    }
    return _repository.updateHabit(habit);
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

    _scheduleSnoozeExpiry();
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
      return result;
    }

    var created = result.right!;
    final cutover = _cutover;
    if (cutover != null) {
      // Stage L2 (D4): a new recurring item is born canonical. Migration links
      // the just-created habit to a Task; if it fails the path deletes the
      // habit again so no half-created item survives.
      final linked = await cutover.linkNewlyCreated(created);
      if (linked.isLeft) {
        state =
            state.copyWith(isCreating: false, error: linked.left!.userMessage);
        return Either.left(linked.left!);
      }
      created = linked.right!;
    }

    state = state.copyWith(
      isCreating: false,
      habits: [...state.habits, created]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    );

    return Either.right(created);
  }

  Future<Result<Habit>> updateHabit(Habit habit) async {
    state = state.copyWith(isUpdating: true, error: null);

    final result = await _writeHabit(habit);

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

    _scheduleSnoozeExpiry();
    return result;
  }

  Future<Result<void>> deleteHabit(String id) async {
    state = state.copyWith(isUpdating: true, error: null);

    final cutover = _cutover;
    Result<void> result;
    final habit = cutover == null ? null : await _lookupHabit(id);
    if (cutover != null && habit != null && habit.taskId != null) {
      // Stage L2 (D3): a migrated habit's delete must take its Task and the
      // Task's occurrence rows with it, in the recoverable order the path owns.
      result = await cutover.deleteMigratedPair(habit);
    } else {
      result = await _repository.deleteHabit(id);
    }

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
    final linked = await _linkedHabitFor(id);
    if (linked != null) {
      final result = await _cutover!.updateMigrated(
        linked.copyWith(isArchived: true, updatedAt: AppClock.now()),
      );
      if (result.isLeft) {
        state = state.copyWith(error: result.left!.userMessage);
        return Either.left(result.left!);
      }
      state = state.copyWith(
        habits: state.habits
            .map((h) => h.id == id ? result.right! : h)
            .toList(),
      );
      return Either.right(null);
    }

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
    final linked = await _linkedHabitFor(id);
    if (linked != null) {
      final result = await _cutover!.updateMigrated(
        linked.copyWith(isArchived: false, updatedAt: AppClock.now()),
      );
      if (result.isLeft) {
        state = state.copyWith(error: result.left!.userMessage);
        return Either.left(result.left!);
      }
      state = state.copyWith(
        habits: state.habits
            .map((h) => h.id == id ? result.right! : h)
            .toList(),
      );
      return Either.right(null);
    }

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

  /// The linked habit behind [id] when a cutover path is held, else null.
  ///
  /// A null result routes the call to the legacy branch, which is correct both
  /// when no path is held (legacy regime) and when the habit is not migrated.
  Future<Habit?> _linkedHabitFor(String id) async {
    final cutover = _cutover;
    if (cutover == null) return null;
    final habit = await _lookupHabit(id);
    if (habit == null || habit.taskId == null) return null;
    return habit;
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

    // Migrated habits (taskId != null): Task is authoritative.
    // Write ONLY to Task occurrence log, do NOT update Habit streaks/counters.
    if (habit.taskId != null) {
      final taskOccurrenceResult =
          await _repository.recordRecurringTaskOccurrence(
        taskId: habit.taskId!,
        date: targetDate,
        count: count,
        duration: duration,
        note: note,
        moodRating: moodRating,
        energyRating: energyRating,
      );

      if (taskOccurrenceResult.isLeft) {
        return Either.left(taskOccurrenceResult.left!);
      }

      // For migrated habits, we don't add to todaysCompletions (which is habit-only)
      // and we don't update the Habit entity. The Task occurrence log is the source.
      return Either.right(taskOccurrenceResult.right!);
    }

    // Non-migrated habits: original Habit completion flow
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

    // Migrated habits (taskId != null): Task is authoritative.
    // Delete from Task occurrence log, do NOT update Habit streaks/counters.
    if (habit.taskId != null) {
      // For migrated habits, we delete the Task occurrence for the target date.
      final taskDeleteResult = await _repository.deleteRecurringTaskOccurrence(
        taskId: habit.taskId!,
        date: targetDate,
      );

      if (taskDeleteResult.isLeft) {
        return Either.left(taskDeleteResult.left!);
      }

      // For migrated habits, we don't update the Habit entity.
      // The Task occurrence log is the source.
      return Either.right(null);
    }

    // Non-migrated habits: original Habit uncompletion flow
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
    final result = await _writeHabit(updatedHabit);

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

  /// Holds [habitId] out of the workload until [until].
  ///
  /// Snoozing is not completing: no completion is written, so the streak and
  /// totals are untouched. The hold is stored on the habit (and therefore
  /// persisted), and the controller schedules a refresh for the moment it ends.
  Future<Result<Habit>> snoozeHabit(String habitId, DateTime until) async {
    final habit = _findHabit(habitId);
    if (habit == null) {
      return Either.left(NotFoundFailure('Habit $habitId not found'));
    }
    if (!until.isAfter(AppClock.now())) {
      return Either.left(
          const ValidationFailure('Snooze time must be in the future'));
    }

    return updateHabit(habit.copyWith(
      snoozedUntil: until,
      updatedAt: AppClock.now(),
    ));
  }

  /// Moves the next occurrence of [habitId] to [dueAt].
  ///
  /// An explicit reschedule supersedes any active snooze, so the hold is cleared.
  Future<Result<Habit>> rescheduleHabit(String habitId, DateTime dueAt) async {
    final habit = _findHabit(habitId);
    if (habit == null) {
      return Either.left(NotFoundFailure('Habit $habitId not found'));
    }

    return updateHabit(habit.copyWith(
      dueAt: dueAt,
      snoozedUntil: null,
      updatedAt: AppClock.now(),
    ));
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

  /// Schedules a single refresh for the moment the soonest active snooze ends.
  ///
  /// The workload is computed at read time, so an expired snooze already reads
  /// as due; this timer is only what makes an open screen notice.
  void _scheduleSnoozeExpiry() {
    _snoozeTimer?.cancel();
    _snoozeTimer = null;
    if (!mounted) return;

    final now = AppClock.now();
    Duration? soonest;
    for (final habit in state.habits) {
      final until = habit.snoozedUntil;
      if (until == null || !until.isAfter(now)) continue;
      final wait = until.difference(now);
      if (soonest == null || wait < soonest) soonest = wait;
    }
    if (soonest == null) return;

    _snoozeTimer = Timer(soonest, () {
      if (!mounted) return;
      refresh();
    });
  }

  @override
  void dispose() {
    _snoozeTimer?.cancel();
    super.dispose();
  }
}
