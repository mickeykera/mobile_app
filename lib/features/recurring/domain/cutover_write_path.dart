import '../../../core/errors/failures.dart';
import '../../../core/utils/app_clock.dart';
import '../../habits/domain/entities/habit.dart';
import '../../habits/domain/repositories/habit_repository.dart';
import '../../tasks/domain/entities/task.dart';
import '../../tasks/domain/repositories/task_repository.dart';
import '../../tasks/domain/value_objects/task_schedule.dart';
import '../../tasks/domain/value_objects/task_status.dart';
import 'habit_task_identity.dart';
import 'migration.dart';

/// The Stage L2 canonical write path: the one seam where a write to recurring
/// work becomes a write to the canonical `Task`.
///
/// A controller built *holding* this object routes its qualifying writes
/// through it; a controller without one is a legacy controller by construction
/// (see `docs/ascend-stage-l2-task-write-cutover.md` §2). The path is the only
/// place that knows how a `Habit` and its `Task` are kept in step, so the
/// controllers stay thin and the ownership rules live in one file.
///
/// ## The write contract
///
/// Every paired write is **canonical-first**: the Task is written first, then
/// the Habit is mirrored from it. A canonical failure returns `Left` and leaves
/// the legacy row untouched. A mirror failure triggers a compensating rollback
/// of the canonical write and returns `Left`, so the operation is
/// all-or-nothing from the caller's point of view: either both sides advanced
/// or neither did. The rollback is best-effort; if it also fails the audit
/// surfaces the divergence and the next write converges, which is why every
/// write is idempotent and always carries the full owned-field set.
///
/// Deletes are the one exception: they are not rolled back, because undoing a
/// `deleteTask` would have to recreate an entity (and possibly its history).
/// Instead the delete is ordered so its partial-failure residues are all
/// recoverable by the auditor and by retry — see [deleteMigratedPair].
class CutoverWritePath {
  CutoverWritePath({
    required HabitRepository habitRepository,
    required TaskRepository taskRepository,
  })  : _habitRepository = habitRepository,
        _taskRepository = taskRepository,
        _migration = MigrationService(habitRepository, taskRepository);

  final HabitRepository _habitRepository;
  final TaskRepository _taskRepository;

  /// Owned internally so the path needs no provider imports and cannot be
  /// wired to a different repository pair than the one it writes through.
  final MigrationService _migration;

  /// The habit whose `taskId` claims [taskId], or null when no habit does.
  ///
  /// Scans every habit including archived ones: a migrated habit can be
  /// archived on either side (D2), and an archived habit still owns its Task.
  /// Matching on `taskId` rather than deriving the id from the habit is
  /// deliberate - migration may adopt a Task with a non-deterministic id.
  Future<Habit?> habitForTask(String taskId) async {
    final result = await _habitRepository.getAllHabits(includeArchived: true);
    final habits = result.getOrNull();
    if (habits == null) return null;
    for (final habit in habits) {
      if (habit.taskId == taskId) return habit;
    }
    return null;
  }

  /// Migrates a habit the app just created, so a new recurring item is born
  /// canonical (Stage L2, D4).
  ///
  /// Returns the habit re-shaped with its new `taskId`. When migration or its
  /// verification fails, the just-created habit is deleted again so a failure
  /// cannot leave a half-created item, and the failure is returned. If even
  /// that compensating delete fails the habit survives unlinked, and the D4
  /// startup backfill adopts it on the next launch.
  Future<Result<Habit>> linkNewlyCreated(Habit habit) async {
    try {
      final outcome = await _migration.migrateHabit(habit.id);
      if (!outcome.isSuccess || !outcome.verification.isVerified) {
        await _habitRepository.deleteHabit(habit.id);
        final detail = outcome.error ??
            'verification failed for ${outcome.state.name}';
        return Either.left(
          CacheFailure('Could not create the recurring task: $detail'),
        );
      }
      return Either.right(habit.copyWith(taskId: outcome.taskId));
    } catch (error) {
      await _habitRepository.deleteHabit(habit.id);
      return Either.left(CacheFailure('Could not create the recurring task.',
          originalError: error));
    }
  }

  /// Writes a migrated habit's owned fields onto its Task, then mirrors the
  /// same fields back onto the habit (Stage L2 D1/D2/D5).
  ///
  /// Canonical-first with compensating rollback: if the mirror fails, the Task
  /// is restored to its pre-write value before the failure is returned, so the
  /// pair converges back on the pre-operation state instead of leaving the
  /// canonical side ahead - which the launch capability bridge would otherwise
  /// read as authoritative and push over the habit.
  Future<Result<Habit>> updateMigrated(Habit habit) async {
    final taskId = habit.taskId;
    if (taskId == null) {
      return Either.left(
        ValidationFailure('Habit ${habit.id} is not linked to a Task'),
      );
    }
    final read = await _taskRepository.getTaskById(taskId);
    if (read.isLeft) return Either.left(read.left!);
    final previous = read.right;
    if (previous == null) {
      return Either.left(NotFoundFailure('Task $taskId not found'));
    }

    final canonical = _canonicalFromHabit(previous, habit);
    final write = await _taskRepository.updateTask(canonical);
    if (write.isLeft) return Either.left(write.left!);

    final mirror = await _habitRepository.updateHabit(habit);
    if (mirror.isLeft) {
      await _taskRepository.updateTask(previous);
      return Either.left(mirror.left!);
    }
    return Either.right(habit);
  }

  /// Writes a Task through the canonical path, mirroring any claiming habit.
  ///
  /// A Task with no claiming habit is written exactly as before - the mirror is
  /// skipped, not faked. The Task's description is normalised to a non-null
  /// string so an empty description cannot leave the pair permanently
  /// divergent (`Task.description` is nullable, `Habit.description` is not, and
  /// the auditor compares them strictly).
  Future<Result<Task>> updateMigratedTask(Task task) async {
    final habit = await habitForTask(task.id);
    if (habit == null) return _taskRepository.updateTask(task);

    final read = await _taskRepository.getTaskById(task.id);
    if (read.isLeft) return Either.left(read.left!);
    final previous = read.right;
    if (previous == null) return _taskRepository.updateTask(task);

    final canonical = task.copyWith(description: task.description ?? '');
    final write = await _taskRepository.updateTask(canonical);
    if (write.isLeft) return Either.left(write.left!);

    final mirror = await _habitRepository.updateHabit(
      _habitFromTask(habit, canonical),
    );
    if (mirror.isLeft) {
      await _taskRepository.updateTask(previous);
      return Either.left(mirror.left!);
    }
    return Either.right(canonical);
  }

  /// Archives or unarchives the canonical Task and mirrors the habit, or does
  /// the plain legacy write when nothing claims the Task.
  Future<Result<void>> setArchived(String taskId,
      {required bool archived}) async {
    final habit = await habitForTask(taskId);
    if (habit == null) {
      return archived
          ? _taskRepository.archiveTask(taskId)
          : _taskRepository.unarchiveTask(taskId);
    }

    final read = await _taskRepository.getTaskById(taskId);
    final previous = read.getOrNull();
    final write = archived
        ? await _taskRepository.archiveTask(taskId)
        : await _taskRepository.unarchiveTask(taskId);
    if (write.isLeft) return Either.left(write.left!);

    final mirror = archived
        ? await _habitRepository.archiveHabit(habit.id)
        : await _habitRepository.unarchiveHabit(habit.id);
    if (mirror.isLeft) {
      if (previous != null) await _taskRepository.updateTask(previous);
      return Either.left(mirror.left!);
    }
    return Either.right(null);
  }

  /// Deletes a migrated pair in the only order that leaves every interruption
  /// recoverable (Stage L2, D3):
  ///
  /// 1. delete the canonical Task - fails transparently, nothing changed;
  /// 2. delete the Task's occurrence rows - a failure leaves a dangling link
  ///    with intact history, which the auditor reports and a retry converges;
  /// 3. delete the habit and its legacy rows - a failure leaves a dangling link
  ///    with the Task already gone, which the auditor reports and which the
  ///    backfill must never "repair" by resurrecting the Task.
  ///
  /// Deletions are not rolled back. Each step is idempotent, so the caller may
  /// retry; the residue table lives in the stage document.
  Future<Result<void>> deleteMigratedPair(Habit habit) async {
    final taskId = habit.taskId;
    if (taskId == null) {
      return Either.left(
        ValidationFailure('Habit ${habit.id} is not linked to a Task'),
      );
    }

    final taskDelete = await _taskRepository.deleteTask(taskId);
    if (taskDelete.isLeft) return Either.left(taskDelete.left!);

    final all = await _habitRepository.getAllCompletions();
    if (all.isLeft) return Either.left(all.left!);
    final rows = all.right!
        .where((c) => c.itemId == taskId && c.itemType == 'task')
        .toList();
    for (final row in rows) {
      final deleted = await _habitRepository.deleteCompletion(row.id);
      if (deleted.isLeft) return Either.left(deleted.left!);
    }

    return _habitRepository.deleteHabit(habit.id);
  }

  /// The Task a migrated habit's owned fields imply, leaving Task-only fields
  /// ([Task.id], [Task.createdAt], [Task.completedAt], [Task.sortOrder] and the
  /// legacy counters) untouched.
  Task _canonicalFromHabit(Task task, Habit habit) {
    final archived = habit.isArchived;
    final status = archived
        ? TaskStatus.archived
        : (task.status == TaskStatus.archived ? TaskStatus.todo : task.status);
    return LegacyHabitCapabilities.fromHabit(habit).applyTo(task.copyWith(
          title: habit.title,
          description: habit.description,
          category: habit.category,
          projectId: habit.projectId,
          goalId: habit.goalId,
          schedule: habit.recurringSchedule,
          status: status,
          archivedAt: archived ? (task.archivedAt ?? habit.updatedAt) : null,
          updatedAt: AppClock.now(),
        ));
  }

  /// The Habit a Task write implies, leaving habit-only fields (`id`,
  /// `createdAt`, `sortOrder`, streak counters) alone and normalising the
  /// nullable description.
  Habit _habitFromTask(Habit habit, Task task) {
    final schedule = task.schedule;
    final recurring = schedule is Recurring ? schedule : null;
    return habit.copyWith(
      title: task.title,
      description: task.description ?? '',
      category: task.category ?? habit.category,
      projectId: task.projectId,
      goalId: task.goalId,
      frequency: recurring?.rule.frequency ?? habit.frequency,
      customWeekdays: recurring?.rule.customWeekdays ?? habit.customWeekdays,
      dueAt: recurring != null ? recurring.dueAt : habit.dueAt,
      snoozedUntil: recurring != null ? recurring.snoozedUntil : habit.snoozedUntil,
      isArchived: task.status == TaskStatus.archived,
      targetCount: task.targetCount,
      targetDuration: task.targetDuration,
      cue: task.cue,
      timeOfDay: task.timeOfDay,
      streakFreezesUsed: task.streakFreezeUsage.used,
    );
  }
}