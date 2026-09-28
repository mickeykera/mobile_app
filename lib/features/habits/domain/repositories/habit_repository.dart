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
  Future<Result<HabitCompletion>> createCompletion(HabitCompletion completion);
  Future<Result<void>> deleteCompletion(String id);

  Future<Result<int>> getCurrentStreak(String habitId);
  Future<Result<int>> getLongestStreak(String habitId);
  Future<Result<double>> getCompletionRate(String habitId,
      {DateTime? startDate, DateTime? endDate});
  Future<Result<Map<DateTime, int>>> getCompletionHeatmap(String habitId,
      {int weeks = 12});
}
