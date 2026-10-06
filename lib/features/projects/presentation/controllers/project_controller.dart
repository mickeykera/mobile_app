import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/constants/item_status.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/app_clock.dart';
import '../../domain/entities/project.dart';
import '../../domain/repositories/project_repository.dart';

part 'project_controller.freezed.dart';

@freezed
abstract class ProjectState with _$ProjectState {
  const factory ProjectState({
    @Default([]) List<Project> projects,
    @Default(false) bool isLoading,
    @Default(false) bool isSaving,
    String? error,
  }) = _ProjectState;
}

/// Owns the project list and the `active -> completed -> archived` lifecycle.
///
/// Like [TaskController] this holds the whole list rather than a slice, because
/// the Tasks screen groups tasks by project and needs every project to label a
/// section. A project whose tasks have all been archived still has a name to
/// show, and a per-project loader would have lost it.
class ProjectController extends StateNotifier<ProjectState> {
  final ProjectRepository _repository;

  ProjectController(this._repository) : super(const ProjectState()) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    state = state.copyWith(isLoading: true, error: null);

    // Archived projects are loaded too, and filtered on read by the providers, so
    // that one which is filed away can still be unarchived. `TaskController`
    // does the same for tasks, and `HabitController` for habits.
    final result = await _repository.getAllProjects(includeArchived: true);
    if (!mounted) return;

    if (result.isLeft) {
      state = state.copyWith(isLoading: false, error: result.left!.userMessage);
      return;
    }
    state = state.copyWith(isLoading: false, projects: _sorted(result.right!));
  }

  Future<void> refresh() => _loadInitialData();

  static List<Project> _sorted(Iterable<Project> projects) =>
      projects.toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  Project? _find(String id) {
    for (final project in state.projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  Project? projectById(String id) => _find(id);

  String titleFor(String id) {
    final project = _find(id);
    return project?.title ?? 'Unknown project';
  }

  Future<Result<Project>> createProject({
    required String title,
    String? description,
    String? goalId,
    DateTime? targetDate,
    String? category,
    String? color,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return Either.left(
          const ValidationFailure('Project title cannot be empty'));
    }

    state = state.copyWith(isSaving: true, error: null);

    final project = Project.create(
      title: trimmed,
      description: description,
      goalId: goalId,
      targetDate: targetDate,
      category: category,
      color: color,
      sortOrder: state.projects.length,
    );

    final result = await _repository.createProject(project);
    if (!mounted) return result;

    if (result.isLeft) {
      state = state.copyWith(isSaving: false, error: result.left!.userMessage);
    } else {
      state = state.copyWith(
        isSaving: false,
        projects: _sorted([...state.projects, result.right!]),
      );
    }
    return result;
  }

  Future<Result<Project>> updateProject(Project project) async {
    state = state.copyWith(isSaving: true, error: null);

    final result = await _repository.updateProject(project);
    if (!mounted) return result;

    if (result.isLeft) {
      state = state.copyWith(isSaving: false, error: result.left!.userMessage);
    } else {
      state = state.copyWith(
        isSaving: false,
        projects: _sorted(state.projects
            .map((p) => p.id == result.right!.id ? result.right! : p)),
      );
    }
    return result;
  }

  /// Moves [id] to [status], stamping `completedAt` / `archivedAt` to match.
  ///
  /// Reopening a completed project clears `completedAt`, for the same reason the
  /// task controller does on `done`: a stale stamp would keep reporting it as
  /// finished. Archiving *preserves* it - a project that was finished and then
  /// filed away was still finished, and wiping the stamp loses that history.
  Future<Result<Project>> setStatus(String id, ItemStatus status) async {
    final project = _find(id);
    if (project == null) {
      return Either.left(NotFoundFailure('Project $id not found'));
    }

    final now = AppClock.now();
    return updateProject(project.copyWith(
      status: status,
      completedAt: switch (status) {
        ItemStatus.completed => project.completedAt ?? now,
        ItemStatus.archived => project.completedAt,
        ItemStatus.active => null,
      },
      archivedAt: status == ItemStatus.archived ? now : null,
      updatedAt: now,
    ));
  }

  Future<Result<void>> deleteProject(String id) async {
    state = state.copyWith(isSaving: true, error: null);

    final result = await _repository.deleteProject(id);
    if (!mounted) return result;

    if (result.isLeft) {
      state = state.copyWith(isSaving: false, error: result.left!.userMessage);
    } else {
      state = state.copyWith(
        isSaving: false,
        projects: state.projects.where((p) => p.id != id).toList(),
      );
    }
    return result;
  }
}
