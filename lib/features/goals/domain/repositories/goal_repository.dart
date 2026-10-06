import '../../domain/entities/goal.dart';
import '../../../../core/errors/failures.dart';

/// Storage boundary for goals.
///
/// Mirrors [HabitRepository]'s shape: `Result`-wrapped reads, entity-in /
/// entity-out writes, and the same archive/reorder vocabulary, so callers get
/// one consistent way to talk to persisted planning data.
abstract class GoalRepository {
  Future<Result<List<Goal>>> getAllGoals({bool includeArchived = false});
  Future<Result<Goal?>> getGoalById(String id);
  Future<Result<Goal>> createGoal(Goal goal);
  Future<Result<Goal>> updateGoal(Goal goal);
  Future<Result<void>> deleteGoal(String id);
  Future<Result<void>> archiveGoal(String id);
  Future<Result<void>> unarchiveGoal(String id);
  Future<Result<void>> reorderGoals(List<String> goalIds);
}
