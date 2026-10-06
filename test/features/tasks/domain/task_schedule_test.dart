import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';

/// The single definition of "is this work item due on this day".
///
/// These cases are the reference contract the [Habit] entity now delegates to,
/// so they cover recurrence, the today-forward snooze/reschedule overrides, and
/// the finite one-off schedule that the upcoming Task entity will use.
void main() {
  // 2025-06-09 is a Monday.
  final monday = DateTime(2025, 6, 9);
  final tuesday = DateTime(2025, 6, 10);
  final wednesday = DateTime(2025, 6, 11);
  final saturday = DateTime(2025, 6, 14);
  final sunday = DateTime(2025, 6, 15);

  // Wednesday morning: the pinned "now" for every override case.
  final now = DateTime(2025, 6, 11, 9);

  Recurring recurring(
    String frequency, {
    List<int> customWeekdays = const [],
    DateTime? dueAt,
    DateTime? snoozedUntil,
  }) =>
      Recurring(
        RecurrenceRule.fromFrequency(frequency, customWeekdays),
        dueAt: dueAt,
        snoozedUntil: snoozedUntil,
      );

  group('RecurrenceRule', () {
    test('daily recurs every day', () {
      final rule = RecurrenceRule.fromFrequency('Daily');
      expect(rule.occursOn(monday), isTrue);
      expect(rule.occursOn(sunday), isTrue);
    });

    test('weekdays recurs Monday to Friday only', () {
      final rule = RecurrenceRule.fromFrequency('Weekdays');
      expect(rule.occursOn(monday), isTrue);
      expect(rule.occursOn(saturday), isFalse);
      expect(rule.occursOn(sunday), isFalse);
    });

    test('weekends recurs Saturday and Sunday only', () {
      final rule = RecurrenceRule.fromFrequency('Weekends');
      expect(rule.occursOn(monday), isFalse);
      expect(rule.occursOn(saturday), isTrue);
      expect(rule.occursOn(sunday), isTrue);
    });

    test('custom recurs on the configured weekdays', () {
      final rule = RecurrenceRule.fromFrequency('Custom', const [2]);
      expect(rule.occursOn(tuesday), isTrue);
      expect(rule.occursOn(monday), isFalse);
    });

    test('an unknown frequency never recurs', () {
      final rule = RecurrenceRule.fromFrequency('Sometimes');
      expect(rule.occursOn(monday), isFalse);
      expect(rule.occursOn(sunday), isFalse);
    });
  });

  group('Unscheduled', () {
    test('is never due', () {
      expect(const Unscheduled().isDueOn(monday, now: now), isFalse);
    });
  });

  group('Once', () {
    test('is due on its own day only', () {
      final schedule = Once(saturday);
      expect(schedule.isDueOn(saturday, now: now), isTrue);
      expect(schedule.isDueOn(monday, now: now), isFalse);
    });

    test('ignores the time of day in the due date', () {
      final schedule = Once(DateTime(2025, 6, 14, 18, 30));
      expect(schedule.isDueOn(saturday, now: now), isTrue);
    });
  });

  group('Recurring overrides', () {
    test('an active snooze hides today and every future day', () {
      final schedule =
          recurring('Daily', snoozedUntil: now.add(const Duration(hours: 3)));

      expect(schedule.isDueOn(wednesday, now: now), isFalse);
      expect(schedule.isDueOn(saturday, now: now), isFalse);
    });

    test('a snooze does not rewrite days already in the past', () {
      final schedule =
          recurring('Daily', snoozedUntil: now.add(const Duration(hours: 3)));

      expect(schedule.isDueOn(tuesday, now: now), isTrue);
    });

    test('an elapsed snooze is inert', () {
      final schedule = recurring('Daily',
          snoozedUntil: now.subtract(const Duration(hours: 1)));

      expect(schedule.isDueOn(wednesday, now: now), isTrue);
    });

    test('a due date suppresses the days before it', () {
      final schedule = recurring('Daily', dueAt: saturday);

      expect(schedule.isDueOn(wednesday, now: now), isFalse);
    });

    test('a due date forces its own day even outside the recurrence', () {
      final schedule = recurring('Weekdays', dueAt: saturday);

      expect(schedule.isDueOn(saturday, now: now), isTrue);
    });

    test('recurrence resumes once the rescheduled day is past', () {
      final schedule = recurring('Weekdays', dueAt: saturday);

      // Sunday is still a non-working day for a Weekdays rule.
      expect(schedule.isDueOn(sunday, now: now), isFalse);
      // Monday falls back to the normal recurrence.
      expect(schedule.isDueOn(DateTime(2025, 6, 16), now: now), isTrue);
    });

    test('a reschedule does not rewrite days already in the past', () {
      final schedule = recurring('Weekdays', dueAt: saturday);

      expect(schedule.isDueOn(monday, now: now), isTrue,
          reason: 'the override only applies from today forward');
    });
  });

  group('serialization', () {
    test('an unscheduled schedule round-trips', () {
      final json = const Unscheduled().toJson();

      expect(json['kind'], 'unscheduled');
      expect(TaskSchedule.fromJson(json), const Unscheduled());
    });

    test('a once schedule round-trips its due date', () {
      final schedule = Once(DateTime(2025, 6, 14, 18, 30));

      final restored = TaskSchedule.fromJson(schedule.toJson());

      expect(restored, schedule);
      expect((restored as Once).dueDate, DateTime(2025, 6, 14, 18, 30));
    });

    test('a recurring schedule round-trips its rule and overrides', () {
      final schedule = recurring(
        'Custom',
        customWeekdays: const [3, 1],
        dueAt: saturday,
        snoozedUntil: now,
      );

      final restored = TaskSchedule.fromJson(schedule.toJson()) as Recurring;

      expect(restored, schedule);
      expect(restored.rule, const CustomRecurrence({1, 3}));
      expect(restored.dueAt, saturday);
      expect(restored.snoozedUntil, now);
    });

    test('every frequency spelling round-trips through fromFrequency', () {
      for (final frequency in const ['Daily', 'Weekdays', 'Weekends', 'None']) {
        final rule = RecurrenceRule.fromFrequency(frequency);

        expect(rule.frequency, frequency);
        expect(
          RecurrenceRule.fromFrequency(rule.frequency, rule.customWeekdays),
          rule,
        );
      }
    });

    test('an unknown or missing schedule kind reads back as unscheduled', () {
      expect(
        TaskSchedule.fromJson(const {'kind': 'someday'}),
        const Unscheduled(),
      );
      expect(TaskSchedule.fromJson(const {}), const Unscheduled());
    });
  });
}
