import 'package:ascend/features/analytics/presentation/widgets/heatmap_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('heatmapStartDate', () {
    // 2026-09-28 is a Monday, so `startOfWeek` is the day itself.
    final monday = DateTime(2026, 9, 28);

    test('a single-week grid starts on the current week, not the previous one',
        () {
      expect(heatmapStartDate(monday, 1), DateTime(2026, 9, 28));
    });

    test("today's data is inside the drawn window", () {
      // Regression: the old formula stepped back `weeks * 7` days and *then*
      // snapped to a week start, which shifted the grid one week into the past
      // and hid the current week entirely.
      final start = heatmapStartDate(monday, 1);
      final end = start.add(const Duration(days: 6));
      expect(monday.isAfter(start.subtract(const Duration(days: 1))), isTrue);
      expect(end.isBefore(monday.add(const Duration(days: 8))), isTrue);
    });

    test('multi-week grids still end on the current week', () {
      expect(heatmapStartDate(monday, 4), DateTime(2026, 9, 7));
      // 11 full weeks before Mon 2026-09-28.
      expect(heatmapStartDate(monday, 12), DateTime(2026, 7, 13));
    });

    test('always starts on a Monday', () {
      for (var offset = 0; offset < 14; offset++) {
        final day = monday.add(Duration(days: offset));
        for (final weeks in [1, 4, 12]) {
          expect(heatmapStartDate(day, weeks).weekday, DateTime.monday,
              reason: 'weeks=$weeks now=$day');
        }
      }
    });

    test('ignores the time component of now', () {
      final withTime = DateTime(2026, 9, 28, 23, 59, 59);
      expect(heatmapStartDate(withTime, 1), DateTime(2026, 9, 28));
    });
  });

  group('heatmapMaxValue', () {
    final start = DateTime(2026, 9, 28);

    test('ignores data outside the visible window', () {
      // A big value well before the window must not set the legend.
      final data = {DateTime(2026, 1, 1): 40};
      expect(heatmapMaxValue(data, start, 1), 0);
    });

    test('picks up values inside the visible window', () {
      final data = {start: 4, start.add(const Duration(days: 1)): 2};
      expect(heatmapMaxValue(data, start, 1), 4);
    });

    test('returns 0 for an empty map', () {
      expect(heatmapMaxValue({}, start, 4), 0);
    });
  });

  group('HeatmapWidget', () {
    // The reported bug: the legend read "Max: 4" while every cell was empty,
    // because the drawn window ended a week before the data.
    testWidgets("renders today's value in a single-week grid", (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HeatmapWidget(
              data: {today: 4},
              weeks: 1,
              color: Colors.purple,
              label: 'Habit Completions',
            ),
          ),
        ),
      ));

      // The legend reports the max...
      expect(find.text('Max: 4'), findsOneWidget);
      // ...and the value is actually drawn in a cell.
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('a value outside the window is not drawn', (tester) async {
      final now = DateTime.now();
      final old = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 30));

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HeatmapWidget(
              data: {old: 7},
              weeks: 1,
              color: Colors.purple,
              label: 'Habit Completions',
            ),
          ),
        ),
      ));

      // Outside the window, so neither the cell nor a misleading legend shows.
      expect(find.text('7'), findsNothing);
      expect(find.text('Max: 7'), findsNothing);
      expect(find.text('Max: 1'), findsOneWidget);
    });

    testWidgets('renders without overflow at several week counts',
        (tester) async {
      for (final weeks in [1, 4, 12]) {
        await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HeatmapWidget(
                data: {DateTime.now(): 3},
                weeks: weeks,
                color: Colors.teal,
                label: 'Focus Minutes',
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'weeks=$weeks');
      }
    });
  });
}
