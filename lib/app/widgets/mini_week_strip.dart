import 'package:flutter/material.dart';

import 'week_strip.dart';

/// Derives the Monday-first [WeekDayState] list for the week containing
/// [reference] from the completion data actually held on a [Habit].
///
/// The habit record keeps `lastCompletedAt` and a `currentStreak` rather than a
/// per-day history, so the chain is reconstructed as "the last `currentStreak`
/// days up to `lastCompletedAt` were completed". That is the same chain the
/// streak badge already advertises, so the strip and the number can never
/// disagree.
List<WeekDayState> deriveWeekStates({
  required DateTime? lastCompletedAt,
  required int currentStreak,
  DateTime? reference,
}) {
  // `reference` is the day the user is looking at, which is "today" for the
  // live screen but an arbitrary past date in tests and date navigation.
  final today = reference ?? DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  // Monday-first index of the current week.
  final monday = todayDate.subtract(Duration(days: todayDate.weekday - 1));

  return List<WeekDayState>.generate(7, (index) {
    final day = monday.add(Duration(days: index));
    if (day.isAfter(todayDate)) return WeekDayState.upcoming;

    final last = lastCompletedAt;
    if (last == null) {
      // Nothing kept yet. Today is still in play, so it is partial rather than
      // a day that was already missed.
      return day == todayDate ? WeekDayState.partial : WeekDayState.missed;
    }

    // Walk back from the last completion for as many days as the streak runs.
    final lastDate = DateTime(last.year, last.month, last.day);
    final withinStreak = currentStreak > 0 &&
        !day.isAfter(lastDate) &&
        lastDate.difference(day).inDays < currentStreak;

    if (withinStreak) return WeekDayState.complete;

    // Today is still in play, so a partial today reads as partial rather than
    // as a day that was already missed.
    if (day == todayDate) return WeekDayState.partial;

    return WeekDayState.missed;
  });
}

/// A compact row of seven squares shown inside a habit row.
///
/// Each square is one day of the current week: filled means kept, outlined
/// means missed, hollow means still to come. It is the small "chain" that makes
/// consistency visible without leaving the list.
class MiniWeekStrip extends StatelessWidget {
  final List<WeekDayState> days;
  final Color accent;
  final double size;

  const MiniWeekStrip({
    super.key,
    required this.days,
    required this.accent,
    this.size = 10,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: days.take(7).map((state) {
        final Color fill;
        switch (state) {
          case WeekDayState.complete:
            fill = accent;
          case WeekDayState.partial:
            fill = accent.withValues(alpha: 0.35);
          case WeekDayState.missed:
            fill = Colors.transparent;
          case WeekDayState.upcoming:
            fill = empty;
        }

        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(3),
              border: state == WeekDayState.missed
                  ? Border.all(color: empty, width: 1)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}
