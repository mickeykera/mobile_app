import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_completion.dart';
import '../../../../core/errors/failures.dart';

abstract class HabitRepository {
  Future<Result<List<Habit>>> getAllHabits({bool includeArchived = false});
  Future<Result<Habit?>> getHabitById(String id);
  Future<Result<Habit>> createHabit(Habit habit);
  Future<Result<Habit>> updateHabit(Habit habit);
  Future<Result<void>> deleteHabit(String id);
  Future<Result<void>> archiveHabit(String id);
  Future<Result<void>> unarchiveHabit(String id);
  Future<Result<void>> reorderHabits(List<String> habitIds);

  Future<Result<List<HabitCompletion>>> getCompletionsForHabit(String habitId,
      {DateTime? startDate, DateTime? endDate});
  Future<Result<List<HabitCompletion>>> getCompletionsForDate(DateTime date);

  /// Every completion row, across all habits and the whole history.
  ///
  /// Added for the Stage G streak-parity report, which compares a habit's stored
  /// streak counters against its log and therefore needs the *whole* log: a
  /// range would silently report divergence for every habit whose history reaches
  /// outside it, which is a fabricated result rather than a finding. Callers that
  /// only need a window should keep using [getCompletionsInRange].
  Future<Result<List<HabitCompletion>>> getAllCompletions();

  /// Every completion in `[start, end]`, across all habits.
  ///
  /// Added for the Today view's week strip. It exists as one range call rather
  /// than the caller looping [getCompletionsForDate] over seven days because
  /// each of those reads the *entire* completions list back out of storage
  /// before filtering - seven calls means seven full reads and seven array
  /// scans where one does the job.
  Future<Result<List<HabitCompletion>>> getCompletionsInRange(
      DateTime start, DateTime end);

  Future<Result<HabitCompletion>> createCompletion(HabitCompletion completion);
  Future<Result<void>> deleteCompletion(String id);

  /// Records an occurrence for a recurring Task.
  ///
  /// Writes a [HabitCompletion] with [itemId] = [taskId], [itemType] = 'task',
  /// and [habitId] = null. The [date] parameter is the calendar day the
  /// occurrence falls on; the timestamp on the row combines this date with the
  /// current time of day via [AppClock].
  ///
  /// Idempotent: if a row already exists for the same ([taskId], [date])
  /// (same-day dedupe), returns the existing row without creating a duplicate.
  Future<Result<HabitCompletion>> recordRecurringTaskOccurrence({
    required String taskId,
    required DateTime date,
    required int count,
    Duration? duration,
    String? note,
    int? moodRating,
    int? energyRating,
  });

  /// Deletes the occurrence row for a recurring Task on a specific date.
  ///
  /// Symmetric with [recordRecurringTaskOccurrence]. No-op if no row exists.
  Future<Result<void>> deleteRecurringTaskOccurrence({
    required String taskId,
    required DateTime date,
  });

  /// Reconciles a Task's occurrence history from its authoritative Habit.
  ///
  /// This is a recovery operation for non-atomic dual-write failures, NOT a
  /// transaction. It rebuilds the Task's occurrence rows from the Habit's
  /// completion history (the authoritative source). Idempotent: repeated
  /// invocations converge to the same state.
  ///
  /// Steps:
  /// 1. Load all HabitCompletion rows with [ownerId] == [habitId].
  /// 2. Load the corresponding Task's current occurrence rows
  ///    ([itemId] == [taskId], [itemType] == 'task').
  /// 3. For each Habit completion row, ensure a matching Task row exists
  ///    (create via [recordRecurringTaskOccurrence]).
  /// 4. For each Task row with no corresponding Habit row, delete it (orphaned
  ///    by partial failure).
  Future<Result<void>> reconcileHabitToTask({
    required String habitId,
    required String taskId,
  });

  Future<Result<int>> getCurrentStreak(String habitId);
  Future<Result<int>> getLongestStreak(String habitId);
  Future<Result<double>> getCompletionRate(String habitId,
      {DateTime? startDate, DateTime? endDate});
  Future<Result<Map<DateTime, int>>> getCompletionHeatmap(String habitId,
      {int weeks = 12});
}
