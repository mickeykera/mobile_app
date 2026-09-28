import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/analytics_controller.dart';
import '../widgets/heatmap_widget.dart';
import '../widgets/analytics_charts.dart';
import '../../domain/analytics_data.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/app_empty_state.dart';
import '../../../../core/constants/app_constants.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsControllerProvider.notifier).loadAnalytics('Week');
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyticsControllerProvider);
    final controller = ref.read(analyticsControllerProvider.notifier);
    final sectionCount = _getSectionCount(state);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          if (state.isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (sectionCount == 0)
            // No charts were rendered at all before, so a brand new account saw
            // a blank screen under the header. Say what is missing instead.
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.insights_rounded,
                title: 'No data yet',
                message:
                    'Complete a habit, run a focus session or write a journal '
                    'entry and your ${state.selectedPeriod.toLowerCase()} '
                    'insights will show up here.',
                accent: Theme.of(context).colorScheme.primary,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.separated(
                itemCount: sectionCount,
                separatorBuilder: (_, __) => const SizedBox(height: 24),
                itemBuilder: (context, index) =>
                    _buildSection(context, index, state, controller),
              ),
            ),
        ],
      ),
    );
  }

  /// Header for the Analytics tab.
  ///
  /// Uses a plain sliver box plus a separate pinned title bar. Anchoring the
  /// stat cards to the bottom of a `FlexibleSpaceBar` while its `title` claimed
  /// the same edge left the title rendering *below* the cards.
  Widget _buildSliverAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(analyticsControllerProvider);

    return SliverMainAxisGroup(
      slivers: [
        SliverAppBar(
          pinned: true,
          titleSpacing: AppSpacingTokens.lg,
          title: Text(
            'Analytics',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.secondaryContainer,
                  colorScheme.tertiaryContainer,
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadiusTokens.xxl),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacingTokens.lg,
              AppSpacingTokens.md,
              AppSpacingTokens.lg,
              AppSpacingTokens.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildStatCard('Focus', '${state.totalFocusMinutes} min',
                        Icons.timer_outlined, colorScheme.primary),
                    const SizedBox(width: AppSpacingTokens.sm),
                    _buildStatCard('Entries', '${state.journalEntriesCount}',
                        Icons.book_outlined, colorScheme.tertiary),
                    const SizedBox(width: AppSpacingTokens.sm),
                    _buildStatCard(
                        'Mood',
                        state.avgMood > 0
                            ? state.avgMood.toStringAsFixed(1)
                            : '—',
                        Icons.sentiment_satisfied_outlined,
                        colorScheme.secondary),
                  ],
                ),
                const SizedBox(height: AppSpacingTokens.md),
                _buildPeriodSelector(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const Spacer(),
                Text(value,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(analyticsControllerProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AppConstants.analyticsPeriods.map((period) {
          final isSelected = state.selectedPeriod == period;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(period),
              selected: isSelected,
              onSelected: (_) => ref
                  .read(analyticsControllerProvider.notifier)
                  .setPeriod(period),
              selectedColor: theme.colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          );
        }).toList(),
      ),
    );
  }

  int _getSectionCount(AnalyticsState state) {
    int count = 0;
    if (state.habitHeatmap.isNotEmpty) count++;
    if (state.categoryCompletions.isNotEmpty) count++;
    if (state.focusHeatmap.isNotEmpty) count++;
    if (state.focusByCategory.isNotEmpty) count++;
    if (state.moodDistribution.isNotEmpty) count++;
    if (state.energyDistribution.isNotEmpty) count++;
    if (state.moodHabitCorrelation.isNotEmpty) count++;
    if (state.energyHabitCorrelation.isNotEmpty) count++;
    return count;
  }

  Widget _buildSection(BuildContext context, int index, AnalyticsState state,
      AnalyticsController controller) {
    int sectionIndex = 0;

    if (state.habitHeatmap.isNotEmpty) {
      if (sectionIndex == index) {
        return _buildHabitHeatmapSection(context, state);
      }
      sectionIndex++;
    }

    if (state.categoryCompletions.isNotEmpty) {
      if (sectionIndex == index) {
        return _buildCategorySection(context, state);
      }
      sectionIndex++;
    }

    if (state.focusHeatmap.isNotEmpty) {
      if (sectionIndex == index) {
        return _buildFocusHeatmapSection(context, state);
      }
      sectionIndex++;
    }

    if (state.focusByCategory.isNotEmpty) {
      if (sectionIndex == index) {
        return _buildFocusCategorySection(context, state);
      }
      sectionIndex++;
    }

    if (state.moodDistribution.isNotEmpty) {
      if (sectionIndex == index) {
        return _buildMoodDistributionSection(context, state);
      }
      sectionIndex++;
    }

    if (state.energyDistribution.isNotEmpty) {
      if (sectionIndex == index) {
        return _buildEnergyDistributionSection(context, state);
      }
      sectionIndex++;
    }

    if (state.moodHabitCorrelation.isNotEmpty) {
      if (sectionIndex == index) {
        return _buildCorrelationSection(context, state, 'Mood');
      }
      sectionIndex++;
    }

    if (state.energyHabitCorrelation.isNotEmpty) {
      if (sectionIndex == index) {
        return _buildCorrelationSection(context, state, 'Energy');
      }
      sectionIndex++;
    }

    return const SizedBox.shrink();
  }

  Widget _buildHabitHeatmapSection(BuildContext context, AnalyticsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeatmapWidget(
          data: state.habitHeatmap,
          weeks: state.selectedPeriod == 'Week' ? 1 : 4,
          color: Theme.of(context).colorScheme.primary,
          label: 'Habit Completions',
        ),
      ],
    );
  }

  Widget _buildCategorySection(BuildContext context, AnalyticsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CategoryBarChart(
          data: state.categoryCompletions,
          color: Theme.of(context).colorScheme.primary,
          label: 'Completions by Category',
        ),
        const SizedBox(height: 24),
        CategoryBarChart(
          data: state.categoryStreaks,
          color: Theme.of(context).colorScheme.tertiary,
          label: 'Current Streaks by Category',
        ),
      ],
    );
  }

  Widget _buildFocusHeatmapSection(BuildContext context, AnalyticsState state) {
    return HeatmapWidget(
      data: state.focusHeatmap,
      weeks: state.selectedPeriod == 'Week' ? 1 : 4,
      color: Theme.of(context).colorScheme.tertiary,
      label: 'Focus Minutes',
    );
  }

  Widget _buildFocusCategorySection(
      BuildContext context, AnalyticsState state) {
    return CategoryBarChart(
      data: state.focusByCategory,
      color: Theme.of(context).colorScheme.tertiary,
      label: 'Focus Time by Project',
    );
  }

  Widget _buildMoodDistributionSection(
      BuildContext context, AnalyticsState state) {
    return DistributionPieChart(
      data: state.moodDistribution,
      colors: const [
        Colors.red,
        Colors.orange,
        Colors.grey,
        Colors.lightGreen,
        Colors.green
      ],
      label: 'Mood Distribution',
    );
  }

  Widget _buildEnergyDistributionSection(
      BuildContext context, AnalyticsState state) {
    return DistributionPieChart(
      data: state.energyDistribution,
      colors: const [
        Colors.red,
        Colors.orange,
        Colors.grey,
        Colors.lightBlue,
        Colors.blue
      ],
      label: 'Energy Distribution',
    );
  }

  Widget _buildCorrelationSection(
      BuildContext context, AnalyticsState state, String type) {
    final List<CorrelationPoint> points = type == 'Mood'
        ? state.moodHabitCorrelation
        : state.energyHabitCorrelation;
    final color = type == 'Mood'
        ? Theme.of(context).colorScheme.secondary
        : Theme.of(context).colorScheme.tertiary;

    return CorrelationScatterChart(
      points: points,
      xLabel: 'Habit Completion %',
      yLabel: type,
      color: color,
    );
  }
}
