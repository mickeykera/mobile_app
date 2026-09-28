import '../../../../core/errors/failures.dart';
import 'analytics_data.dart';

/// Read-only aggregation surface across the habit, focus and journal features.
abstract class AnalyticsRepository {
  /// Everything the analytics screen needs for a single period, in one call.
  Future<Result<AnalyticsData>> getAnalyticsData({
    required DateTime startDate,
    required DateTime endDate,
    int heatmapWeeks = 4,
  });

  Future<Result<Map<DateTime, int>>> getHabitHeatmap({int weeks = 12});
  Future<Result<Map<String, int>>> getHabitCompletionsByCategory({
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<Result<Map<String, int>>> getHabitStreaksByCategory();
  Future<Result<int>> getTotalFocusMinutes(
      {DateTime? startDate, DateTime? endDate});
  Future<Result<Map<String, int>>> getFocusByCategory(
      {DateTime? startDate, DateTime? endDate});
  Future<Result<Map<DateTime, int>>> getFocusHeatmap({int weeks = 12});
  Future<Result<int>> getJournalEntriesCount(
      {DateTime? startDate, DateTime? endDate});
  Future<Result<Map<String, int>>> getMoodDistribution(
      {DateTime? startDate, DateTime? endDate});
  Future<Result<Map<String, int>>> getEnergyDistribution(
      {DateTime? startDate, DateTime? endDate});
  Future<Result<double>> getAverageMood(
      {DateTime? startDate, DateTime? endDate});
  Future<Result<double>> getAverageEnergy(
      {DateTime? startDate, DateTime? endDate});
  Future<Result<List<CorrelationPoint>>> getMoodHabitCorrelation({
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<Result<List<CorrelationPoint>>> getEnergyHabitCorrelation({
    DateTime? startDate,
    DateTime? endDate,
  });
}
