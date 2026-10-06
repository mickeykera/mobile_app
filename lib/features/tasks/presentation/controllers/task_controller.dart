import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../recurring/domain/cutover_write_path.dart';
import '../../../habits/domain/entities/habit_completion.dart';
import '../../../habits/domain/repositories/habit_repository.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/value_objects/task_schedule.dart';
import '../../domain/value_objects/task_status.dart';

part 'task_controller.freezed.dart';

@freezed
abstract class TaskState with _$TaskState {
  const factory TaskState({
    @Default([]) List<Task> tasks,
    @Default(false) bool isLoading,
    @Default(false) bool isSaving,
    String? error,
  }) = _TaskState;
}

/// Owns the task list and every transition a task can make.
///
/// Deliberately holds the whole list rather than a per-project slice: the Inbox
/// is a *query* over the list (`Task.isInbox`), so a controller that only loaded
/// one project's tasks could not answer "what is unfiled" at all. The list is
/// also what [ProgressService] needs, so keeping it in one place means the screen
/// and the progress numbers cannot be built from different reads.
class TaskController extends StateNotifier<TaskState> {
  final TaskRepository _repository;
  final HabitRepository _habitRepository;

  /// The Stage L2 canonical write path, when the cutover gate is open.
  ///
  /// Null means legacy by construction. A non-null path mirrors task writes
  /// onto any habit whose `taskId` claims the task; an unclaimed task is
  /// written exactly as before.
  final CutoverWritePath? _cutover;

  TaskController(this._repository, this._habitRepository,
      {CutoverWritePath? cutover})
      : _cutover = cutover,
        super(const TaskState()) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    state = state.copyWith(isLoading: true, error: null);

    // Archived tasks are loaded too, and filtered on read. Two reasons: the
    // screen can only offer "unarchive" for a task it is actually holding, and
    // `HabitController` keeps archived habits in state the same way, so the two
    // lists behave alike. What the user *sees* is decided by the read getters
    // at the bottom, not by what was loaded.
    final result = await _repository.getAllTasks(includeArchived: true);
    // The provider can be disposed while the load is in flight (navigation, a
    // test tearing down); writing state afterwards throws `Bad state`.
    if (!mounted) return;

    if (result.isLeft) {
      state = state.copyWith(isLoading: false, error: result.left!.userMessage);
      return;
    }
    state = state.copyWith(isLoading: false, tasks: _sorted(result.right!));
  }

  Future<void> refresh() => _loadInitialData();

  Task? _find(String id) {
    for (final task in state.tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  static List<Task> _sorted(Iterable<Task> tasks) =>
      tasks.toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  /// Creates a task and prepends it to the working set.
  ///
  /// No project or goal is required: with neither link the task lands in the
  /// Inbox, which is the intended default rather than a half-configured state.
  Future<Result<Task>> createTask({
    required String title,
    String? description,
    TaskSchedule schedule = const Unscheduled(),
    String? projectId,
    String? goalId,
    String? category,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return Either.left(const ValidationFailure('Task title cannot be empty'));
    }

    state = state.copyWith(isSaving: true, error: null);

    final task = Task.create(
      title: trimmed,
      description: description,
      schedule: schedule,
      projectId: projectId,
      goalId: goalId,
      category: category,
      sortOrder: state.tasks.length,
    );

    final result = await _repository.createTask(task);
    if (!mounted) return result;

    if (result.isLeft) {
      state = state.copyWith(isSaving: false, error: result.left!.userMessage);
    } else {
      state = state.copyWith(
        isSaving: false,
        tasks: _sorted([...state.tasks, result.right!]),
      );
    }
    return result;
  }

  /// Persists an edited task and mirrors it into state.
  ///
  /// With a cutover path held, a task claimed by a migrated habit is written
  /// canonical-first and mirrored onto that habit (Stage L2, D1); an unclaimed
  /// task is written exactly as before.
  Future<Result<Task>> updateTask(Task task) async {
    state = state.copyWith(isSaving: true, error: null);

    final cutover = _cutover;
    final result = cutover != null
        ? await cutover.updateMigratedTask(task)
        : await _repository.updateTask(task);
    if (!mounted) return result;

    if (result.isLeft) {
      state = state.copyWith(isSaving: false, error: result.left!.userMessage);
    } else {
      state = state.copyWith(
        isSaving: false,
        tasks: _sorted(state.tasks
            .map((t) => t.id == result.right!.id ? result.right! : t)),
      );
    }
    return result;
  }

  /// Moves [id] to [status], stamping `completedAt`/`archivedAt` where the
  /// transition implies them.
  ///
  /// Reopening a done task clears `completedAt`: leaving it behind would report
  /// the task as finished in any history keyed on that stamp. Archiving
  /// *preserves* it - a task that was finished and then filed away was still
  /// finished.
  Future<Result<Task>> setStatus(String id, TaskStatus status) async {
    final task = _find(id);
    if (task == null) {
      return Either.left(NotFoundFailure('Task $id not found'));
    }

    final now = AppClock.now();
    return updateTask(task.copyWith(
      status: status,
      completedAt: switch (status) {
        TaskStatus.done => task.completedAt ?? now,
        TaskStatus.archived => task.completedAt,
        TaskStatus.todo || TaskStatus.doing => null,
      },
      archivedAt: status == TaskStatus.archived ? now : null,
      updatedAt: now,
    ));
  }

  /// Files [id] under [projectId] (or clears the link when it is null).
  ///
  /// Clearing is what puts a task back in the Inbox, and it happens here as a
  /// single write rather than as a separate "move" concept that could disagree
  /// with the links.
  Future<Result<Task>> fileUnderProject(String id, String? projectId) async {
    final task = _find(id);
    if (task == null) {
      return Either.left(NotFoundFailure('Task $id not found'));
    }

    // A project already implies its goal. Storing both would let the two links
    // disagree, and the goal rollup counts a task either way, so the redundant
    // copy is dropped rather than kept in sync.
    final goalId = projectId == null ? task.goalId : null;
    return updateTask(task.copyWith(
      projectId: projectId,
      goalId: goalId,
      updatedAt: AppClock.now(),
    ));
  }

  Future<Result<void>> deleteTask(String id) async {
    state = state.copyWith(isSaving: true, error: null);

    final cutover = _cutover;
    Result<void> result;
    if (cutover != null) {
      final habit = await cutover.habitForTask(id);
      // Stage L2 (D3): deleting a migrated pair takes the habit and its legacy
      // rows too, so a Task-surface delete cannot leave a live habit behind.
      result = habit != null
          ? await cutover.deleteMigratedPair(habit)
          : await _repository.deleteTask(id);
    } else {
      result = await _repository.deleteTask(id);
    }
    if (!mounted) return result;

    if (result.isLeft) {
      state = state.copyWith(isSaving: false, error: result.left!.userMessage);
    } else {
      state = state.copyWith(
        isSaving: false,
        tasks: state.tasks.where((t) => t.id != id).toList(),
      );
    }
    return result;
  }

  Future<Result<void>> archiveTask(String id) async {
    final cutover = _cutover;
    final result = cutover != null
        ? await cutover.setArchived(id, archived: true)
        : await _repository.archiveTask(id);
    if (!mounted) return result;

    if (result.isLeft) {
      state = state.copyWith(error: result.left!.userMessage);
    } else {
      state = state.copyWith(
        tasks: state.tasks
            .map(
                (t) => t.id == id ? t.copyWith(status: TaskStatus.archived) : t)
            .toList(),
      );
    }
    return result;
  }

  Future<Result<void>> unarchiveTask(String id) async {
    final cutover = _cutover;
    final result = cutover != null
        ? await cutover.setArchived(id, archived: false)
        : await _repository.unarchiveTask(id);
    if (!mounted) return result;

    if (result.isLeft) {
      state = state.copyWith(error: result.left!.userMessage);
    } else {
      state = state.copyWith(
        tasks: state.tasks
            .map((t) => t.id == id ? t.copyWith(status: TaskStatus.todo) : t)
            .toList(),
      );
    }
    return result;
  }

  /// Writes [taskIds] as the new manual order.
  ///
  /// Ids the controller does not hold are ignored rather than reordered blindly,
  /// so a stale drag from another screen cannot rewrite an unrelated task.
  Future<Result<void>> reorderTasks(List<String> taskIds) async {
    final result = await _repository.reorderTasks(taskIds);
    if (!mounted) return result;

    if (result.isLeft) {
      state = state.copyWith(error: result.left!.userMessage);
      return result;
    }

    final byId = {for (final task in state.tasks) task.id: task};
    final ordered = <Task>[];
    for (var i = 0; i < taskIds.length; i++) {
      final task = byId.remove(taskIds[i]);
      if (task != null) {
        ordered.add(task.copyWith(sortOrder: i, updatedAt: AppClock.now()));
      }
    }
    // Anything the caller did not mention keeps its relative order after the
    // ones it did, so a partial drag is not destructive.
    ordered.addAll(_sorted(byId.values));

    state = state.copyWith(tasks: ordered);
    return result;
  }

  /// Tasks nothing has claimed: the Inbox.
  ///
  /// Archived tasks are excluded on read. An archived task is out of the user's
  /// sight, so leaving it in the working set would keep a section's count
  /// disagreeing with the rows actually drawn under it.
  List<Task> get inbox => _visible().where((t) => t.isInbox).toList();

  List<Task> tasksForProject(String projectId) =>
      _visible().where((t) => t.projectId == projectId).toList();

  List<Task> tasksForGoal(String goalId) =>
      _visible().where((t) => t.goalId == goalId).toList();

  List<Task> _visible() =>
      state.tasks.where((t) => t.status != TaskStatus.archived).toList();

  /// Records an occurrence for a recurring task.
  ///
  /// Unlike finite tasks (which use `setStatus` to mark done), recurring tasks
  /// express completion only through occurrence rows. This method writes a
  /// [HabitCompletion] with [itemType] = 'task' and does not change the
  /// task's [TaskStatus] or [completedAt].
  ///
  /// Returns the created completion row, or an existing one if the same
  /// task+date was already recorded (idempotent).
  Future<Result<HabitCompletion>> recordOccurrence(
    String taskId, {
    required DateTime date,
    int count = 1,
    Duration? duration,
    String? note,
    int? moodRating,
    int? energyRating,
  }) async {
    final task = _find(taskId);
    if (task == null) {
      return Either.left(NotFoundFailure('Task $taskId not found'));
    }
    if (task.schedule is! Recurring) {
      return Either.left(
          ValidationFailure('Task $taskId is not a recurring task'));
    }

    return _habitRepository.recordRecurringTaskOccurrence(
      taskId: taskId,
      date: date,
      count: count,
      duration: duration,
      note: note,
      moodRating: moodRating,
      energyRating: energyRating,
    );
  }

  /// Removes an occurrence for a recurring task.
  ///
  /// Symmetric with [recordOccurrence]. Does not change the task's status.
  Future<Result<void>> deleteOccurrence(
    String taskId, {
    required DateTime date,
  }) async {
    final task = _find(taskId);
    if (task == null) {
      return Either.left(NotFoundFailure('Task $taskId not found'));
    }
    if (task.schedule is! Recurring) {
      return Either.left(
          ValidationFailure('Task $taskId is not a recurring task'));
    }

    return _habitRepository.deleteRecurringTaskOccurrence(
      taskId: taskId,
      date: date,
    );
  }
}
