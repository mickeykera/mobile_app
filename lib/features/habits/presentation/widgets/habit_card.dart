import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../domain/entities/habit.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/mini_week_strip.dart';

class HabitCard extends StatelessWidget {
  final Habit habit;
  final bool isCompleted;
  final VoidCallback onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onUncomplete;
  final VoidCallback? onLongPress;

  const HabitCard({
    super.key,
    required this.habit,
    required this.isCompleted,
    required this.onTap,
    this.onComplete,
    this.onUncomplete,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = habit.categoryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppRadiusTokens.lg),
        child: Container(
          decoration: BoxDecoration(
            color: isCompleted
                ? categoryColor.withValues(alpha: 0.1)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadiusTokens.lg),
            border: Border.all(
              color: isCompleted
                  ? categoryColor.withValues(alpha: 0.3)
                  : theme.colorScheme.outline.withValues(alpha: 0.2),
              width: isCompleted ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(AppSpacingTokens.md),
          child: Row(
            children: [
              _buildCompletionButton(context),
              const SizedBox(width: AppSpacingTokens.md),
              Expanded(child: _buildHabitInfo(context)),
              const SizedBox(width: AppSpacingTokens.md),
              _buildStreakBadge(context),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0),
    );
  }

  Widget _buildCompletionButton(BuildContext context) {
    final categoryColor = habit.categoryColor;

    return GestureDetector(
      onTap: () async {
        if (isCompleted) {
          onUncomplete?.call();
        } else {
          onComplete?.call();
        }
      },
      // An explicit scale rather than a `.animate(target: ...)` on the child:
      // the target-0 form collapsed the 48dp target to nothing, leaving the
      // habit impossible to tick.
      child: AnimatedScale(
        scale: isCompleted ? 1.0 : 0.94,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? categoryColor : Colors.transparent,
            border: Border.all(
              color: isCompleted
                  ? categoryColor
                  : categoryColor.withValues(alpha: 0.5),
              width: 2.5,
            ),
            boxShadow: isCompleted
                ? [
                    BoxShadow(
                      color: categoryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: isCompleted
              ? const Icon(Icons.check, color: Colors.white, size: 24)
              : Icon(Icons.add,
                  color: categoryColor.withValues(alpha: 0.7), size: 24),
        ),
      ),
    );
  }

  Widget _buildHabitInfo(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = habit.categoryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadiusTokens.full),
              ),
              child: Text(
                habit.category,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: categoryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (habit.targetDuration.inMinutes > 0) ...[
              const SizedBox(width: AppSpacingTokens.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadiusTokens.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${habit.targetDuration.inMinutes} min',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacingTokens.xs),
        Text(
          habit.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isCompleted
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurface,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (habit.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            habit.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: AppSpacingTokens.xs),
        // The seven-square chain gives a per-habit read on consistency that the
        // streak number alone cannot: it shows *where* in the week it broke.
        MiniWeekStrip(
          days: deriveWeekStates(
            lastCompletedAt: habit.lastCompletedAt,
            currentStreak: habit.currentStreak,
          ),
          accent: categoryColor,
        ),
        const SizedBox(height: AppSpacingTokens.xs),
        Row(
          children: [
            Icon(
              _getTimeOfDayIcon(habit.timeOfDay),
              size: 14,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
            Text(
              habit.timeOfDay,
              style: theme.textTheme.labelSmall?.copyWith(
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: AppSpacingTokens.sm),
            Icon(
              _getFrequencyIcon(habit.frequency),
              size: 14,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
            Text(
              _getFrequencyLabel(habit.frequency, habit.customWeekdays),
              style: theme.textTheme.labelSmall?.copyWith(
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStreakBadge(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = habit.categoryColor;

    if (habit.currentStreak == 0 && habit.longestStreak == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: categoryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadiusTokens.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 16,
                color: categoryColor,
              ),
              const SizedBox(width: 4),
              Text(
                '${habit.currentStreak}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: categoryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (habit.longestStreak > habit.currentStreak) ...[
          const SizedBox(height: 4),
          Text(
            'Best: ${habit.longestStreak}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }

  IconData _getTimeOfDayIcon(String timeOfDay) {
    switch (timeOfDay) {
      case 'Morning':
        return Icons.wb_sunny_outlined;
      case 'Afternoon':
        return Icons.wb_sunny_outlined;
      case 'Evening':
        return Icons.nights_stay_outlined;
      default:
        return Icons.access_time_outlined;
    }
  }

  IconData _getFrequencyIcon(String frequency) {
    switch (frequency) {
      case 'Daily':
        return Icons.repeat_outlined;
      case 'Weekdays':
        return Icons.calendar_today_outlined;
      case 'Weekends':
        return Icons.weekend_outlined;
      case 'Custom':
        return Icons.tune_outlined;
      default:
        return Icons.repeat_outlined;
    }
  }

  String _getFrequencyLabel(String frequency, List<int> customWeekdays) {
    switch (frequency) {
      case 'Daily':
        return 'Daily';
      case 'Weekdays':
        return 'Mon-Fri';
      case 'Weekends':
        return 'Sat-Sun';
      case 'Custom':
        if (customWeekdays.isEmpty) return 'Custom';
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return customWeekdays.map((d) => days[d - 1]).join(', ');
      default:
        return frequency;
    }
  }
}
