import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/analytics_controller.dart';
import '../widgets/heatmap_widget.dart';
import '../widgets/analytics_charts.dart';
import '../../domain/analytics_data.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/text_styles.dart';
import '../../../../app/widgets/app_empty_state.dart';
import '../../../../app/widgets/pill_chip.dart';
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
      extendBodyBehindAppBar: true,
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
                icon: state.error != null
                    ? Icons.error_outline
                    : Icons.insights_rounded,
                title: state.error != null
                    ? 'Could not load insights'
                    : 'No data yet',
                message: state.error != null
                    ? state.error!
                    : 'Complete a habit, run a focus session or write a '
                        'journal entry and your ${state.selectedPeriod.toLowerCase()} '
                        'insights will show up here.',
                accent: state.error != null
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            )
          else
            SliverPadding(
              // Bottom padding clears the floating nav bar; the charts are the
              // last thing on the page and were ending up underneath it.
              padding: const EdgeInsets.fromLTRB(
                AppSpacingTokens.gutter,
                AppSpacingTokens.gutter,
                AppSpacingTokens.gutter,
                96,
              ),
              sliver: SliverList.separated(
                itemCount: sectionCount,
                separatorBuilder: (_, __) => const SizedBox(height: 24),
                itemBuilder: (context, index) => _buildSection(context, index,
                    state, controller)
                    // Staggered entrance. The cap matters: with the long
                    // analytics list a linear delay would leave the eighth
                    // section waiting over a second to appear, which reads as a
                    // stall rather than as choreography.
                    .animate()
                        .fadeIn(
                          delay: Duration(
                            milliseconds: (index * 55).clamp(0, 400),
                          ),
                          duration: AppAnimationTokens.slow,
                        )
                        .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
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
          // Translucent, so the hero panel scrolling up behind it stays
          // readable through the bar instead of being chopped off at a hard
          // line. The blur is what keeps the title legible over moving content.
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleSpacing: AppSpacingTokens.lg,
          title: ShaderMask(
            shaderCallback: AppGradients.action(colorScheme.primary)
                .createShader,
            child: Text(
              'Analytics',
              style: AppTextStyles.headlineSmall.copyWith(color: Colors.white),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            // Offset for the app bar, which now floats over this panel because
            // of `extendBodyBehindAppBar`.
            padding: const EdgeInsets.fromLTRB(
              AppSpacingTokens.gutter,
              kToolbarHeight + AppSpacingTokens.sm,
              AppSpacingTokens.gutter,
              0,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadiusTokens.xl),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppGradients.journalHeader(colorScheme),
                    borderRadius: BorderRadius.circular(AppRadiusTokens.xl),
                    border: Border.all(color: AppColors.hairline(colorScheme)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 26,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(AppSpacingTokens.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          _buildStatCard(
                              'Focus', '${state.totalFocusMinutes} min',
                              Icons.timer_outlined, AppColors.neonCyan),
                          const SizedBox(width: AppSpacingTokens.sm),
                          _buildStatCard(
                              'Entries', '${state.journalEntriesCount}',
                              Icons.book_outlined, AppColors.radiantViolet),
                          const SizedBox(width: AppSpacingTokens.sm),
                          _buildStatCard(
                            'Mood',
                            state.avgMood > 0
                                ? state.avgMood.toStringAsFixed(1)
                                : '—',
                            Icons.sentiment_satisfied_outlined,
                            AppColors.coralOrange,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacingTokens.md),
                      _buildPeriodSelector(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);

    // A translucent well rather than a full card: three of these sit shoulder to
    // shoulder, and a border on each one made the row read as three boxes
    // instead of one strip of numbers.
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacingTokens.sm + 2,
          vertical: AppSpacingTokens.sm + 4,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadiusTokens.md),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            // `FittedBox` rather than a smaller font: the value is the thing
            // being read, and 1,240 min must not wrap or ellipsize on a narrow
            // phone while "—" sits next to it taking the same space.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context) {
    final state = ref.watch(analyticsControllerProvider);

    return Align(
      alignment: Alignment.centerLeft,
      child: GlassPillRow(
        pills: [
          for (final period in AppConstants.analyticsPeriods)
            GlassPill(
              label: period,
              selected: state.selectedPeriod == period,
              accent: AppColors.neonCyan,
              onTap: () => ref
                  .read(analyticsControllerProvider.notifier)
                  .setPeriod(period),
            ),
        ],
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
    // One shared ramp for both charts: previously these two hand-picked
    // colours that overlapped (three of five were identical between them)
    // and read as pure material red/green rather than app colours.
    return DistributionPieChart(
      data: state.moodDistribution,
      colors: AppColors.ratingScale(Theme.of(context).colorScheme),
      label: 'Mood Distribution',
    );
  }

  Widget _buildEnergyDistributionSection(
      BuildContext context, AnalyticsState state) {
    return DistributionPieChart(
      data: state.energyDistribution,
      colors: AppColors.ratingScale(Theme.of(context).colorScheme),
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
