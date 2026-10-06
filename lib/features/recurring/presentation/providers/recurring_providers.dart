import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../habits/domain/entities/habit_completion.dart';
import '../../../habits/presentation/providers/habit_providers.dart';
import '../../../progress/domain/services/progress_service.dart';
import '../../../tasks/presentation/providers/task_providers.dart';
import '../../domain/migration.dart';
import '../../domain/migration_runner.dart';
import '../../domain/recurring_streak.dart';
import '../../domain/recurring_work.dart';
import '../../domain/streak_parity.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/database/database.dart';

/// Both models' recurring work, as one list.
///
/// Read-only by construction: it reads the two controllers and writes nothing,
/// which is what lets a screen migrate onto this without changing behaviour.
/// Both inputs are already archived-filtered, so archived work never appears
/// here.
final recurringWorkProvider = Provider<List<RecurringWork>>((ref) {
  return recurringWorkFrom(
    habits: ref.watch(habitsProvider),
    tasks: ref.watch(taskControllerProvider).tasks,
  );
});

/// Recurring work filed under [projectId], across both sources.
///
/// For the same reason F2 does not show `habitCompletionCount` on the project
/// detail screen, this counts the work rather than reporting whether it was
/// done: a recurring task has no completion log to count, so a number here would
/// silently mean "habit days" on one source and nothing on the other.
final recurringWorkForProjectProvider =
    Provider.family<List<RecurringWork>, String>((ref, projectId) {
  return ref
      .watch(recurringWorkProvider)
      .where((w) => w.projectId == projectId)
      .toList();
});

/// How many pieces of recurring work came from each source.
///
/// The read-only counterpart of the parity report: it says how much of the
/// recurring workload still lives in `Habit`, which is the number a later stage
/// is trying to drive to zero.
final recurringSourceCountsProvider =
    Provider<Map<RecurringSource, int>>((ref) {
  final counts = <RecurringSource, int>{
    for (final source in RecurringSource.values) source: 0,
  };
  for (final work in ref.watch(recurringWorkProvider)) {
    counts[work.source] = counts[work.source]! + 1;
  }
  return counts;
});

/// The streak parity report, over every habit and the whole completion log.
///
/// Reads the *whole* log rather than a range on purpose: parity compares a
/// habit's stored streak counters against its entire history, so a range would
/// report divergence for every habit whose history reaches outside it — a
/// fabricated finding, which is worse than no report.
///
/// Watches the controller as an invalidation signal. Without it this provider is
/// read once and cached forever, so completing a habit would leave the report
/// describing the previous state of the world.
///
/// A failed read resolves to an empty report, matching
/// [habitCompletionsInRangeProvider]. Note that an empty report is
/// indistinguishable from "everything agrees", so a consumer that gates on this
/// must treat it as advisory rather than as a pass.
final streakParityReportProvider =
    FutureProvider<List<HabitStreakParity>>((ref) async {
  // Watched purely as an invalidation signal: without it this provider is read
  // once and cached forever, so completing a habit would leave the report
  // describing the previous state of the world.
  ref.watch(habitControllerProvider);
  final habits = ref.watch(habitsProvider);

  final completions =
      await ref.watch(habitRepositoryProvider).getAllCompletions();

  return parityReportFor(
    habits: habits,
    completions: completions.getOrElse((_) => const <HabitCompletion>[]),
  );
});

/// Only the habits whose log and stored counters disagree.
///
/// This is the finding Stage G exists to produce: a non-empty list means the two
/// records of the same history are out of step, and a write stage cannot assume
/// which one to trust.
final divergentStreakParityProvider =
    FutureProvider<List<HabitStreakParity>>((ref) async {
  return divergentParities(await ref.watch(streakParityReportProvider.future));
});

/// Whether a specific migrated recurring task is completed today.
///
/// Answers through [RecurringStreak] rather than re-filtering the log, so the
/// tick on the Today screen and the day the streak arithmetic counted are the
/// same day by construction.
final taskOccurrenceTodayProvider =
    FutureProvider.family<bool, String>((ref, taskId) async {
  final completions = await ref.watch(allCompletionsProvider.future);
  return RecurringStreak.forTaskLog(completions, taskId)
      .isCompletedOn(AppClock.now().startOfDay);
});

/// Current streak per recurring Task category, over the whole completion log.
///
/// The provider-side read of `ProgressService.taskStreaksByCategory`, which is
/// what the Analytics screen reaches through the merged
/// `recurringStreaksByCategory`. Both run the same [RecurringStreak] arithmetic
/// rather than one calling into the other, so the rule still has one home.
final taskStreaksByCategoryProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final completions = await ref.watch(allCompletionsProvider.future);
  return const ProgressService().taskStreaksByCategory(
    ref.watch(tasksProvider),
    completions,
  );
});

/// Migration service for Habit → Task convergence.
final migrationServiceProvider = Provider<MigrationService>((ref) {
  return MigrationService(
    ref.watch(habitRepositoryProvider),
    ref.watch(taskRepositoryProvider),
  );
});

/// Parity gate report provider.
///
/// Runs the parity check on all Habits and produces a [MigrationReport].
/// This is the mandatory gate before any migration.
final migrationReportProvider = FutureProvider<MigrationReport>((ref) async {
  return ref.watch(migrationServiceProvider).runParityGate();
});

/// The production execution point for the Habit -> Task migration.
///
/// Resolved during startup, after the database is initialised. Reading this
/// provider does **not** start a migration - it only hands back the runner - so
/// nothing migrates merely because the parity report above was read.
final habitTaskMigrationRunnerProvider =
    Provider<HabitTaskMigrationRunner>((ref) {
  return HabitTaskMigrationRunner(
    migration: ref.watch(migrationServiceProvider),
    database: ref.watch(databaseServiceProvider),
  );
});
