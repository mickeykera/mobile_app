import '../../domain/entities/task.dart';
import '../../../../core/errors/failures.dart';

/// Storage boundary for tasks.
///
/// Mirrors the goal/project repositories: `Result`-wrapped reads, entity-in /
/// entity-out writes, and the same archive/reorder vocabulary. The Inbox and
/// the "tasks for a project" view are queries here rather than stored
/// collections, so they can never disagree with the `projectId`/`goalId` links.
abstract class TaskRepository {
  Future<Result<List<Task>>> getAllTasks({bool includeArchived = false});
  Future<Result<Task?>> getTaskById(String id);

  /// Tasks with neither a project nor a goal.
  Future<Result<List<Task>>> getInboxTasks({bool includeArchived = false});

  Future<Result<List<Task>>> getTasksForProject(
    String projectId, {
    bool includeArchived = false,
  });

  Future<Result<List<Task>>> getTasksForGoal(
    String goalId, {
    bool includeArchived = false,
  });

  Future<Result<Task>> createTask(Task task);
  Future<Result<Task>> updateTask(Task task);
  Future<Result<void>> deleteTask(String id);
  Future<Result<void>> archiveTask(String id);
  Future<Result<void>> unarchiveTask(String id);
  Future<Result<void>> reorderTasks(List<String> taskIds);
}
