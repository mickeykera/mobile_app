import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/core/database/database.dart';
import 'package:ascend/core/errors/failures.dart';
import 'package:ascend/features/habits/data/repositories/habit_repository_impl.dart';
import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/habits/presentation/controllers/habit_controller.dart';
import 'package:ascend/features/recurring/domain/cutover_readiness.dart';
import 'package:ascend/features/recurring/domain/cutover_write_path.dart';
import 'package:ascend/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/presentation/controllers/task_controller.dart';

/// Shared fixture for the Stage L2 write-routing and failure-safety suites.
///
/// The single most important rule here is that the controllers and the
/// [CutoverWritePath] share **one** repository instance each. A repository
/// memoises its JSON list on first read, so two instances built over the same
/// storage are two caches that drift the moment one writes - which is exactly
/// the bug these tests exist to catch. Seed and migrate with throwaway
/// instances *before* the rig is built; the rig's repositories then load the
/// persisted result.
class L2Rig {
  final DatabaseService database;
  final HabitRepositoryImpl habitRepository;
  final TaskRepositoryImpl taskRepository;
  final CutoverWritePath path;
  final HabitController habitController;
  final TaskController taskController;

  L2Rig({
    required this.database,
    required this.habitRepository,
    required this.taskRepository,
    required this.path,
    required this.habitController,
    required this.taskController,
  });

  /// Loads both controllers from storage. Call after any seeding.
  Future<void> ready() async {
    await habitController.refresh();
    await taskController.refresh();
  }

  /// The cutover audit over the whole store, archived pairs included.
  ///
  /// Archived tasks must be included: an archived migrated pair (D2) would
  /// otherwise read as a dangling link and make every archived-state assertion
  /// fail for the wrong reason.
  Future<CutoverReadinessReport> audit() async {
    final habits = (await habitRepository.getAllHabits(includeArchived: true))
        .fold((_) => const <Habit>[], (habits) => habits);
    final tasks = (await taskRepository.getAllTasks(includeArchived: true))
        .fold((_) => const <Task>[], (tasks) => tasks);
    return CutoverAuditor.audit(habits: habits, tasks: tasks);
  }
}

/// Builds a rig over [database] with one shared repository instance per side.
L2Rig l2RigOn(
  DatabaseService database, {
  HabitRepositoryImpl? habitRepository,
  TaskRepositoryImpl? taskRepository,
}) {
  final habits = habitRepository ?? HabitRepositoryImpl(database);
  final tasks = taskRepository ?? TaskRepositoryImpl(database);
  final path = CutoverWritePath(
    habitRepository: habits,
    taskRepository: tasks,
  );
  return L2Rig(
    database: database,
    habitRepository: habits,
    taskRepository: tasks,
    path: path,
    habitController: HabitController(habits, cutover: path),
    taskController: TaskController(tasks, habits, cutover: path),
  );
}

/// A habit repository whose writes can be made to fail on demand.
///
/// Subclassing the real repository, rather than faking it, keeps every read and
/// every non-failing write genuinely progressing through the same cache the
/// controllers hold; only the chosen call is turned into a failure.
class L2FailingHabitRepository extends HabitRepositoryImpl {
  L2FailingHabitRepository(super.database);

  int failUpdate = 0;
  int failDelete = 0;
  int failArchive = 0;
  int failUnarchive = 0;
  int failDeleteCompletion = 0;

  @override
  Future<Result<Habit>> updateHabit(Habit habit) {
    if (failUpdate > 0) {
      failUpdate--;
      return Future.value(Either.left(const CacheFailure('injected habit update')));
    }
    return super.updateHabit(habit);
  }

  @override
  Future<Result<void>> deleteHabit(String id) async {
    if (failDelete > 0) {
      failDelete--;
      return Either.left(const CacheFailure('injected habit delete'));
    }
    return super.deleteHabit(id);
  }

  @override
  Future<Result<void>> archiveHabit(String id) async {
    if (failArchive > 0) {
      failArchive--;
      return Either.left(const CacheFailure('injected habit archive'));
    }
    return super.archiveHabit(id);
  }

  @override
  Future<Result<void>> unarchiveHabit(String id) async {
    if (failUnarchive > 0) {
      failUnarchive--;
      return Either.left(const CacheFailure('injected habit unarchive'));
    }
    return super.unarchiveHabit(id);
  }

  @override
  Future<Result<void>> deleteCompletion(String id) async {
    if (failDeleteCompletion > 0) {
      failDeleteCompletion--;
      return Either.left(const CacheFailure('injected deleteCompletion'));
    }
    return super.deleteCompletion(id);
  }
}

/// A task repository whose writes can be made to fail on demand.
class L2FailingTaskRepository extends TaskRepositoryImpl {
  L2FailingTaskRepository(super.database);

  int failUpdate = 0;
  int failDelete = 0;
  int failCreate = 0;

  @override
  Future<Result<Task>> createTask(Task task) {
    if (failCreate > 0) {
      failCreate--;
      return Future.value(Either.left(const CacheFailure('injected task create')));
    }
    return super.createTask(task);
  }

  @override
  Future<Result<Task>> updateTask(Task task) {
    if (failUpdate > 0) {
      failUpdate--;
      return Future.value(Either.left(const CacheFailure('injected task update')));
    }
    return super.updateTask(task);
  }

  @override
  Future<Result<void>> deleteTask(String id) async {
    if (failDelete > 0) {
      failDelete--;
      return Either.left(const CacheFailure('injected task delete'));
    }
    return super.deleteTask(id);
  }
}