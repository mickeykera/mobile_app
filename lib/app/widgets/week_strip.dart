import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import 'progress_ring.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

/// Fraction of the ring each [WeekDayState] fills, when the caller does not
/// supply real numbers.
double _stateFraction(WeekDayState state) {
  switch (state) {
    case WeekDayState.complete:
      return 1.0;
    case WeekDayState.partial:
      return 0.5;
    case WeekDayState.missed:
    case WeekDayState.upcoming:
      return 0.0;
  }
}

/// A floating week chain: seven completion rings in a glass pill.
///
/// This is the pattern Streaks, Trophy, Forest and Fabulous all use - a
/// glanceable "chain" of the last seven days that makes a broken streak visible
/// without opening a calendar. It is drawn as a single floating pill rather
/// than seven loose squares so it reads as one object that can be tapped, and
/// so the rings sit on glass instead of on the page.
class WeekStrip extends StatelessWidget {
  /// Seven entries, Monday first.
  final List<WeekDayState> days;
  final int? todayIndex;
  final Color accent;

  /// Diameter of each ring. The pill's height follows from this.
  final double cellSize;

  /// Per-day fill fractions in `0..1`, in the same order as [days]. Lets a
  /// caller show real counts (3 of 5 habits) instead of the coarse state. Falls
  /// back to the value implied by [WeekDayState].
  final List<double>? progress;

  const WeekStrip({
    super.key,
    required this.days,
    required this.accent,
    this.todayIndex,
    this.cellSize = 38,
    this.progress,
  });

  static const List<String> _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final count = days.length.clamp(0, 7);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacingTokens.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardFill(
          Theme.of(context).colorScheme,
          opacity: 0.55,
        ),
        borderRadius: BorderRadius.circular(AppRadiusTokens.full),
        border: Border.all(
          color: AppColors.hairline(Theme.of(context).colorScheme),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List<Widget>.generate(count, (index) {
          final isToday = todayIndex == index;

          return _DayCell(
            state: days[index],
            fraction: progress != null && index < progress!.length
                ? progress![index].clamp(0.0, 1.0)
                : _stateFraction(days[index]),
            isToday: isToday,
            accent: accent,
            size: cellSize,
            label: _labels[index % 7],
          );
        }),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final WeekDayState state;
  final double fraction;
  final bool isToday;
  final Color accent;
  final double size;
  final String label;

  const _DayCell({
    required this.state,
    required this.fraction,
    required this.isToday,
    required this.accent,
    required this.size,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isFuture = state == WeekDayState.upcoming;

    // A missed day is a real absence, so it keeps a faint ring. An upcoming day
    // is not an absence at all and gets no ring - otherwise a Monday morning
    // reads as seven failures.
    final ringColor = switch (state) {
      WeekDayState.complete => accent,
      WeekDayState.partial => accent,
      WeekDayState.missed => scheme.onSurfaceVariant.withValues(alpha: 0.4),
      WeekDayState.upcoming => scheme.onSurfaceVariant.withValues(alpha: 0.18),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            fontSize: 10,
            color: isToday
                ? scheme.onSurface
                : scheme.onSurfaceVariant.withValues(alpha: 0.65),
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: AppAnimationTokens.medium,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Today is called out with a halo rather than a heavier border, so
            // "today" is distinguishable from "complete" at a glance.
            boxShadow: isToday
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: isFuture
              ? SizedBox(
                  width: size - 6,
                  height: size - 6,
                )
              : DayRing(
                  value: fraction,
                  color: ringColor,
                  size: size - 6,
                  strokeWidth: 3,
                  child: state == WeekDayState.complete
                      ? Icon(
                          LucideIcons.check,
                          size: (size - 6) * 0.52,
                          color: AppColors.onColorFor(ringColor, scheme),
                        )
                      : state == WeekDayState.partial
                          ? Container(
                              width: (size - 6) * 0.24,
                              height: (size - 6) * 0.24,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                ),
        ),
      ],
    );
  }
}
