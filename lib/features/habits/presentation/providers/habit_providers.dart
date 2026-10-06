import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_clock.dart';
import '../controllers/habit_controller.dart';
import '../../data/repositories/habit_repository_impl.dart';
import '../../domain/repositories/habit_repository.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/database/database.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_completion.dart';
import '../../../progress/domain/services/progress_service.dart';
import '../../../recurring/domain/cutover_readiness.dart';
import '../../../recurring/domain/cutover_write_path.dart';
import '../../../tasks/domain/entities/task.dart';
import '../../../tasks/domain/value_objects/task_schedule.dart';
import '../../../tasks/presentation/providers/task_providers.dart';

/// The habits repository, so every consumer shares one instance.
///
/// Was constructed inline inside [habitControllerProvider], which meant the
/// Today view had to build a *second* repository to read the week's
/// completions - a second copy of the in-memory cache, built from the same
/// storage.
final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return HabitRepositoryImpl(ref.watch(databaseServiceProvider));
});

/// The Stage L2 canonical write path, or null while the cutover gate is closed.
///
/// Both controllers watch this, so the gate is read once per wiring rebuild
/// rather than per write. It lives in the habit providers because
/// `recurring_providers` already imports this file, and the reverse would be a
/// provider import cycle.
final cutoverWritePathProvider = Provider<CutoverWritePath?>((ref) {
  if (!CutoverGate.enabled) return null;
  return CutoverWritePath(
    habitRepository: ref.watch(habitRepositoryProvider),
    taskRepository: ref.watch(taskRepositoryProvider),
  );
});

final habitControllerProvider =
    StateNotifierProvider<HabitController, HabitState>((ref) {
  return HabitController(
    ref.watch(habitRepositoryProvider),
    cutover: ref.watch(cutoverWritePathProvider),
  );
});

/// Reads habit completions across the week containing [day].
///
/// A function provider because the habits controller only holds completions for
/// one day in its state - the day being viewed - so anything that needs a range
/// has to go back to the repository. Declared as a single range call rather than
/// a loop over seven days because each per-day call re-reads the whole
/// completions list out of storage.
final habitCompletionsInRangeProvider =
    Provider<Future<List<HabitCompletion>> Function(DateTime day)>((ref) {
  final repository = ref.watch(habitRepositoryProvider);
  return (day) async {
    final result = await repository.getCompletionsInRange(
      day.startOfWeek,
      day.endOfWeek,
    );
    return result.getOrElse((_) => const <HabitCompletion>[]);
  };
});

final habitsProvider = Provider<List<Habit>>((ref) {
  return ref.watch(habitControllerProvider).habits;
});

/// Every completion row, of every owner, across the whole history.
///
/// Distinct from [habitCompletionsInRangeProvider] on purpose. A range covers
/// one week, which is enough to draw the week strip and no more; a current
/// streak is a chain that may have started months ago, so anything re-deriving
/// one has to read the entire log. Reading a week and calling it a streak is how
/// a badge ends up reporting the length of a chain it only saw the tail of.
final allCompletionsProvider =
    FutureProvider<List<HabitCompletion>>((ref) async {
  // Watched purely as invalidation signals. Both controllers are needed: a
  // migrated habit's completions are written through TaskController, so watching
  // only the habit controller would leave every derived streak stale after a
  // recurring occurrence - which is the one write that most needs to show up.
  ref.watch(habitControllerProvider
      .select((state) => state.todaysCompletions.length));
  ref.watch(taskControllerProvider.select((state) => state.tasks.length));
  final result = await ref.watch(habitRepositoryProvider).getAllCompletions();
  return result.getOrElse((_) => const <HabitCompletion>[]);
});

final todaysCompletionsProvider = Provider<List<HabitCompletion>>((ref) {
  return ref.watch(habitControllerProvider).todaysCompletions;
});

/// Habits due on the day the controller is currently showing. Must read the
/// state (not the notifier): watching `.notifier` never re-notifies, so this
/// would freeze at the value computed for the very first build.
final dueHabitsProvider = Provider<List<Habit>>((ref) {
  final state = ref.watch(habitControllerProvider);
  return HabitController.dueHabitsFor(state.habits, _targetDate(state));
});

final todaysProgressProvider = Provider<double>((ref) {
  final state = ref.watch(habitControllerProvider);
  return HabitController.progressFor(
    habits: state.habits,
    completions: state.todaysCompletions,
    date: _targetDate(state),
    taskIdToHabitId: ProgressService.habitIdByTaskId(state.habits),
  );
});

/// The day the loaded completion list belongs to: the user-picked date, or
/// today while none has been picked.
DateTime _targetDate(HabitState state) => state.selectedDate ?? AppClock.now();

/// Non-migrated habits (taskId == null) - the "pure" habits still managed by HabitController.
final nonMigratedHabitsProvider = Provider<List<Habit>>((ref) {
  final allHabits = ref.watch(habitsProvider);
  return allHabits.where((h) => h.taskId == null && !h.isArchived).toList();
});

/// Migrated habits (taskId != null) - shown in HabitsScreen as "Recurring Tasks".
/// These are read-only in HabitController; completion is delegated to TaskController.
final migratedHabitsProvider = Provider<List<Habit>>((ref) {
  final allHabits = ref.watch(habitsProvider);
  return allHabits.where((h) => h.taskId != null && !h.isArchived).toList();
});

/// Recurring tasks from TaskController that originated from migrated habits.
/// These are the authoritative source for completions of migrated habits.
final recurringTasksFromMigratedHabitsProvider = Provider<List<Task>>((ref) {
  final allTasks = ref.watch(tasksProvider);
  final migratedHabitIds =
      ref.watch(migratedHabitsProvider).map((h) => h.taskId!).toSet();
  return allTasks
      .where((t) => t.schedule is Recurring && migratedHabitIds.contains(t.id))
      .toList();
});

/// Completion state for recurring tasks from migrated habits, keyed by taskId.
/// Used by HabitsScreen to show completion status for the "Recurring Tasks" section.
final migratedHabitTaskCompletionsProvider =
    FutureProvider.family<Map<String, bool>, DateTime>((ref, date) async {
  final repository = ref.watch(habitRepositoryProvider);
  final migratedHabits = ref.watch(migratedHabitsProvider);
  if (migratedHabits.isEmpty) return {};

  final taskIds = migratedHabits.map((h) => h.taskId!).toList();
  final result = await repository.getCompletionsInRange(
    date.startOfDay,
    date.endOfDay,
  );
  final completions = result.getOrElse((_) => const <HabitCompletion>[]);

  final completionMap = <String, bool>{};
  for (final taskId in taskIds) {
    completionMap[taskId] = completions.any((c) =>
        c.itemId == taskId &&
        c.itemType == 'task' &&
        c.completedAt.startOfDay == date.startOfDay);
  }
  return completionMap;
});
