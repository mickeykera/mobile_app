import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/repositories/analytics_repository_impl.dart';
import '../../domain/analytics_data.dart';
import '../../domain/analytics_repository.dart';

part 'analytics_controller.freezed.dart';

@freezed
abstract class AnalyticsState with _$AnalyticsState {
  const factory AnalyticsState({
    @Default(AppConstants.analyticsPeriodMonth) String selectedPeriod,
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
    @Default(false) bool isLoading,
    String? error,
  }) = _AnalyticsState;
}

class AnalyticsController extends StateNotifier<AnalyticsState> {
  final AnalyticsRepository _repository;

  AnalyticsController(this._repository) : super(const AnalyticsState()) {
    loadAnalytics(AppConstants.analyticsPeriodMonth);
  }

  Future<void> loadAnalytics(String period) async {
    state =
        state.copyWith(isLoading: true, error: null, selectedPeriod: period);

    final now = DateTime.now();
    final result = await _repository.getAnalyticsData(
      startDate: _startDateFor(period, now),
      endDate: now,
      heatmapWeeks: period == AppConstants.analyticsPeriodWeek ? 1 : 4,
    );

    if (result.isLeft) {
      state = state.copyWith(isLoading: false, error: result.left!.userMessage);
      return;
    }

    final data = result.right!;
    state = state.copyWith(
      isLoading: false,
      habitHeatmap: data.habitHeatmap,
      categoryCompletions: data.categoryCompletions,
      categoryStreaks: data.categoryStreaks,
      totalFocusMinutes: data.totalFocusMinutes,
      focusByCategory: data.focusByCategory,
      focusHeatmap: data.focusHeatmap,
      journalEntriesCount: data.journalEntriesCount,
      moodDistribution: data.moodDistribution,
      energyDistribution: data.energyDistribution,
      avgMood: data.avgMood,
      avgEnergy: data.avgEnergy,
      moodHabitCorrelation: data.moodHabitCorrelation,
      energyHabitCorrelation: data.energyHabitCorrelation,
    );
  }

  /// Resets to [period] and reloads every metric.
  void setPeriod(String period) {
    if (period == state.selectedPeriod) return;
    loadAnalytics(period);
  }

  Future<void> refresh() => loadAnalytics(state.selectedPeriod);

  static DateTime _startDateFor(String period, DateTime now) {
    switch (period) {
      case AppConstants.analyticsPeriodWeek:
        return now.subtract(const Duration(days: 7));
      case AppConstants.analyticsPeriodQuarter:
        return now.subtract(const Duration(days: 90));
      case AppConstants.analyticsPeriodYear:
        return now.subtract(const Duration(days: 365));
      case AppConstants.analyticsPeriodMonth:
      default:
        return now.subtract(const Duration(days: 30));
    }
  }
}

final analyticsControllerProvider =
    StateNotifierProvider<AnalyticsController, AnalyticsState>((ref) {
  return AnalyticsController(ref.watch(analyticsRepositoryProvider));
});

final analyticsStateProvider = Provider<AnalyticsState>((ref) {
  return ref.watch(analyticsControllerProvider);
});
