import '../../domain/entities/project.dart';
import '../../../../core/errors/failures.dart';

/// Storage boundary for projects.
///
/// Mirrors [HabitRepository]'s shape: `Result`-wrapped reads, entity-in /
/// entity-out writes, and the same archive/reorder vocabulary, so callers get
/// one consistent way to talk to persisted planning data.
abstract class ProjectRepository {
  Future<Result<List<Project>>> getAllProjects({bool includeArchived = false});
  Future<Result<Project?>> getProjectById(String id);
  Future<Result<Project>> createProject(Project project);
  Future<Result<Project>> updateProject(Project project);
  Future<Result<void>> deleteProject(String id);
  Future<Result<void>> archiveProject(String id);
  Future<Result<void>> unarchiveProject(String id);
  Future<Result<void>> reorderProjects(List<String> projectIds);
}
