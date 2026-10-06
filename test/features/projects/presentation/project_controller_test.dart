import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/core/constants/item_status.dart';
import 'package:ascend/core/errors/failures.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/projects/domain/entities/project.dart';
import 'package:ascend/features/projects/domain/repositories/project_repository.dart';
import 'package:ascend/features/projects/presentation/controllers/project_controller.dart';

class FakeProjectRepository implements ProjectRepository {
  final List<Project> stored;
  bool failOnRead = false;
  bool failOnWrite = false;

  FakeProjectRepository([List<Project>? initial])
      : stored = initial == null ? [] : List<Project>.from(initial);

  @override
  Future<Result<List<Project>>> getAllProjects(
      {bool includeArchived = false}) async {
    if (failOnRead) return Either.left(const CacheFailure('read failed'));
    return Either.right(stored
        .where((p) => includeArchived || p.status != ItemStatus.archived)
        .toList());
  }

  @override
  Future<Result<Project?>> getProjectById(String id) async =>
      Either.right(_find(id));

  @override
  Future<Result<Project>> createProject(Project project) async {
    if (failOnWrite) return Either.left(const CacheFailure('write failed'));
    stored.add(project);
    return Either.right(project);
  }

  @override
  Future<Result<Project>> updateProject(Project project) async {
    if (failOnWrite) return Either.left(const CacheFailure('write failed'));
    final index = stored.indexWhere((p) => p.id == project.id);
    if (index >= 0) stored[index] = project;
    return Either.right(project);
  }

  @override
  Future<Result<void>> deleteProject(String id) async {
    if (failOnWrite) return Either.left(const CacheFailure('write failed'));
    stored.removeWhere((p) => p.id == id);
    return Either.right(null);
  }

  @override
  Future<Result<void>> archiveProject(String id) async {
    final project = _find(id);
    if (project == null) return Either.left(const NotFoundFailure('not found'));
    stored[stored.indexWhere((p) => p.id == id)] = project.copyWith(
      status: ItemStatus.archived,
      archivedAt: AppClock.now(),
    );
    return Either.right(null);
  }

  @override
  Future<Result<void>> unarchiveProject(String id) async {
    final project = _find(id);
    if (project == null) return Either.left(const NotFoundFailure('not found'));
    stored[stored.indexWhere((p) => p.id == id)] =
        project.copyWith(status: ItemStatus.active, archivedAt: null);
    return Either.right(null);
  }

  @override
  Future<Result<void>> reorderProjects(List<String> projectIds) async {
    for (var i = 0; i < projectIds.length; i++) {
      final project = _find(projectIds[i]);
      if (project != null) {
        stored[stored.indexWhere((p) => p.id == project.id)] =
            project.copyWith(sortOrder: i);
      }
    }
    return Either.right(null);
  }

  Project? _find(String id) {
    for (final project in stored) {
      if (project.id == id) return project;
    }
    return null;
  }
}

Project _project(String id,
        {ItemStatus status = ItemStatus.active, int order = 0}) =>
    Project(
      id: id,
      title: 'Project $id',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      sortOrder: order,
      status: status,
    );

void main() {
  final now = DateTime(2025, 6, 11, 9);
  setUp(() => AppClock.debugSetNow(() => now));
  tearDown(AppClock.debugResetNow);

  late FakeProjectRepository repository;

  setUp(() {
    repository = FakeProjectRepository();
  });

  Future<ProjectController> build([List<Project> seed = const []]) async {
    repository.stored.addAll(seed);
    final built = ProjectController(repository);
    await Future<void>.delayed(Duration.zero);
    return built;
  }

  test('loads archived projects too, so they can be unarchived', () async {
    final controller = await build(
        [_project('a'), _project('b', status: ItemStatus.archived)]);

    expect(controller.state.projects.map((p) => p.id), ['a', 'b']);
  });

  test('a new project starts active, with no goal', () async {
    final controller = await build();
    final result = await controller.createProject(title: '  Ship it  ');

    expect(result.right!.title, 'Ship it');
    expect(result.right!.status, ItemStatus.active);
    expect(result.right!.goalId, isNull,
        reason: 'a project is allowed to serve no goal at all');
    expect(result.right!.completedAt, isNull);
  });

  test('a blank title is rejected and nothing is stored', () async {
    final controller = await build();

    final result = await controller.createProject(title: '   ');

    expect(result.isLeft, isTrue);
    expect(result.left, isA<ValidationFailure>());
    expect(controller.state.projects, isEmpty);
    expect(repository.stored, isEmpty);
  });

  group('lifecycle', () {
    test('active -> completed stamps completedAt', () async {
      final controller = await build([_project('a')]);

      final result = await controller.setStatus('a', ItemStatus.completed);

      expect(result.right!.status, ItemStatus.completed);
      expect(result.right!.completedAt, now);
    });

    test('reopening a completed project clears completedAt', () async {
      final controller = await build([
        _project('a', status: ItemStatus.completed).copyWith(completedAt: now)
      ]);

      await controller.setStatus('a', ItemStatus.active);

      expect(controller.projectById('a')!.completedAt, isNull,
          reason: 'a stale stamp would keep reporting it as finished');
    });

    test('active -> archived stamps archivedAt', () async {
      final controller = await build([_project('a')]);

      final result = await controller.setStatus('a', ItemStatus.archived);

      expect(result.right!.archivedAt, now);
    });

    test('completed -> archived keeps completedAt', () async {
      final controller = await build([_project('a')]);
      await controller.setStatus('a', ItemStatus.completed);

      await controller.setStatus('a', ItemStatus.archived);

      final project = controller.projectById('a')!;
      expect(project.status, ItemStatus.archived);
      expect(project.completedAt, isNotNull,
          reason: 'it was finished before it was filed away');
    });

    test('an unknown id is a NotFoundFailure', () async {
      final controller = await build();

      final result = await controller.setStatus('nope', ItemStatus.completed);

      expect(result.isLeft, isTrue);
      expect(result.left, isA<NotFoundFailure>());
    });
  });

  test('titleFor falls back rather than throwing on an unknown id', () async {
    final controller = await build([_project('a')]);

    expect(controller.titleFor('a'), 'Project a');
    expect(controller.titleFor('missing'), 'Unknown project');
  });

  test('a failed load surfaces the message', () async {
    repository.failOnRead = true;
    final controller = await build();

    expect(controller.state.error, isNotNull);
    expect(controller.state.projects, isEmpty);
  });

  test('a failed write leaves the list untouched', () async {
    final controller = await build([_project('a')]);
    repository.failOnWrite = true;

    final result = await controller.createProject(title: 'Nope');

    expect(result.isLeft, isTrue);
    expect(controller.state.projects, hasLength(1));
    expect(controller.state.isSaving, isFalse);
  });

  test('deleting drops the project', () async {
    final controller = await build([_project('a')]);

    await controller.deleteProject('a');

    expect(controller.state.projects, isEmpty);
  });

  test('projects load in sortOrder', () async {
    final controller =
        await build([_project('b', order: 2), _project('a', order: 0)]);

    expect(controller.state.projects.map((p) => p.id), ['a', 'b']);
  });
}
