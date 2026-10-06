import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/app_clock.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/value_objects/streak_freeze_usage.dart';
import '../../domain/value_objects/task_schedule.dart';
import '../../domain/value_objects/task_status.dart';

class TaskRepositoryImpl implements TaskRepository {
  final DatabaseService _database;
  final List<Task> _tasks = [];

  /// Memoised load, not a `bool` guard, for the same reason as
  /// [HabitRepositoryImpl]: a plain bool loses the race between two concurrent
  /// callers and doubles every loaded row.
  Future<void>? _loading;

  TaskRepositoryImpl(this._database);

  Future<void> _ensureLoaded() => _loading ??= _loadFromPrefs();

  Future<void> _loadFromPrefs() async {
    final tasksJson = _database.getJsonList(DatabaseService.tasksKey) ?? [];
    for (final json in tasksJson) {
      _tasks.add(_taskFromJson(json));
    }
  }

  Future<void> _saveTasks() async {
    await _database.setJsonList(
        DatabaseService.tasksKey, _tasks.map(_taskToJson).toList());
  }

  Task _taskFromJson(Map<String, dynamic> json) {
    final scheduleJson = json['schedule'];
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      projectId: json['projectId'] as String?,
      goalId: json['goalId'] as String?,
      category: json['category'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      sortOrder: json['sortOrder'] as int? ?? 0,
      status: TaskStatus.fromStorage(json['status']),
      schedule: scheduleJson is Map
          ? TaskSchedule.fromJson(scheduleJson.cast<String, dynamic>())
          : const Unscheduled(),
      completedAt: _dateFromJson(json['completedAt']),
      archivedAt: _dateFromJson(json['archivedAt']),
      // Added in Stage L1.3. A Task written before these keys existed was
      // produced by Stage L0's copy, which deliberately carried no capability
      // fields. Absent reads as the legacy default so such a Task compares
      // equal to a default Habit and the capability bridge writes nothing for
      // it; a habit that actually customised a value is detected as a
      // divergence and gets the field written on the next pass.
      targetCount: json['targetCount'] as int? ?? 1,
      targetDuration:
          Duration(minutes: json['targetDurationMinutes'] as int? ?? 0),
      cue: json['cue'] as String? ?? '',
      timeOfDay: json['timeOfDay'] as String? ?? AppConstants.timeOfDayMorning,
      streakFreezeUsage:
          StreakFreezeUsage(json['streakFreezesUsed'] as int? ?? 0),
    );
  }

  Map<String, dynamic> _taskToJson(Task task) {
    return {
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'projectId': task.projectId,
      'goalId': task.goalId,
      'category': task.category,
      'createdAt': task.createdAt.toIso8601String(),
      'updatedAt': task.updatedAt.toIso8601String(),
      'sortOrder': task.sortOrder,
      'status': task.status.storageValue,
      'schedule': task.schedule.toJson(),
      'completedAt': task.completedAt?.toIso8601String(),
      'archivedAt': task.archivedAt?.toIso8601String(),
      // Stage L1.3: the five legacy capability fields. The JSON keys match the
      // Habit record's spelling so a value moved across can be diffed - and
      // later retired - by name rather than by an invented mapping.
      'targetCount': task.targetCount,
      'targetDurationMinutes': task.targetDuration.inMinutes,
      'cue': task.cue,
      'timeOfDay': task.timeOfDay,
      'streakFreezesUsed': task.streakFreezeUsage.used,
    };
  }

  DateTime? _dateFromJson(Object? value) =>
      value is String ? DateTime.parse(value) : null;

  Task? _findTask(String id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  List<Task> _visible({required bool includeArchived}) {
    final tasks = _tasks
        .where((t) => includeArchived || t.status != TaskStatus.archived)
        .toList();
    tasks.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return tasks;
  }

  @override
  Future<Result<List<Task>>> getAllTasks({bool includeArchived = false}) async {
    await _ensureLoaded();
    try {
      return Either.right(_visible(includeArchived: includeArchived));
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to fetch tasks: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Task?>> getTaskById(String id) async {
    await _ensureLoaded();
    try {
      return Either.right(_findTask(id));
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to fetch task: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<List<Task>>> getInboxTasks(
      {bool includeArchived = false}) async {
    await _ensureLoaded();
    try {
      final tasks = _visible(includeArchived: includeArchived)
          .where((t) => t.isInbox)
          .toList();
      return Either.right(tasks);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to fetch inbox tasks: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<List<Task>>> getTasksForProject(
    String projectId, {
    bool includeArchived = false,
  }) async {
    await _ensureLoaded();
    try {
      final tasks = _visible(includeArchived: includeArchived)
          .where((t) => t.projectId == projectId)
          .toList();
      return Either.right(tasks);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to fetch project tasks: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<List<Task>>> getTasksForGoal(
    String goalId, {
    bool includeArchived = false,
  }) async {
    await _ensureLoaded();
    try {
      final tasks = _visible(includeArchived: includeArchived)
          .where((t) => t.goalId == goalId)
          .toList();
      return Either.right(tasks);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to fetch goal tasks: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Task>> createTask(Task task) async {
    await _ensureLoaded();
    try {
      _tasks.add(task);
      await _saveTasks();
      return Either.right(task);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to create task: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Task>> updateTask(Task task) async {
    await _ensureLoaded();
    try {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index >= 0) {
        _tasks[index] = task;
        await _saveTasks();
      }
      return Either.right(task);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to update task: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> deleteTask(String id) async {
    await _ensureLoaded();
    try {
      _tasks.removeWhere((t) => t.id == id);
      await _saveTasks();
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to delete task: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> archiveTask(String id) async {
    await _ensureLoaded();
    try {
      final task = _findTask(id);
      if (task == null) {
        return Either.left(const NotFoundFailure('Task not found'));
      }

      final now = AppClock.now();
      _tasks[_tasks.indexWhere((t) => t.id == id)] = task.copyWith(
        status: TaskStatus.archived,
        archivedAt: now,
        updatedAt: now,
      );
      await _saveTasks();
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to archive task: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> unarchiveTask(String id) async {
    await _ensureLoaded();
    try {
      final task = _findTask(id);
      if (task == null) {
        return Either.left(const NotFoundFailure('Task not found'));
      }

      // Archive records no "previous status", so a restored task returns to the
      // backlog as `todo` rather than guessing it was mid-flight. Guessing
      // `doing` would resurrect a stale in-progress claim the user may not
      // still hold.
      _tasks[_tasks.indexWhere((t) => t.id == id)] = task.copyWith(
        status: TaskStatus.todo,
        archivedAt: null,
        updatedAt: AppClock.now(),
      );
      await _saveTasks();
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to unarchive task: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> reorderTasks(List<String> taskIds) async {
    await _ensureLoaded();
    try {
      for (int i = 0; i < taskIds.length; i++) {
        final task = _findTask(taskIds[i]);
        if (task != null) {
          _tasks[_tasks.indexWhere((t) => t.id == task.id)] = task.copyWith(
            sortOrder: i,
            updatedAt: AppClock.now(),
          );
        }
      }
      await _saveTasks();
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to reorder tasks: $e',
          originalError: e, stackTrace: st));
    }
  }
}
