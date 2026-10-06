import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/text_styles.dart';
import '../../../../app/widgets/app_empty_state.dart';
import '../../../../app/widgets/glass_card.dart';
import '../../../../app/widgets/glow_button.dart';
import '../../../../app/widgets/pressable.dart';
import '../../../../app/widgets/progress_ring.dart';
import '../../../../app/widgets/week_strip.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../habits/domain/entities/habit.dart';
import '../../../habits/presentation/controllers/habit_controller.dart';
import '../../../habits/presentation/providers/habit_providers.dart';
import '../../../habits/presentation/widgets/quick_habit_form.dart';
import '../../../progress/domain/services/progress_service.dart';
import '../../../tasks/presentation/providers/task_providers.dart';
import '../../../recurring/presentation/providers/recurring_providers.dart';
import '../../domain/today_summary.dart';

/// The landing screen: what is due today, and how today is going.
///
/// Deliberately read-only over the three features that already exist - habits,
/// focus and journal - rather than the tasks/projects/goals the wider roadmap
/// describes. Those do not exist yet, and a Today view that waits on them is a
/// Today view that ships never.
///
/// The one thing it writes is habit completion, and it goes through
/// [HabitController] so that ticking a habit here and ticking it on the Habits
/// screen are the same code path.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueHabitsProvider);
    final completions = ref.watch(todaysCompletionsProvider);
    final progress = ref.watch(todaysProgressProvider);
    final streak = ref.watch(bestStreakProvider);
    final focusMinutes = ref.watch(todayFocusMinutesProvider);
    final focusActive = ref.watch(hasActiveFocusProvider);
    final weekStates = ref.watch(weekDayStatesProvider);
    final weekCount = ref.watch(weekCompletionCountProvider);

    // A migrated habit's completion is a Task occurrence row with no `habitId`,
    // so keying on `habitId` alone left every such habit in "Still to do" on a
    // day its own row - one line further down, which ticks through
    // `taskController` - says it was done. Resolved through the same ownership
    // map the week strip, the header streak and Analytics use.
    final completedIds = <String>{};
    final habitIdByTaskId =
        ProgressService.habitIdByTaskId(ref.watch(habitsProvider));
    for (final completion in completions) {
      if (completion.isHabitCompletion) {
        final habitId = completion.ownerId;
        if (habitId != null) completedIds.add(habitId);
      } else if (completion.itemType == 'task') {
        final habitId = habitIdByTaskId[completion.itemId];
        if (habitId != null) completedIds.add(habitId);
      }
    }
    final pending = due.where((habit) => !completedIds.contains(habit.id));
    final done = due.where((habit) => completedIds.contains(habit.id));

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          _Header(
            greeting: ref.watch(greetingProvider),
            streak: streak,
          ),
          _ProgressSection(
            completed: done.length,
            total: due.length,
            hasAnyHabits: ref.watch(habitsProvider).isNotEmpty,
            progress: progress,
            focusMinutes: focusMinutes,
          ),
          // Slivers are spread directly into the list rather than grouped
          // under a wrapper: a sliver cannot be a child of a Column, so a
          // grouped section header would have to be a box widget and the
          // viewport would reject it.
          if (due.isEmpty) const _TodayEmptyState(),
          if (pending.isNotEmpty) ...[
            _SectionHeader(label: 'Still to do', count: pending.length),
            _HabitList(
              habits: pending.toList(),
              completedIds: completedIds,
            ),
          ],
          if (done.isNotEmpty) ...[
            _SectionHeader(label: 'Done today', count: done.length),
            _HabitList(
              habits: done.toList(),
              completedIds: completedIds,
              dimmed: true,
            ),
          ],
          _FocusCard(minutes: focusMinutes, isActive: focusActive),
          _WeekCard(states: weekStates, completions: weekCount),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      floatingActionButton: GlowButton(
        label: 'New Habit',
        icon: LucideIcons.plus,
        accent: AppColors.accentPrimary,
        height: 52,
        onPressed: () => showQuickHabitFormSheet(
          context,
          ref.read(habitControllerProvider.notifier),
        ),
      ),
    );
  }
}

/// Greeting and date, on the app's standard header gradient.
class _Header extends StatelessWidget {
  final String greeting;
  final int streak;

  const _Header({required this.greeting, required this.streak});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = AppClock.now();

    // The animation is on the child, not on the SliverToBoxAdapter:
    // `.animate()` wraps its target in a FadeTransition, which is not a
    // sliver and so cannot be a direct child of the scroll view's viewport.
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          AppSpacingTokens.lg,
          MediaQuery.paddingOf(context).top + AppSpacingTokens.lg,
          AppSpacingTokens.lg,
          AppSpacingTokens.xl,
        ),
        decoration: BoxDecoration(
          gradient: AppGradients.header(scheme),
          border: Border(
            bottom: BorderSide(color: AppColors.hairline(scheme)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greeting.toUpperCase(),
                style: AppTextStyles.overline
                    .copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacingTokens.xs),
            Text(now.dayOfWeek,
                style: AppTextStyles.displaySmall
                    .copyWith(color: scheme.onSurface)),
            Text(
              '${now.monthName} ${now.day}',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: scheme.onSurfaceVariant),
            ),
            if (streak > 0) ...[
              const SizedBox(height: AppSpacingTokens.md),
              _StreakBadge(streak: streak),
            ],
          ],
        ),
      ).animate().fadeIn(duration: AppAnimationTokens.slow),
    );
  }
}

/// "🔥 12 day streak"
///
/// Uses the flame icon rather than a text emoji: the app's icon set is Lucide
/// throughout, and a colour emoji would be the one element on the screen drawn
/// by a different font at a different optical size.
class _StreakBadge extends StatelessWidget {
  final int streak;

  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppColors.accent(
        scheme, AppColors.accentWarmDeep, AppColors.accentWarmDark);

    return Pressable(
      onTap: () => context.go('/analytics'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.flame, size: 16, color: accent),
          const SizedBox(width: AppSpacingTokens.xs),
          Text(
            '$streak day${streak == 1 ? '' : 's'} in a row',
            style: AppTextStyles.labelMedium.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}

/// The day's headline numbers: a completion ring plus two counters.
class _ProgressSection extends StatelessWidget {
  final int completed;
  final int total;

  /// Whether the user has any habits at all, as opposed to having habits that
  /// happen not to be due today.
  ///
  /// The two need different words. "Nothing due today" on an empty account is
  /// wrong - there is no today to have nothing on - and it is also what the
  /// empty state below already says, so the screen showed the same sentence
  /// twice.
  final bool hasAnyHabits;
  final double progress;
  final int focusMinutes;

  const _ProgressSection({
    required this.completed,
    required this.total,
    required this.hasAnyHabits,
    required this.progress,
    required this.focusMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppColors.accent(
        scheme, AppColors.accentPrimaryDeep, AppColors.accentPrimaryDark);

    // A day with nothing due is not a zero: the ring would read as failure. It
    // is left undrawn and the copy says what is actually true.
    final hasHabits = total > 0;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacingTokens.lg),
        child: GlassCard(
          child: Row(
            children: [
              if (hasHabits)
                ProgressRing(
                  value: progress,
                  size: 84,
                  color: accent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$completed/$total',
                          style: AppTextStyles.metricMedium
                              .copyWith(color: scheme.onSurface)),
                    ],
                  ),
                )
              else
                // Not `onColorFor`: that picks the colour to place *on* an
                // accent, so it returned white on the light card and the app
                // background colour on the dark one - the icon rendered at
                // 1.07:1 and 1.00:1 against its own surface, i.e. invisible.
                Icon(LucideIcons.circleCheck, size: 40, color: accent),
              const SizedBox(width: AppSpacingTokens.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasHabits
                          ? (completed == total
                              ? 'All done for today'
                              : '$completed of $total habits done')
                          : (hasAnyHabits
                              ? 'Nothing due today'
                              : 'No habits yet'),
                      style: AppTextStyles.titleMedium
                          .copyWith(color: scheme.onSurface),
                    ),
                    const SizedBox(height: AppSpacingTokens.xs),
                    Text(
                      _focusLine(),
                      style: AppTextStyles.bodySmall
                          .copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: AppAnimationTokens.stagger),
      ),
    );
  }

  String _focusLine() {
    if (focusMinutes <= 0) return 'No focus time logged yet';
    final hours = focusMinutes ~/ 60;
    final minutes = focusMinutes % 60;
    if (hours == 0) return '${minutes}m focused today';
    return '${hours}h ${minutes}m focused today';
  }
}

/// Small caps divider above each block, with an optional count.
class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;

  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacingTokens.lg, 0, AppSpacingTokens.lg, AppSpacingTokens.sm),
        child: Row(
          children: [
            Text(label.toUpperCase(),
                style: AppTextStyles.overline
                    .copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(width: AppSpacingTokens.sm),
            Expanded(
                child: Divider(color: AppColors.hairline(scheme), height: 1)),
            const SizedBox(width: AppSpacingTokens.sm),
            Text('$count',
                style: AppTextStyles.labelSmall
                    .copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Shown when no habit is due.
///
/// Distinct from "you finished everything": an empty account and a clear day
/// are different situations and get different copy, because only one of them
/// needs the user to go and do something.
class _TodayEmptyState extends ConsumerWidget {
  const _TodayEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacingTokens.lg),
        child: AppEmptyState(
          icon: LucideIcons.sun,
          title: 'Start your first habit',
          message: 'Habits you add will show up here on the days they are due.',
          actionLabel: 'Add a habit',
          onAction: () => showQuickHabitFormSheet(
            context,
            ref.read(habitControllerProvider.notifier),
          ),
        ),
      ),
    );
  }
}

/// Tappable habit rows.
///
/// The row is the tap target rather than a checkbox on the right, because a
/// row-sized target is the difference between completing a habit one-handed and
/// aiming at a 24dp circle.
class _HabitList extends ConsumerWidget {
  final List<Habit> habits;
  final Set<String> completedIds;
  final bool dimmed;

  const _HabitList({
    required this.habits,
    required this.completedIds,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacingTokens.lg),
        child: Column(
          children: [
            for (final habit in habits)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacingTokens.sm),
                child: _HabitRow(
                  habit: habit,
                  done: completedIds.contains(habit.id),
                  dimmed: dimmed,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HabitRow extends ConsumerWidget {
  final Habit habit;
  final bool done;
  final bool dimmed;

  const _HabitRow({
    required this.habit,
    required this.done,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final habitController = ref.read(habitControllerProvider.notifier);
    final accent = habit.categoryColorFor(Theme.of(context).brightness);

    // A completed row drops to a fraction of its opacity rather than losing its
    // accent entirely, so the day's shape stays readable while scrolling.
    final contentOpacity = dimmed ? 0.45 : 1.0;

    final isMigrated = habit.taskId != null;
    final completionAsync = isMigrated
        ? ref.watch(taskOccurrenceTodayProvider(habit.taskId!))
        : const AsyncData(false);
    final isCompletedToday = completionAsync.value ?? false;

    return Pressable(
      onTap: () {
        final isMigrated = habit.taskId != null;
        if (isMigrated) {
          final taskController = ref.read(taskControllerProvider.notifier);
          final isDone =
              ref.read(taskOccurrenceTodayProvider(habit.taskId!)).value ??
                  false;
          if (isDone) {
            taskController.deleteOccurrence(habit.taskId!,
                date: AppClock.now());
          } else {
            taskController.recordOccurrence(habit.taskId!,
                date: AppClock.now());
          }
        } else {
          if (done) {
            habitController.uncompleteHabit(habit.id);
          } else {
            habitController.completeHabit(habit.id);
          }
        }
      },
      child: Opacity(
        opacity: contentOpacity,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacingTokens.md,
            vertical: AppSpacingTokens.md,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadiusTokens.sm),
                ),
                child: Icon(
                  isCompletedToday
                      ? LucideIcons.circleCheck
                      : habit.categoryIcon,
                  size: 18,
                  color: accent,
                ),
              ),
              const SizedBox(width: AppSpacingTokens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: scheme.onSurface,
                        decoration: isCompletedToday
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (habit.timeOfDay.isNotEmpty)
                      Text(
                        habit.timeOfDay,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              if (habit.targetCount > 1)
                Text(
                  '${habit.targetCount}',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Focus minutes today, and a way into the timer.
class _FocusCard extends ConsumerWidget {
  final int minutes;
  final bool isActive;

  const _FocusCard({required this.minutes, required this.isActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppColors.accent(
        scheme, AppColors.accentLiveDeep, AppColors.accentLiveDark);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacingTokens.lg, AppSpacingTokens.md, AppSpacingTokens.lg, 0),
        child: GlassCard(
          onTap: () => context.go('/focus'),
          child: Row(
            children: [
              Icon(
                isActive ? LucideIcons.timer : LucideIcons.batteryCharging,
                size: 20,
                color: accent,
              ),
              const SizedBox(width: AppSpacingTokens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive ? 'Session in progress' : 'Focus',
                      style: AppTextStyles.titleSmall
                          .copyWith(color: scheme.onSurface),
                    ),
                    Text(
                      isActive
                          ? 'Tap to go back to your timer'
                          : minutes > 0
                              ? '$minutes minutes logged today'
                              : 'No sessions yet today',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.arrowRight,
                  size: 16, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// The week strip, with the week's total alongside it.
class _WeekCard extends StatelessWidget {
  final List<WeekDayState> states;
  final int completions;

  const _WeekCard({required this.states, required this.completions});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppColors.accent(
        scheme, AppColors.accentPrimaryDeep, AppColors.accentPrimaryDark);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacingTokens.lg, AppSpacingTokens.md, AppSpacingTokens.lg, 0),
        child: GlassCard(
          onTap: () => context.go('/analytics'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('This week',
                      style: AppTextStyles.titleSmall
                          .copyWith(color: scheme.onSurface)),
                  const Spacer(),
                  Text(
                    '$completions done',
                    style: AppTextStyles.labelMedium.copyWith(color: accent),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacingTokens.md),
              WeekStrip(
                days: states,
                accent: accent,
                todayIndex: AppClock.now().weekday - 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
