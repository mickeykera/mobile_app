import 'package:ascend/features/analytics/presentation/widgets/analytics_charts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression cover for a Y-axis that rendered as `2, 2, 1`.
///
/// The axis headroom used to be a bare `maxValue * 1.2`, so for a maximum of 2
/// the top tick sat at 2.4. Labels are produced with `toInt()`, so that tick
/// printed "2" a second time directly above the real 2.
void main() {
  Future<List<String>> axisLabels(
      WidgetTester tester, Map<String, int> data) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CategoryBarChart(
            data: data,
            color: Colors.indigo,
            label: 'Completions by Category',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // The left axis returns bare `Text` widgets while the bottom axis wraps
    // category names in `SideTitleWidget`, so collect every `Text` under the
    // chart and keep only the numeric ones that make up the Y axis.
    return tester
        .widgetList<Text>(find.descendant(
          of: find.byType(BarChart),
          matching: find.byType(Text),
        ))
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => RegExp(r'^\d+%?$').hasMatch(s))
        .toList();
  }

  testWidgets('labels are unique for a max of 2', (tester) async {
    final labels = await axisLabels(tester, {'Mind': 2});
    expect(labels.where((l) => l == '2').length, 1, reason: 'got $labels');
    expect(labels, isNot(contains('2, 2')));
  });

  testWidgets('labels are unique for a max of 1', (tester) async {
    final labels = await axisLabels(tester, {'Mind': 1});
    expect(labels.where((l) => l == '1').length, 1, reason: 'got $labels');
  });

  testWidgets('labels are unique for a max of 4', (tester) async {
    final labels = await axisLabels(tester, {'Mind': 4});
    expect(labels.toSet().length, labels.length, reason: 'got $labels');
  });

  testWidgets('labels are unique for a larger max', (tester) async {
    final labels = await axisLabels(tester, {'Mind': 37});
    expect(labels.toSet().length, labels.length, reason: 'got $labels');
  });

  testWidgets('single entry still renders', (tester) async {
    final labels = await axisLabels(tester, {'Mind': 5});
    expect(labels, isNotEmpty);
  });
}
