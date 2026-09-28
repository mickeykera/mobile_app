import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

import '../theme/app_theme.dart';

/// How a single day in a [WeekStrip] should be drawn.
enum WeekDayState {
  /// Every habit due that day was completed.
  complete,

  /// Some, but not all, of the habits due that day were completed.
  partial,

  /// The day is over and nothing was completed.
  missed,

  /// The day has not happened yet.
  upcoming,
}

/// A Monday-to-Sunday row of day markers.
///
/// This is the pattern Streaks, Trophy and Fabulous all use: a glanceable
/// "chain" of the last seven days that makes a broken streak feel visible
/// without opening a calendar.
class WeekStrip extends StatelessWidget {
  /// Seven entries, Monday first.
  final List<WeekDayState> days;
  final int? todayIndex;
  final Color accent;
  final double cellSize;

  const WeekStrip({
    super.key,
    required this.days,
    required this.accent,
    this.todayIndex,
    this.cellSize = 34,
  });

  static const List<String> _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: List<Widget>.generate(days.length.clamp(0, 7), (index) {
        final isToday = todayIndex == index;
        final label = _labels[index % 7];

        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isToday
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.7),
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacingTokens.xs),
              _DayCell(
                state: days[index],
                isToday: isToday,
                accent: accent,
                size: cellSize,
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _DayCell extends StatelessWidget {
  final WeekDayState state;
  final bool isToday;
  final Color accent;
  final double size;

  const _DayCell({
    required this.state,
    required this.isToday,
    required this.accent,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35);

    final Color fill;
    final Color border;
    final double borderWidth;

    switch (state) {
      case WeekDayState.complete:
        fill = accent;
        border = accent;
        borderWidth = 2;
      case WeekDayState.partial:
        fill = accent.withValues(alpha: 0.28);
        border = accent;
        borderWidth = 2;
      case WeekDayState.missed:
        fill = Colors.transparent;
        border = outline;
        borderWidth = 1.5;
      case WeekDayState.upcoming:
        fill = Colors.transparent;
        border = outline.withValues(alpha: 0.5);
        borderWidth = 1.5;
    }

    return AnimatedContainer(
      duration: AppAnimationTokens.medium,
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadiusTokens.md),
        border: Border.all(color: border, width: borderWidth),
      ),
      child: state == WeekDayState.complete
          ? Icon(
              Icons.check_rounded,
              size: size * 0.55,
              // Same reasoning as the habit card tick: a fixed white tick is
              // too light on the mint and amber accents.
              color: AppColors.onColorFor(fill, Theme.of(context).colorScheme),
            )
          : state == WeekDayState.partial
              ? Center(
                  child: Container(
                    width: size * 0.22,
                    height: size * 0.22,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null,
    );
  }
}
