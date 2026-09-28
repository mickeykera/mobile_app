import 'package:flutter_test/flutter_test.dart';
import 'package:ascend/features/analytics/presentation/widgets/heatmap_widget.dart';

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
}
