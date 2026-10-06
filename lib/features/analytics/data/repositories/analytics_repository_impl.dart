import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../focus/data/repositories/focus_repository_impl.dart';
import '../../../focus/domain/repositories/focus_repository.dart';
import '../../../habits/presentation/providers/habit_providers.dart';
import '../../../habits/domain/entities/habit.dart';
import '../../../habits/domain/entities/habit_completion.dart';
import '../../../habits/domain/repositories/habit_repository.dart';
import '../../../journal/data/repositories/journal_repository_impl.dart';
import '../../../journal/domain/entities/journal_entry.dart';
import '../../../journal/domain/repositories/journal_repository.dart';
import '../../../progress/domain/services/progress_service.dart';
import '../../../tasks/domain/entities/task.dart';
import '../../../tasks/domain/repositories/task_repository.dart';
import '../../../tasks/presentation/providers/task_providers.dart';
import '../../domain/analytics_data.dart';
import '../../domain/analytics_repository.dart';

/// Aggregates the habit, focus and journal repositories into the read models
/// consumed by the analytics screen.
///
/// Every derived number here comes from [ProgressService] rather than being
/// summed inline, so this class stays an orchestration of reads and the metric
/// definitions have exactly one home.
///
/// The habit and Task repositories are both needed because a migrated habit is
/// only half a habit: its legacy record carries frozen counters, and its history
/// lives in the Task occurrence log. Reading only one of them is what made this
/// screen report stale streaks and a heatmap that stopped at the migration date.
class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final HabitRepository _habitRepository;
  final TaskRepository _taskRepository;
  final FocusRepository _focusRepository;
  final JournalRepository _journalRepository;
  final ProgressService _progress;

  AnalyticsRepositoryImpl(
    this._habitRepository,
    this._taskRepository,
    this._focusRepository,
    this._journalRepository, [
    this._progress = const ProgressService(),
  ]);

  @override
  Future<Result<AnalyticsData>> getAnalyticsData({
    required DateTime startDate,
    required DateTime endDate,
    int heatmapWeeks = 4,
  }) async {
    final habitsResult =
        await _habitRepository.getAllHabits(includeArchived: true);
    if (habitsResult.isLeft) return Either.left(habitsResult.left!);
    final habits = habitsResult.right!;

    final completionsResult = await _recurringInputs();
    if (completionsResult.isLeft) return Either.left(completionsResult.left!);
    final (tasks, completions) = completionsResult.right!;

    final sessionsResult = await _focusRepository.getSessions(
        startDate: startDate, endDate: endDate);
    if (sessionsResult.isLeft) return Either.left(sessionsResult.left!);
    final sessions = sessionsResult.right!;

    final entriesResult = await _journalRepository.getEntries(
        startDate: startDate, endDate: endDate);
    if (entriesResult.isLeft) return Either.left(entriesResult.left!);
    final entries = entriesResult.right!;

    final focusHeatmapResult =
        await _focusRepository.getFocusHeatmap(weeks: heatmapWeeks);
    if (focusHeatmapResult.isLeft) return Either.left(focusHeatmapResult.left!);

    final windowed = await _completionsIn(startDate, endDate);
    if (windowed.isLeft) return Either.left(windowed.left!);

    final moodCorrelationResult =
        await _correlationFor(habits, entries, windowed, 'mood');
    if (moodCorrelationResult.isLeft) {
      return Either.left(moodCorrelationResult.left!);
    }

    final energyCorrelationResult =
        await _correlationFor(habits, entries, windowed, 'energy');
    if (energyCorrelationResult.isLeft) {
      return Either.left(energyCorrelationResult.left!);
    }

    final focus = _progress.focusBreakdown(sessions);

    return Either.right(AnalyticsData(
      startDate: startDate,
      endDate: endDate,
      habitHeatmap: _progress.recurringCompletionHeatmap(
        habits: habits,
        completions: completions,
        weeks: heatmapWeeks,
      ),
      categoryCompletions: _progress.recurringCompletionsByCategory(
        habits: habits,
        tasks: tasks,
        completions: completions,
      ),
      categoryStreaks: _progress.recurringStreaksByCategory(
        habits: habits,
        tasks: tasks,
        completions: completions,
      ),
      totalFocusMinutes: focus.totalMinutes,
      focusByCategory: focus.byCategory,
      focusHeatmap: focusHeatmapResult.right!,
      journalEntriesCount: entries.length,
      moodDistribution:
          _progress.moodDistribution(entries.map((e) => e.moodRating)),
      energyDistribution:
          _progress.energyDistribution(entries.map((e) => e.energyRating)),
      avgMood: _progress.averageRating(entries.map((e) => e.moodRating)),
      avgEnergy: _progress.averageRating(entries.map((e) => e.energyRating)),
      moodHabitCorrelation: moodCorrelationResult.right!,
      energyHabitCorrelation: energyCorrelationResult.right!,
    ));
  }

  @override
  Future<Result<Map<DateTime, int>>> getHabitHeatmap({int weeks = 12}) async {
    final habitsResult =
        await _habitRepository.getAllHabits(includeArchived: true);
    if (habitsResult.isLeft) return Either.left(habitsResult.left!);

    final completionsResult = await _habitRepository.getAllCompletions();
    if (completionsResult.isLeft) return Either.left(completionsResult.left!);

    return Either.right(_progress.recurringCompletionHeatmap(
      habits: habitsResult.right!,
      completions: completionsResult.right!,
      weeks: weeks,
    ));
  }

  /// The Task list and the whole completion log, which are the two halves of a
  /// recurring item's history after migration.
  Future<Result<(List<Task>, List<HabitCompletion>)>> _recurringInputs() async {
    final tasksResult = await _taskRepository.getAllTasks();
    if (tasksResult.isLeft) return Either.left(tasksResult.left!);

    final completionsResult = await _habitRepository.getAllCompletions();
    if (completionsResult.isLeft) return Either.left(completionsResult.left!);

    return Either.right((tasksResult.right!, completionsResult.right!));
  }

  @override
  Future<Result<Map<String, int>>> getHabitCompletionsByCategory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final habitsResult =
        await _habitRepository.getAllHabits(includeArchived: true);
    if (habitsResult.isLeft) return Either.left(habitsResult.left!);

    final habits = habitsResult.right!;

    // No window means "all time", which the habits already carry as a lifetime
    // counter; a window has to be counted from the log instead.
    if (startDate == null && endDate == null) {
      final recurringResult = await _recurringInputs();
      if (recurringResult.isLeft) return Either.left(recurringResult.left!);
      final (tasks, completions) = recurringResult.right!;
      return Either.right(_progress.recurringCompletionsByCategory(
        habits: habits,
        tasks: tasks,
        completions: completions,
      ));
    }

    final allCompletionsResult = await _habitRepository.getAllCompletions();
    if (allCompletionsResult.isLeft) {
      return Either.left(allCompletionsResult.left!);
    }
    return Either.right(_progress.recurringCompletionsByCategoryFromLog(
      habits: habits,
      completions: allCompletionsResult.right!,
      startDate: startDate,
      endDate: endDate,
    ));
  }

  @override
  Future<Result<Map<String, int>>> getHabitStreaksByCategory() async {
    final habitsResult =
        await _habitRepository.getAllHabits(includeArchived: true);
    if (habitsResult.isLeft) return Either.left(habitsResult.left!);

    final recurringResult = await _recurringInputs();
    if (recurringResult.isLeft) return Either.left(recurringResult.left!);
    final (tasks, completions) = recurringResult.right!;

    return Either.right(_progress.recurringStreaksByCategory(
      habits: habitsResult.right!,
      tasks: tasks,
      completions: completions,
    ));
  }

  @override
  Future<Result<int>> getTotalFocusMinutes(
      {DateTime? startDate, DateTime? endDate}) {
    return _focusRepository.getTotalFocusMinutes(
        startDate: startDate, endDate: endDate);
  }

  @override
  Future<Result<Map<String, int>>> getFocusByCategory(
      {DateTime? startDate, DateTime? endDate}) {
    return _focusRepository.getFocusByCategory(
        startDate: startDate, endDate: endDate);
  }

  @override
  Future<Result<Map<DateTime, int>>> getFocusHeatmap({int weeks = 12}) {
    return _focusRepository.getFocusHeatmap(weeks: weeks);
  }

  @override
  Future<Result<int>> getJournalEntriesCount(
      {DateTime? startDate, DateTime? endDate}) async {
    final result = await _journalRepository.getEntries(
        startDate: startDate, endDate: endDate);
    if (result.isLeft) return Either.left(result.left!);
    return Either.right(result.right!.length);
  }

  @override
  Future<Result<Map<String, int>>> getMoodDistribution(
      {DateTime? startDate, DateTime? endDate}) {
    return _journalRepository.getMoodDistribution(
        startDate: startDate, endDate: endDate);
  }

  @override
  Future<Result<Map<String, int>>> getEnergyDistribution(
      {DateTime? startDate, DateTime? endDate}) {
    return _journalRepository.getEnergyDistribution(
        startDate: startDate, endDate: endDate);
  }

  @override
  Future<Result<double>> getAverageMood(
      {DateTime? startDate, DateTime? endDate}) async {
    final result = await _journalRepository.getEntries(
        startDate: startDate, endDate: endDate);
    if (result.isLeft) return Either.left(result.left!);
    return Either.right(
        _progress.averageRating(result.right!.map((e) => e.moodRating)));
  }

  @override
  Future<Result<double>> getAverageEnergy(
      {DateTime? startDate, DateTime? endDate}) async {
    final result = await _journalRepository.getEntries(
        startDate: startDate, endDate: endDate);
    if (result.isLeft) return Either.left(result.left!);
    return Either.right(
        _progress.averageRating(result.right!.map((e) => e.energyRating)));
  }

  @override
  Future<Result<List<CorrelationPoint>>> getMoodHabitCorrelation({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _correlationForRange('mood', startDate, endDate);
  }

  @override
  Future<Result<List<CorrelationPoint>>> getEnergyHabitCorrelation({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _correlationForRange('energy', startDate, endDate);
  }

  Future<Result<List<CorrelationPoint>>> _correlationForRange(
    String type,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    final habitsResult =
        await _habitRepository.getAllHabits(includeArchived: true);
    if (habitsResult.isLeft) return Either.left(habitsResult.left!);

    final entriesResult = await _journalRepository.getEntries(
        startDate: startDate, endDate: endDate);
    if (entriesResult.isLeft) return Either.left(entriesResult.left!);

    return _correlationFor(
      habitsResult.right!,
      entriesResult.right!,
      await _completionsIn(startDate, endDate),
      type,
    );
  }

  /// Pairs each journal rating with the share of habits that were completed on
  /// that day, producing one point per rated day.
  Future<Result<List<CorrelationPoint>>> _correlationFor(
    List<Habit> habits,
    List<JournalEntry> entries,
    Result<List<HabitCompletion>> completionsResult,
    String type,
  ) async {
    if (completionsResult.isLeft) {
      return Either.left(completionsResult.left!);
    }

    // Resolved through the same ownership map the category and heatmap reads
    // use, so a migrated habit is credited its Task rows and charged only once.
    final completionsByDay = _progress.completedHabitIdsByDay(
      completionsResult.right!,
      ProgressService.habitIdByTaskId(habits),
    );

    final points = <CorrelationPoint>[];
    for (final entry in entries) {
      final rating = type == 'mood' ? entry.moodRating : entry.energyRating;
      if (rating == null) continue;

      final date = entry.date.startOfDay;
      final percent = _progress.dayHabitCompletionPercent(
        habits: habits,
        completedByDay: completionsByDay,
        day: date,
      );
      // Nothing was due that day, so there is no completion share to correlate.
      if (percent == null) continue;

      points.add(CorrelationPoint(
        x: percent,
        y: rating.toDouble(),
        label: date.formatRelative(),
      ));
    }

    points.sort((a, b) => a.x.compareTo(b.x));
    return Either.right(points);
  }

  /// Completion rows inside an optional window.
  ///
  /// A window is applied here, on the shared log, rather than by asking the
  /// repository once per habit. Two consequences worth stating: it is one query
  /// instead of one per habit, and it sees Task rows for migrated habits, which
  /// the per-habit query structurally cannot return.
  Future<Result<List<HabitCompletion>>> _completionsIn(
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    if (startDate == null || endDate == null) {
      return _habitRepository.getAllCompletions();
    }
    return _habitRepository.getCompletionsInRange(startDate, endDate);
  }
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepositoryImpl(
    ref.watch(habitRepositoryProvider),
    ref.watch(taskRepositoryProvider),
    ref.watch(focusRepositoryProvider),
    ref.watch(journalRepositoryProvider),
    ref.watch(progressServiceProvider),
  );
});
