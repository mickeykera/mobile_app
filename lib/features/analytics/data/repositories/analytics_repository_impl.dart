import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../focus/data/repositories/focus_repository_impl.dart';
import '../../../focus/domain/entities/focus_session.dart';
import '../../../focus/domain/repositories/focus_repository.dart';
import '../../../habits/data/repositories/habit_repository_impl.dart';
import '../../../habits/domain/entities/habit.dart';
import '../../../habits/domain/repositories/habit_repository.dart';
import '../../../journal/data/repositories/journal_repository_impl.dart';
import '../../../journal/domain/entities/journal_entry.dart';
import '../../../journal/domain/repositories/journal_repository.dart';
import '../../domain/analytics_data.dart';
import '../../domain/analytics_repository.dart';

/// Aggregates the habit, focus and journal repositories into the read models
/// consumed by the analytics screen.
class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final HabitRepository _habitRepository;
  final FocusRepository _focusRepository;
  final JournalRepository _journalRepository;

  AnalyticsRepositoryImpl(
    this._habitRepository,
    this._focusRepository,
    this._journalRepository,
  );

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

    final sessionsResult = await _focusRepository.getSessions(
        startDate: startDate, endDate: endDate);
    if (sessionsResult.isLeft) return Either.left(sessionsResult.left!);
    final sessions = sessionsResult.right!;

    final entriesResult = await _journalRepository.getEntries(
        startDate: startDate, endDate: endDate);
    if (entriesResult.isLeft) return Either.left(entriesResult.left!);
    final entries = entriesResult.right!;

    final habitHeatmapResult = await _habitHeatmapFor(habits, heatmapWeeks);
    if (habitHeatmapResult.isLeft) return Either.left(habitHeatmapResult.left!);

    final focusHeatmapResult =
        await _focusRepository.getFocusHeatmap(weeks: heatmapWeeks);
    if (focusHeatmapResult.isLeft) return Either.left(focusHeatmapResult.left!);

    final moodCorrelationResult =
        await _correlationFor(habits, entries, 'mood', startDate, endDate);
    if (moodCorrelationResult.isLeft) {
      return Either.left(moodCorrelationResult.left!);
    }

    final energyCorrelationResult =
        await _correlationFor(habits, entries, 'energy', startDate, endDate);
    if (energyCorrelationResult.isLeft) {
      return Either.left(energyCorrelationResult.left!);
    }

    final categoryCompletions = <String, int>{};
    final categoryStreaks = <String, int>{};
    for (final habit in habits) {
      categoryCompletions[habit.category] =
          (categoryCompletions[habit.category] ?? 0) + habit.totalCompletions;
      categoryStreaks[habit.category] =
          (categoryStreaks[habit.category] ?? 0) + habit.currentStreak;
    }

    final focusByCategory = <String, int>{};
    var totalFocusMinutes = 0;
    for (final FocusSession session in sessions) {
      totalFocusMinutes += session.totalWorkMinutes;
      final category = session.projectName ?? 'Uncategorized';
      focusByCategory[category] =
          (focusByCategory[category] ?? 0) + session.totalWorkMinutes;
    }

    var moodSum = 0;
    var moodCount = 0;
    var energySum = 0;
    var energyCount = 0;
    for (final entry in entries) {
      if (entry.moodRating != null) {
        moodSum += entry.moodRating!;
        moodCount++;
      }
      if (entry.energyRating != null) {
        energySum += entry.energyRating!;
        energyCount++;
      }
    }

    return Either.right(AnalyticsData(
      startDate: startDate,
      endDate: endDate,
      habitHeatmap: habitHeatmapResult.right!,
      categoryCompletions: categoryCompletions,
      categoryStreaks: categoryStreaks,
      totalFocusMinutes: totalFocusMinutes,
      focusByCategory: focusByCategory,
      focusHeatmap: focusHeatmapResult.right!,
      journalEntriesCount: entries.length,
      moodDistribution: _distribution(
          entries.map((e) => e.moodRating), AppConstants.moodLevels),
      energyDistribution: _distribution(
          entries.map((e) => e.energyRating), AppConstants.energyLevels),
      avgMood: moodCount == 0 ? 0 : moodSum / moodCount,
      avgEnergy: energyCount == 0 ? 0 : energySum / energyCount,
      moodHabitCorrelation: moodCorrelationResult.right!,
      energyHabitCorrelation: energyCorrelationResult.right!,
    ));
  }

  @override
  Future<Result<Map<DateTime, int>>> getHabitHeatmap({int weeks = 12}) async {
    final habitsResult =
        await _habitRepository.getAllHabits(includeArchived: true);
    if (habitsResult.isLeft) return Either.left(habitsResult.left!);
    return _habitHeatmapFor(habitsResult.right!, weeks);
  }

  Future<Result<Map<DateTime, int>>> _habitHeatmapFor(
      List<Habit> habits, int weeks) async {
    final merged = <DateTime, int>{};
    for (final habit in habits) {
      final result =
          await _habitRepository.getCompletionHeatmap(habit.id, weeks: weeks);
      if (result.isLeft) return Either.left(result.left!);
      result.right!.forEach((day, count) {
        merged[day] = (merged[day] ?? 0) + count;
      });
    }
    return Either.right(merged);
  }

  @override
  Future<Result<Map<String, int>>> getHabitCompletionsByCategory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final habitsResult =
        await _habitRepository.getAllHabits(includeArchived: true);
    if (habitsResult.isLeft) return Either.left(habitsResult.left!);

    final byCategory = <String, int>{};
    for (final habit in habitsResult.right!) {
      if (startDate == null && endDate == null) {
        byCategory[habit.category] =
            (byCategory[habit.category] ?? 0) + habit.totalCompletions;
        continue;
      }
      final completionsResult = await _habitRepository.getCompletionsForHabit(
          habit.id,
          startDate: startDate,
          endDate: endDate);
      if (completionsResult.isLeft) return Either.left(completionsResult.left!);
      final count =
          completionsResult.right!.fold<int>(0, (sum, c) => sum + c.count);
      byCategory[habit.category] = (byCategory[habit.category] ?? 0) + count;
    }
    return Either.right(byCategory);
  }

  @override
  Future<Result<Map<String, int>>> getHabitStreaksByCategory() async {
    final habitsResult =
        await _habitRepository.getAllHabits(includeArchived: true);
    if (habitsResult.isLeft) return Either.left(habitsResult.left!);

    final byCategory = <String, int>{};
    for (final habit in habitsResult.right!) {
      byCategory[habit.category] =
          (byCategory[habit.category] ?? 0) + habit.currentStreak;
    }
    return Either.right(byCategory);
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
    return Either.right(_average(result.right!.map((e) => e.moodRating)));
  }

  @override
  Future<Result<double>> getAverageEnergy(
      {DateTime? startDate, DateTime? endDate}) async {
    final result = await _journalRepository.getEntries(
        startDate: startDate, endDate: endDate);
    if (result.isLeft) return Either.left(result.left!);
    return Either.right(_average(result.right!.map((e) => e.energyRating)));
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
        habitsResult.right!, entriesResult.right!, type, startDate, endDate);
  }

  /// Pairs each journal rating with the share of habits that were completed on
  /// that day, producing one point per rated day.
  Future<Result<List<CorrelationPoint>>> _correlationFor(
    List<Habit> habits,
    List<JournalEntry> entries,
    String type,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    final completionsByDay = <DateTime, Set<String>>{};
    for (final habit in habits) {
      final result = await _habitRepository.getCompletionsForHabit(habit.id,
          startDate: startDate, endDate: endDate);
      if (result.isLeft) return Either.left(result.left!);
      for (final completion in result.right!) {
        completionsByDay
            .putIfAbsent(completion.completedAt.startOfDay, () => <String>{})
            .add(completion.habitId);
      }
    }

    final points = <CorrelationPoint>[];
    for (final entry in entries) {
      final rating = type == 'mood' ? entry.moodRating : entry.energyRating;
      if (rating == null) continue;

      final date = entry.date.startOfDay;
      final dueHabits = habits.where((h) => h.isDueOnDate(date)).toList();
      if (dueHabits.isEmpty) continue;

      final completed = completionsByDay[date] ?? const <String>{};
      final completedDue =
          dueHabits.where((h) => completed.contains(h.id)).length;

      points.add(CorrelationPoint(
        x: completedDue / dueHabits.length * 100,
        y: rating.toDouble(),
        label: date.formatRelative(),
      ));
    }

    points.sort((a, b) => a.x.compareTo(b.x));
    return Either.right(points);
  }

  static double _average(Iterable<int?> ratings) {
    var sum = 0;
    var count = 0;
    for (final rating in ratings) {
      if (rating == null) continue;
      sum += rating;
      count++;
    }
    return count == 0 ? 0 : sum / count;
  }

  static Map<String, int> _distribution(
      Iterable<int?> ratings, List<String> labels) {
    final distribution = <String, int>{};
    for (final rating in ratings) {
      if (rating == null || rating < 1 || rating > labels.length) continue;
      final label = labels[rating - 1];
      distribution[label] = (distribution[label] ?? 0) + 1;
    }
    return distribution;
  }
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepositoryImpl(
    ref.watch(habitRepositoryProvider),
    ref.watch(focusRepositoryProvider),
    ref.watch(journalRepositoryProvider),
  );
});
