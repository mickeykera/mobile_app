import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/item_status.dart';
import '../../../../core/database/database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/app_clock.dart';
import '../../domain/entities/project.dart';
import '../../domain/repositories/project_repository.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  final DatabaseService _database;
  final List<Project> _projects = [];

  /// Memoised load, not a `bool` guard, for the same reason as
  /// [HabitRepositoryImpl]: a plain bool loses the race between two concurrent
  /// callers and doubles every loaded row.
  Future<void>? _loading;

  ProjectRepositoryImpl(this._database);

  Future<void> _ensureLoaded() => _loading ??= _loadFromPrefs();

  Future<void> _loadFromPrefs() async {
    final projectsJson =
        _database.getJsonList(DatabaseService.projectsKey) ?? [];
    for (final json in projectsJson) {
      _projects.add(_projectFromJson(json));
    }
  }

  Future<void> _saveProjects() async {
    await _database.setJsonList(
        DatabaseService.projectsKey, _projects.map(_projectToJson).toList());
  }

  Project _projectFromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      goalId: json['goalId'] as String?,
      targetDate: _dateFromJson(json['targetDate']),
      category: json['category'] as String?,
      color: json['color'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      sortOrder: json['sortOrder'] as int? ?? 0,
      status: ItemStatus.fromStorage(json['status']),
      completedAt: _dateFromJson(json['completedAt']),
      archivedAt: _dateFromJson(json['archivedAt']),
    );
  }

  Map<String, dynamic> _projectToJson(Project project) {
    return {
      'id': project.id,
      'title': project.title,
      'description': project.description,
      'goalId': project.goalId,
      'targetDate': project.targetDate?.toIso8601String(),
      'category': project.category,
      'color': project.color,
      'createdAt': project.createdAt.toIso8601String(),
      'updatedAt': project.updatedAt.toIso8601String(),
      'sortOrder': project.sortOrder,
      'status': project.status.storageValue,
      'completedAt': project.completedAt?.toIso8601String(),
      'archivedAt': project.archivedAt?.toIso8601String(),
    };
  }

  DateTime? _dateFromJson(Object? value) =>
      value is String ? DateTime.parse(value) : null;

  Project? _findProject(String id) {
    for (final project in _projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  @override
  Future<Result<List<Project>>> getAllProjects(
      {bool includeArchived = false}) async {
    await _ensureLoaded();
    try {
      final projects = _projects
          .where((p) => includeArchived || p.status != ItemStatus.archived)
          .toList();
      projects.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return Either.right(projects);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to fetch projects: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Project?>> getProjectById(String id) async {
    await _ensureLoaded();
    try {
      return Either.right(_findProject(id));
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to fetch project: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Project>> createProject(Project project) async {
    await _ensureLoaded();
    try {
      _projects.add(project);
      await _saveProjects();
      return Either.right(project);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to create project: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Project>> updateProject(Project project) async {
    await _ensureLoaded();
    try {
      final index = _projects.indexWhere((p) => p.id == project.id);
      if (index >= 0) {
        _projects[index] = project;
        await _saveProjects();
      }
      return Either.right(project);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to update project: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> deleteProject(String id) async {
    await _ensureLoaded();
    try {
      _projects.removeWhere((p) => p.id == id);
      await _saveProjects();
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to delete project: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> archiveProject(String id) async {
    await _ensureLoaded();
    try {
      final project = _findProject(id);
      if (project == null) {
        return Either.left(const NotFoundFailure('Project not found'));
      }

      final now = AppClock.now();
      _projects[_projects.indexWhere((p) => p.id == id)] = project.copyWith(
        status: ItemStatus.archived,
        archivedAt: now,
        updatedAt: now,
      );
      await _saveProjects();
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to archive project: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> unarchiveProject(String id) async {
    await _ensureLoaded();
    try {
      final project = _findProject(id);
      if (project == null) {
        return Either.left(const NotFoundFailure('Project not found'));
      }

      _projects[_projects.indexWhere((p) => p.id == id)] = project.copyWith(
        status: ItemStatus.active,
        archivedAt: null,
        updatedAt: AppClock.now(),
      );
      await _saveProjects();
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to unarchive project: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> reorderProjects(List<String> projectIds) async {
    await _ensureLoaded();
    try {
      for (int i = 0; i < projectIds.length; i++) {
        final project = _findProject(projectIds[i]);
        if (project != null) {
          _projects[_projects.indexWhere((p) => p.id == project.id)] =
              project.copyWith(
            sortOrder: i,
            updatedAt: AppClock.now(),
          );
        }
      }
      await _saveProjects();
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to reorder projects: $e',
          originalError: e, stackTrace: st));
    }
  }
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final database = ref.watch(databaseServiceProvider);
  return ProjectRepositoryImpl(database);
});
