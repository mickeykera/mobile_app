import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/features/habits/domain/habit_scheduling.dart';

void main() {
  // 2025-06-11 is a Wednesday.
  final wednesday = DateTime(2025, 6, 11, 14, 30);

  group('scheduling options', () {
    test('todayAt anchors to the morning hour', () {
      expect(todayAt(wednesday), DateTime(2025, 6, 11, 9));
    });

    test('tomorrowAfter is the next day at the morning hour', () {
      expect(tomorrowAfter(wednesday), DateTime(2025, 6, 12, 9));
    });

    test('thisWeekend is the coming Saturday', () {
      expect(thisWeekend(wednesday), DateTime(2025, 6, 14, 9));
    });

    test('thisWeekend on a Saturday plans the following weekend', () {
      expect(thisWeekend(DateTime(2025, 6, 14, 14)), DateTime(2025, 6, 21, 9));
    });

    test('nextWeek is the coming Monday', () {
      expect(nextWeek(wednesday), DateTime(2025, 6, 16, 9));
    });

    test('nextWeek on a Monday plans the following Monday', () {
      expect(nextWeek(DateTime(2025, 6, 16, 10)), DateTime(2025, 6, 23, 9));
    });

    test('laterToday is three hours on', () {
      expect(laterToday(wednesday), DateTime(2025, 6, 11, 17, 30));
    });

    test('laterToday is clamped inside the current day', () {
      expect(laterToday(DateTime(2025, 6, 11, 23, 0)),
          DateTime(2025, 6, 11, 23, 59));
    });
  });

  group('date boundaries', () {
    test('tomorrowAfter rolls over the end of a month', () {
      expect(tomorrowAfter(DateTime(2025, 1, 31, 22)), DateTime(2025, 2, 1, 9));
    });

    test('tomorrowAfter rolls over the end of a year', () {
      expect(tomorrowAfter(DateTime(2025, 12, 31, 23, 59)),
          DateTime(2026, 1, 1, 9));
    });

    test('laterToday at 23:59 stays on the same day', () {
      expect(laterToday(DateTime(2025, 6, 11, 23, 59)),
          DateTime(2025, 6, 11, 23, 59));
    });

    test('thisWeekend from a Sunday plans the coming Saturday', () {
      // Sunday 2025-06-15 sits between weekends; the next Saturday is the 21st.
      expect(thisWeekend(DateTime(2025, 6, 15, 10)), DateTime(2025, 6, 21, 9));
    });

    test('nextWeek from a Sunday is the very next day', () {
      expect(nextWeek(DateTime(2025, 6, 15, 10)), DateTime(2025, 6, 16, 9));
    });

    test('nextWeek rolls over the year boundary', () {
      // Wednesday 2025-12-31 -> Monday 2026-01-05.
      expect(nextWeek(DateTime(2025, 12, 31, 10)), DateTime(2026, 1, 5, 9));
    });
  });
}
