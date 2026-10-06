import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/core/errors/failures.dart';
import 'package:ascend/core/utils/app_clock.dart';
import '../../habits/presentation/habit_controller_test.dart'
    show FakeHabitRepository;
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/repositories/task_repository.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';
import 'package:ascend/features/tasks/presentation/controllers/task_controller.dart';

/// In-memory stand-in for [TaskRepository].
///
/// Mirrors the real repository's contract without its storage: entity-in,
/// entity-out, and archive hidden unless asked for.
class FakeTaskRepository implements TaskRepository {
  final List<Task> stored;
  bool failOnRead = false;
  bool failOnWrite = false;

  FakeTaskRepository([List<Task>? initial])
      : stored = initial == null ? [] : List<Task>.from(initial);

  @override
  Future<Result<List<Task>>> getAllTasks({bool includeArchived = false}) async {
    if (failOnRead) {
      return Either.left(const CacheFailure('read failed'));
    }
    return Either.right(stored
        .where((t) => includeArchived || t.status != TaskStatus.archived)
        .toList());
  }

  @override
  Future<Result<Task?>> getTaskById(String id) async => Either.right(_find(id));

  @override
  Future<Result<List<Task>>> getInboxTasks(
      {bool includeArchived = false}) async {
    final all = await getAllTasks(includeArchived: includeArchived);
    return Either.right(
        (all.right ?? const []).where((t) => t.isInbox).toList());
  }

  @override
  Future<Result<List<Task>>> getTasksForProject(String projectId,
      {bool includeArchived = false}) async {
    final all = await getAllTasks(includeArchived: includeArchived);
    return Either.right((all.right ?? const [])
        .where((t) => t.projectId == projectId)
        .toList());
  }

  @override
  Future<Result<List<Task>>> getTasksForGoal(String goalId,
      {bool includeArchived = false}) async {
    final all = await getAllTasks(includeArchived: includeArchived);
    return Either.right(
        (all.right ?? const []).where((t) => t.goalId == goalId).toList());
  }

  @override
  Future<Result<Task>> createTask(Task task) async {
    if (failOnWrite) return Either.left(const CacheFailure('write failed'));
    stored.add(task);
    return Either.right(task);
  }

  @override
  Future<Result<Task>> updateTask(Task task) async {
    if (failOnWrite) return Either.left(const CacheFailure('write failed'));
    final index = stored.indexWhere((t) => t.id == task.id);
    if (index >= 0) stored[index] = task;
    return Either.right(task);
  }

  @override
  Future<Result<void>> deleteTask(String id) async {
    if (failOnWrite) return Either.left(const CacheFailure('write failed'));
    stored.removeWhere((t) => t.id == id);
    return Either.right(null);
  }

  @override
  Future<Result<void>> archiveTask(String id) async {
    final task = _find(id);
    if (task == null) {
      return Either.left(const NotFoundFailure('Task not found'));
    }
    stored[stored.indexWhere((t) => t.id == id)] = task.copyWith(
      status: TaskStatus.archived,
      archivedAt: AppClock.now(),
      updatedAt: AppClock.now(),
    );
    return Either.right(null);
  }

  @override
  Future<Result<void>> unarchiveTask(String id) async {
    final task = _find(id);
    if (task == null) {
      return Either.left(const NotFoundFailure('Task not found'));
    }
    stored[stored.indexWhere((t) => t.id == id)] =
        task.copyWith(status: TaskStatus.todo, archivedAt: null);
    return Either.right(null);
  }

  @override
  Future<Result<void>> reorderTasks(List<String> taskIds) async {
    for (var i = 0; i < taskIds.length; i++) {
      final task = _find(taskIds[i]);
      if (task != null) {
        stored[stored.indexWhere((t) => t.id == task.id)] =
            task.copyWith(sortOrder: i);
      }
    }
    return Either.right(null);
  }

  Task? _find(String id) {
    for (final task in stored) {
      if (task.id == id) return task;
    }
    return null;
  }
}

Task _task(String id, {TaskStatus status = TaskStatus.todo, int order = 0}) =>
    Task(
      id: id,
      title: 'Task $id',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      sortOrder: order,
      status: status,
      schedule: const Unscheduled(),
    );

void main() {
  final now = DateTime(2025, 6, 11, 9);
  setUp(() => AppClock.debugSetNow(() => now));
  tearDown(AppClock.debugResetNow);

  late FakeTaskRepository repository;

  setUp(() {
    repository = FakeTaskRepository();
  });

  /// Builds a controller over the repository *after* [seed] has run.
  ///
  /// The controller loads in its constructor, so seeding has to happen first -
  /// a controller built in `setUp` and seeded afterwards would load an empty
  /// list and every assertion below would read nothing.
  Future<TaskController> build([List<Task> seed = const []]) async {
    repository.stored.addAll(seed);
    final habitRepository = FakeHabitRepository();
    final built = TaskController(repository, habitRepository);
    await Future<void>.delayed(Duration.zero);
    return built;
  }

  group('loading', () {
    test('loads the existing tasks and clears the loading flag', () async {
      final fresh = await build([_task('a'), _task('b')]);

      expect(fresh.state.isLoading, isFalse);
      expect(fresh.state.tasks.map((t) => t.id), ['a', 'b']);
    });

    test('a failed load surfaces the message and keeps no stale list',
        () async {
      repository.failOnRead = true;
      final fresh = await build();

      expect(fresh.state.isLoading, isFalse);
      expect(fresh.state.error, isNotNull);
      expect(fresh.state.tasks, isEmpty);
    });
  });

  group('createTask', () {
    test('a task with no project and no goal lands in the inbox', () async {
      final controller = await build();
      final result = await controller.createTask(title: 'Write the plan');

      expect(result.isRight, isTrue);
      final task = result.right!;
      expect(task.isInbox, isTrue);
      expect(task.status, TaskStatus.todo);
      expect(task.schedule, const Unscheduled());
      expect(controller.state.tasks, hasLength(1));
      expect(controller.inbox, hasLength(1));
    });

    test('the title is trimmed and a blank title is rejected', () async {
      final controller = await build();

      final result = await controller.createTask(title: '   Spaced out   ');
      expect(result.right!.title, 'Spaced out');

      final blank = await controller.createTask(title: '    ');
      expect(blank.isLeft, isTrue);
      expect(blank.left, isA<ValidationFailure>());
      expect(controller.state.tasks, hasLength(1),
          reason: 'the rejected task must not be stored');
    });

    test('a dated task carries its schedule through', () async {
      final controller = await build();
      final result = await controller.createTask(
        title: 'Due today',
        schedule: Once(DateTime(2025, 6, 11)),
      );

      expect(result.right!.schedule, isA<Once>());
      expect(result.right!.isDueOn(DateTime(2025, 6, 11), now: now), isTrue);
    });

    test('a failed write surfaces the message and adds nothing', () async {
      final controller = await build();
      repository.failOnWrite = true;

      final result = await controller.createTask(title: 'Nope');

      expect(result.isLeft, isTrue);
      expect(controller.state.error, isNotNull);
      expect(controller.state.tasks, isEmpty);
      expect(controller.state.isSaving, isFalse);
    });
  });

  group('setStatus', () {
    test('todo -> doing -> done stamps completedAt on the way in', () async {
      final controller = await build([_task('a')]);

      await controller.setStatus('a', TaskStatus.doing);
      expect(controller.state.tasks.single.status, TaskStatus.doing);
      expect(controller.state.tasks.single.completedAt, isNull);

      await controller.setStatus('a', TaskStatus.done);
      final done = controller.state.tasks.single;
      expect(done.status, TaskStatus.done);
      expect(done.isComplete, isTrue);
      expect(done.completedAt, now);
    });

    test('reopening a done task clears completedAt', () async {
      final controller = await build(
          [_task('a', status: TaskStatus.done).copyWith(completedAt: now)]);

      expect(controller.state.tasks.single.completedAt, isNotNull);

      await controller.setStatus('a', TaskStatus.todo);
      final reopened = controller.state.tasks.single;
      expect(reopened.status, TaskStatus.todo);
      expect(reopened.completedAt, isNull,
          reason: 'a stale stamp would still report the task as finished');
    });

    test('archiving stamps archivedAt', () async {
      final controller = await build([_task('a')]);

      await controller.setStatus('a', TaskStatus.archived);

      expect(controller.state.tasks.single.archivedAt, now);
    });

    test('archiving a done task keeps completedAt', () async {
      final controller = await build([_task('a')]);
      await controller.setStatus('a', TaskStatus.done);

      await controller.setStatus('a', TaskStatus.archived);

      final task = controller.state.tasks.single;
      expect(task.status, TaskStatus.archived);
      expect(task.completedAt, now,
          reason: 'it was finished before it was filed away');
    });

    test('an unknown id is a NotFoundFailure, not a silent no-op', () async {
      final controller = await build();
      final result = await controller.setStatus('nope', TaskStatus.done);

      expect(result.isLeft, isTrue);
      expect(result.left, isA<NotFoundFailure>());
    });
  });

  group('filing', () {
    test('filing under a project removes the task from the inbox', () async {
      final controller = await build([_task('a')]);
      expect(controller.inbox, hasLength(1));

      await controller.fileUnderProject('a', 'p1');

      expect(controller.inbox, isEmpty);
      expect(controller.tasksForProject('p1'), hasLength(1));
      expect(controller.state.tasks.single.projectId, 'p1');
    });

    test('clearing the project link puts the task back in the inbox', () async {
      final controller = await build([_task('a', order: 1)]);
      await controller.fileUnderProject('a', 'p1');
      expect(controller.inbox, isEmpty);

      await controller.fileUnderProject('a', null);

      expect(controller.inbox, hasLength(1));
      expect(controller.state.tasks.single.projectId, isNull);
    });

    test('filing clears a stale goalId so the two links cannot disagree',
        () async {
      final controller = await build([_task('a').copyWith(goalId: 'g1')]);

      await controller.fileUnderProject('a', 'p2');

      final task = controller.state.tasks.single;
      expect(task.projectId, 'p2');
      expect(task.goalId, isNull,
          reason: 'the project already implies its goal; keeping both lets '
              'them drift apart');
    });

    test('moving back to the inbox keeps a goal-only link intact', () async {
      final controller = await build([_task('a').copyWith(goalId: 'g1')]);

      await controller.fileUnderProject('a', null);

      expect(controller.state.tasks.single.goalId, 'g1');
    });
  });

  group('archive and delete', () {
    test('archiving hides the task from the working set', () async {
      final controller = await build([_task('a')]);

      await controller.archiveTask('a');

      expect(controller.state.tasks.single.status, TaskStatus.archived);
      expect(controller.inbox, isEmpty);
    });

    test('unarchiving returns the task to todo', () async {
      final controller = await build([_task('a', status: TaskStatus.archived)]);

      await controller.unarchiveTask('a');

      expect(controller.state.tasks.single.status, TaskStatus.todo);
    });

    test('deleting drops the task from state', () async {
      final controller = await build([_task('a')]);

      await controller.deleteTask('a');

      expect(controller.state.tasks, isEmpty);
      expect(repository.stored, isEmpty);
    });
  });

  group('reorder', () {
    test('the given order wins and sortOrder is rewritten to match', () async {
      final controller = await build([_task('a'), _task('b'), _task('c')]);

      await controller.reorderTasks(['c', 'a', 'b']);

      expect(controller.state.tasks.map((t) => t.id), ['c', 'a', 'b']);
      expect(controller.state.tasks.map((t) => t.sortOrder), [0, 1, 2]);
    });

    test('a partial order keeps the unmentioned tasks, not drops them',
        () async {
      final controller = await build([_task('a'), _task('b'), _task('c')]);

      await controller.reorderTasks(['c']);

      expect(controller.state.tasks.map((t) => t.id), ['c', 'a', 'b']);
    });
  });

  group('queries', () {
    test('inbox is exactly the unfiled tasks', () async {
      final controller = await build([
        _task('a'),
        _task('b').copyWith(projectId: 'p1'),
        _task('c').copyWith(goalId: 'g1'),
      ]);

      expect(controller.inbox.map((t) => t.id), ['a']);
    });

    test('tasksForGoal finds goal-linked tasks only', () async {
      final controller = await build([
        _task('a').copyWith(goalId: 'g1'),
        _task('b').copyWith(projectId: 'p1'),
      ]);

      expect(controller.tasksForGoal('g1').map((t) => t.id), ['a']);
      expect(controller.tasksForProject('p1').map((t) => t.id), ['b']);
    });
  });
}
