import 'package:freezed_annotation/freezed_annotation.dart';

part 'analytics_data.freezed.dart';

/// Aggregated analytics payload for a requested period.
///
/// Produced by [AnalyticsRepository] and mapped into the flat
/// `AnalyticsState` used by the presentation layer.
@freezed
abstract class AnalyticsData with _$AnalyticsData {
  const factory AnalyticsData({
    required DateTime startDate,
    required DateTime endDate,
    @Default({}) Map<DateTime, int> habitHeatmap,
    @Default({}) Map<String, int> categoryCompletions,
    @Default({}) Map<String, int> categoryStreaks,
    @Default(0) int totalFocusMinutes,
    @Default({}) Map<String, int> focusByCategory,
    @Default({}) Map<DateTime, int> focusHeatmap,
    @Default(0) int journalEntriesCount,
    @Default({}) Map<String, int> moodDistribution,
    @Default({}) Map<String, int> energyDistribution,
    @Default(0.0) double avgMood,
    @Default(0.0) double avgEnergy,
    @Default([]) List<CorrelationPoint> moodHabitCorrelation,
    @Default([]) List<CorrelationPoint> energyHabitCorrelation,
  }) = _AnalyticsData;

  const AnalyticsData._();

  bool get isEmpty =>
      habitHeatmap.isEmpty &&
      categoryCompletions.isEmpty &&
      totalFocusMinutes == 0 &&
      focusByCategory.isEmpty &&
      journalEntriesCount == 0;
}

/// A single observation used by the correlation scatter charts.
///
/// [x] is the habit completion percentage for the day (0-100) and [y] is the
/// reported mood or energy rating (1-5).
@freezed
abstract class CorrelationPoint with _$CorrelationPoint {
  const factory CorrelationPoint({
    required double x,
    required double y,
    required String label,
  }) = _CorrelationPoint;
}
