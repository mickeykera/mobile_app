import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
// `intl` exports its own `TextDirection`, which would shadow the one that
// `TextPainter` needs inside `_CorrelationPainter`.
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/extensions/date_extensions.dart';
import '../../domain/analytics_data.dart';

class CategoryBarChart extends StatelessWidget {
  final Map<String, int> data;
  final Color color;
  final String label;

  const CategoryBarChart({
    super.key,
    required this.data,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = entries.isEmpty ? 1.0 : entries.first.value.toDouble();
    final interval = _axisInterval(maxValue);
    // Round the headroom up to a whole tick. A bare `maxValue * 1.2` lands on a
    // fractional tick (2 -> 2.4), and since the label is produced with
    // `toInt()` that tick printed the same "2" as the tick below it, so the
    // axis read `2, 2, 1` instead of `2, 1`.
    final axisMaxY = _axisMax(maxValue, interval);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: axisMaxY,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => theme.colorScheme.inverseSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final entry = entries[group.x.toInt()];
                    return BarTooltipItem(
                      '${entry.key}\n${entry.value}',
                      theme.textTheme.bodySmall!
                          .copyWith(color: theme.colorScheme.onInverseSurface),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= entries.length) {
                        return const SizedBox.shrink();
                      }
                      final entry = entries[value.toInt()];
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 8,
                        child: Text(
                          entry.key.substring(0, 1),
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: interval,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _axisInterval(maxValue),
                getDrawingHorizontalLine: (value) => FlLine(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: entries.asMap().entries.map((entry) {
                final index = entry.key;
                final value = entry.value.value.toDouble();
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: value,
                      color: color,
                      width: 20,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxValue,
                        color: color.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: entries
              .map((entry) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 6),
                      Text('${entry.key}: ${entry.value}',
                          style: theme.textTheme.bodySmall),
                    ],
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _CorrelationPainter extends CustomPainter {
  final List<CorrelationPoint> points;
  final Color color;
  final double maxX;
  final double maxY;

  /// Supplied by the caller: a `CustomPainter` has no `BuildContext`, so the
  /// axes and labels used to be pinned to a fixed `Colors.grey` that did not
  /// match the theme in either brightness.
  final Color axisColor;
  final Color labelColor;

  _CorrelationPainter({
    required this.points,
    required this.color,
    required this.maxX,
    required this.maxY,
    required this.axisColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final axisPaint = Paint()
      ..color = axisColor.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    // Draw axes
    const originX = 40.0;
    final originY = size.height - 40.0;
    final chartWidth = size.width - 60.0;
    final chartHeight = size.height - 60.0;

    // Draw axes
    canvas.drawLine(
      Offset(originX, originY),
      Offset(originX + chartWidth, originY),
      axisPaint,
    );
    canvas.drawLine(
      Offset(originX, originY),
      Offset(originX, originY - chartHeight),
      axisPaint,
    );

    // Draw X axis labels
    for (int i = 0; i <= 5; i++) {
      final x = originX + (chartWidth * i / 5);
      canvas.drawLine(
        Offset(x, originY),
        Offset(x, originY + 5),
        axisPaint,
      );
      final value = (20 * i).toInt();
      final textPainter = TextPainter(
        text: TextSpan(
            text: '${value.toInt()}%',
            style: TextStyle(color: labelColor, fontSize: 10)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, originY + 8));
    }

    // Draw Y axis labels
    for (int i = 0; i <= 5; i++) {
      final y = originY - (chartHeight * i / 5);
      canvas.drawLine(
        Offset(originX - 5, y),
        Offset(originX, y),
        axisPaint,
      );
      final value = (5 - i).toDouble();
      final textPainter = TextPainter(
        text: TextSpan(
            text: value.toInt().toString(),
            style: TextStyle(color: labelColor, fontSize: 10)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas,
          Offset(originX - textPainter.width - 8, y - textPainter.height / 2));
    }

    // Draw points
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final point in points) {
      final x = originX + (point.x / maxX) * chartWidth;
      final y = originY - (point.y / maxY) * chartHeight;
      canvas.drawCircle(Offset(x, y), 6, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class CorrelationScatterChart extends StatelessWidget {
  final List<CorrelationPoint> points;
  final String xLabel;
  final String yLabel;
  final Color color;

  const CorrelationScatterChart({
    super.key,
    required this.points,
    required this.xLabel,
    required this.yLabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (points.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.scatter_plot_outlined,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No correlation data available',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$yLabel vs $xLabel',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.2)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$yLabel vs $xLabel',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Expanded(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _CorrelationPainter(
                      points: points,
                      color: color,
                      maxX: 100.0,
                      maxY: 5.5,
                      axisColor: theme.colorScheme.outlineVariant,
                      labelColor: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Each dot represents a day. X = Habit completion %, Y = $yLabel (1-5)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DistributionPieChart extends StatelessWidget {
  final Map<String, int> data;
  final List<Color> colors;
  final String label;

  const DistributionPieChart({
    super.key,
    required this.data,
    required this.colors,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = data.values.fold(0, (a, b) => a + b);

    if (total == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No $label data',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final sections = data.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value.value;
      final percentage = (value / total * 100).toStringAsFixed(1);
      return PieChartSectionData(
        color: colors[index % colors.length],
        value: value.toDouble(),
        title: '$percentage%',
        radius: 60,
        // The slice fills come from the shared rating ramp, which includes
        // lighter tones, so a fixed white label was unreadable on some slices.
        titleStyle: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.onColorFor(
            colors[index % colors.length],
            theme.colorScheme,
          ),
          fontWeight: FontWeight.w600,
        ),
        badgeWidget: value > 0
            ? Text(entry.key.toString(), style: theme.textTheme.labelSmall)
            : null,
        badgePositionPercentageOffset: 1.3,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {},
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: data.entries.toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final value = entry.value.value;
                    final percentage = (value / total * 100).toStringAsFixed(1);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                  color: colors[index % colors.length],
                                  borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(entry.key.toString(),
                                  style: theme.textTheme.bodySmall)),
                          Text('$percentage% ($value)',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TrendLineChart extends StatelessWidget {
  final Map<DateTime, int> data;
  final Color color;
  final String label;

  const TrendLineChart({
    super.key,
    required this.data,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (sortedEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart_outlined,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No $label data',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final spots = sortedEntries.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value.toDouble());
    }).toList();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (spots.length - 1).toDouble(),
              minY: minY > 0 ? 0 : minY * 0.9,
              maxY: maxY * 1.1,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => theme.colorScheme.inverseSurface,
                  getTooltipItems: (spots) => spots.map((spot) {
                    final date = sortedEntries[spot.spotIndex.toInt()].key;
                    return LineTooltipItem(
                      '${date.formatRelative()}\n$label: ${spot.y.toInt()}',
                      theme.textTheme.bodySmall!
                          .copyWith(color: theme.colorScheme.onInverseSurface),
                    );
                  }).toList(),
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= sortedEntries.length) {
                        return const SizedBox.shrink();
                      }
                      if (value.toInt() % (sortedEntries.length / 5).ceil() !=
                          0) {
                        return const SizedBox.shrink();
                      }
                      final date = sortedEntries[value.toInt()].key;
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 8,
                        child: Text(
                          DateFormat('MM/dd').format(date),
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: (maxY - minY) / 4,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                      radius: 4,
                      color: color,
                      strokeWidth: 2,
                      strokeColor: theme.colorScheme.surface,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Whole-number axis step for a value axis spanning `0..maxValue`.
///
/// A fractional step combined with `value.toInt()` produced repeated labels such
/// as `0, 1, 1, 2, 2` whenever the maximum was not a multiple of four.
double _axisInterval(double maxValue) {
  if (maxValue <= 0) return 1;
  final step = (maxValue / 4).ceil();
  return step < 1 ? 1.0 : step.toDouble();
}

/// Upper bound for the axis: `maxValue` plus ~20% headroom, rounded up to a
/// whole multiple of [interval] so every rendered tick is a distinct label.
double _axisMax(double maxValue, double interval) {
  final step = interval <= 0 ? 1.0 : interval;
  final padded = maxValue <= 0 ? step : maxValue * 1.2;
  final ticks = (padded / step).ceil();
  return (ticks < 1 ? 1 : ticks) * step;
}
