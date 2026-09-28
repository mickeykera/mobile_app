import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/date_extensions.dart';

/// First day drawn in a [weeks]-wide heatmap grid.
///
/// The grid always *ends* with the current week and walks backwards, so the
/// most recent day is always on screen. Deriving the start by stepping back
/// `weeks * 7` days and then snapping to a week boundary instead shifts the
/// whole window one week into the past, hiding today's data.
DateTime heatmapStartDate(DateTime now, int weeks) {
  final today = DateTime(now.year, now.month, now.day);
  final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
  return startOfWeek.subtract(Duration(days: (weeks - 1) * 7));
}

/// Largest value inside the window the heatmap actually draws, so the legend
/// can never advertise a number that no visible cell shows.
int heatmapMaxValue(Map<DateTime, int> data, DateTime startDate, int weeks) {
  var maxValue = 0;
  for (var weekIndex = 0; weekIndex < weeks; weekIndex++) {
    for (var weekday = 0; weekday < 7; weekday++) {
      final value =
          data[startDate.add(Duration(days: weekIndex * 7 + weekday))] ?? 0;
      if (value > maxValue) maxValue = value;
    }
  }
  return maxValue;
}

class HeatmapWidget extends ConsumerWidget {
  final Map<DateTime, int> data;
  final int weeks;
  final Color color;
  final String label;

  const HeatmapWidget({
    super.key,
    required this.data,
    this.weeks = 12,
    required this.color,
    required this.label,
  });

  /// Width reserved for the Mon..Sun row labels.
  static const double _gutter = 40;

  /// Space between heatmap cells.
  static const double _gap = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = now.startOfDay;
    // Anchor the grid on the *current* week and walk backwards, instead of
    // walking back `weeks * 7` days first and then snapping to a week start.
    // The old form always ended one week in the past, so today's completions
    // were fetched but never drawn: the legend reported "Max: 4" above an
    // entirely empty grid whenever the data came from the current week.
    final startDate = heatmapStartDate(now, weeks);

    // Scale the legend to the cells that are actually on screen rather than the
    // whole payload, so "Max:" can never describe a value no cell shows.
    final visibleMax = heatmapMaxValue(data, startDate, weeks);
    // Keep the division below safe for a fully empty range.
    final maxValue = visibleMax == 0 ? 1 : visibleMax;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              'Max: $maxValue',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            // There are exactly `weeks` columns and one label gutter. The old
            // `(weeks + 1)` divisor made a single-week heatmap draw cells around
            // 140dp tall, which pushed the grid off the screen entirely.
            final available =
                constraints.maxWidth - _gutter - (weeks - 1) * _gap;
            final cellSize = (available / weeks).clamp(10.0, 30.0);
            // Each cell carries a trailing `_gap`, including the last one, so the
            // width has to count `weeks` gaps rather than `weeks - 1`.
            final totalWidth = _gutter + weeks * (cellSize + _gap);

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalWidth,
                child: Column(
                  children: [
                    _buildWeekLabels(context, cellSize, startDate, weeks),
                    const SizedBox(height: 4),
                    ...List.generate(
                      7,
                      (weekday) => Padding(
                        padding: const EdgeInsets.only(bottom: _gap),
                        child: _buildWeekRow(context, weekday, cellSize,
                            startDate, maxValue, today),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWeekLabels(
      BuildContext context, double cellSize, DateTime startDate, int weeks) {
    final theme = Theme.of(context);
    // One label per column: every column is a week starting at `startDate`,
    // and the weekday is already shown as the row label on the left.
    return Row(
      children: [
        SizedBox(
            width: _gutter, child: Text('', style: theme.textTheme.labelSmall)),
        ...List.generate(weeks, (weekIndex) {
          final weekStart = startDate.add(Duration(days: weekIndex * 7));
          return Padding(
            padding: const EdgeInsets.only(right: _gap),
            child: SizedBox(
              width: cellSize,
              child: Center(
                child: Text(
                  '${weekStart.day}/${weekStart.month}',
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 8,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWeekRow(BuildContext context, int weekday, double cellSize,
      DateTime startDate, int maxValue, DateTime today) {
    final theme = Theme.of(context);
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayLabel = days[weekday];

    return Row(
      children: [
        SizedBox(
          width: _gutter,
          child: Text(
            dayLabel,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.right,
          ),
        ),
        ...List.generate(weeks, (weekIndex) {
          final date = startDate.add(Duration(days: weekIndex * 7 + weekday));
          final value = data[date.startOfDay] ?? 0;
          final intensity = maxValue > 0 ? value / maxValue : 0.0;
          // The current week is now part of the grid, so days after today
          // render too. Keep them neutral rather than letting an empty
          // "future" cell read as a day that was missed.
          final isFuture = date.startOfDay.isAfter(today);

          return Padding(
            padding: const EdgeInsets.only(right: _gap),
            child: Container(
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                color: isFuture
                    ? Colors.transparent
                    : intensity > 0
                        ? color.withValues(alpha: 0.15 + intensity * 0.85)
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: isFuture
                      ? Colors.transparent
                      : intensity > 0
                          ? color.withValues(alpha: 0.3)
                          : theme.colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: value > 0 && !isFuture
                  ? Center(
                      child: Text(
                        value.toString(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: intensity > 0.5 ? Colors.white : color,
                          fontWeight: FontWeight.w600,
                          fontSize: 8,
                        ),
                      ),
                    )
                  : null,
            ),
          );
        }),
      ],
    );
  }
}

class MiniHeatmapWidget extends StatelessWidget {
  final Map<DateTime, int> data;
  final int weeks;
  final Color color;

  const MiniHeatmapWidget({
    super.key,
    required this.data,
    this.weeks = 12,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    // Same anchoring as [HeatmapWidget]: the last column is the current week,
    // so the most recent day is actually drawn.
    final startDate = heatmapStartDate(now, weeks);
    final maxValue =
        data.values.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);
    const cellSize = 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ...['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) => SizedBox(
                  width: cellSize + 2,
                  child: Center(
                      child: Text(d,
                          style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 8,
                              color: theme.colorScheme.onSurfaceVariant))),
                )),
          ],
        ),
        const SizedBox(height: 2),
        ...List.generate(
            7,
            (weekday) => Row(
                  children: List.generate(weeks, (weekIndex) {
                    final date =
                        startDate.add(Duration(days: weekIndex * 7 + weekday));
                    final value = data[date.startOfDay] ?? 0;
                    final intensity = maxValue > 0 ? value / maxValue : 0.0;

                    return Container(
                      width: cellSize,
                      height: cellSize,
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: intensity > 0
                            ? color.withValues(alpha: 0.2 + intensity * 0.8)
                            : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                )),
      ],
    );
  }
}
