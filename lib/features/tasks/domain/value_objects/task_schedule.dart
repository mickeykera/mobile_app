/// Scheduling for a work item: when it is "due".
///
/// A one-off task and a recurring habit are the same concept wearing different
/// schedules, so the schedule lives in a value object rather than on the entity.
/// [Habit] builds a [Recurring] schedule from its flat `frequency` /
/// `customWeekdays` / `dueAt` / `snoozedUntil` fields; the upcoming `Task`
/// entity will build a [Once] or [Unscheduled] one. Nothing here reads the
/// clock: the current instant is passed in so the rules stay pure and
/// deterministic under test.
library;

/// How often a recurring item comes due.
sealed class RecurrenceRule {
  const RecurrenceRule();

  /// Whether this rule alone (ignoring per-item overrides) lands on [date].
  bool occursOn(DateTime date);

  /// The persisted `frequency` spelling this rule round-trips to.
  String get frequency;

  /// The selected weekdays for a custom rule; empty for every other rule.
  List<int> get customWeekdays;

  /// Maps the persisted `frequency` string onto a rule.
  ///
  /// Unknown frequencies recur never, matching the previous inline behaviour
  /// and keeping legacy data from silently becoming a daily obligation.
  factory RecurrenceRule.fromFrequency(
    String frequency, [
    List<int> customWeekdays = const [],
  ]) {
    switch (frequency) {
      case 'Daily':
        return const DailyRecurrence();
      case 'Weekdays':
        return const WeekdayRecurrence();
      case 'Weekends':
        return const WeekendRecurrence();
      case 'Custom':
        return CustomRecurrence(customWeekdays.toSet());
      default:
        return const NoRecurrence();
    }
  }
}

final class DailyRecurrence extends RecurrenceRule {
  const DailyRecurrence();

  @override
  bool occursOn(DateTime date) => true;

  @override
  String get frequency => 'Daily';

  @override
  List<int> get customWeekdays => const [];

  @override
  bool operator ==(Object other) => other is DailyRecurrence;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class WeekdayRecurrence extends RecurrenceRule {
  const WeekdayRecurrence();

  @override
  bool occursOn(DateTime date) =>
      date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;

  @override
  String get frequency => 'Weekdays';

  @override
  List<int> get customWeekdays => const [];

  @override
  bool operator ==(Object other) => other is WeekdayRecurrence;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class WeekendRecurrence extends RecurrenceRule {
  const WeekendRecurrence();

  @override
  bool occursOn(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  @override
  String get frequency => 'Weekends';

  @override
  List<int> get customWeekdays => const [];

  @override
  bool operator ==(Object other) => other is WeekendRecurrence;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class CustomRecurrence extends RecurrenceRule {
  final Set<int> weekdays;

  const CustomRecurrence(this.weekdays);

  @override
  bool occursOn(DateTime date) => weekdays.contains(date.weekday);

  @override
  String get frequency => 'Custom';

  @override
  List<int> get customWeekdays {
    final sorted = weekdays.toList()..sort();
    return sorted;
  }

  @override
  bool operator ==(Object other) =>
      other is CustomRecurrence &&
      other.weekdays.length == weekdays.length &&
      other.weekdays.every(weekdays.contains);

  @override
  int get hashCode => Object.hashAllUnordered(weekdays);
}

/// A frequency the app does not recognise. Never due.
final class NoRecurrence extends RecurrenceRule {
  const NoRecurrence();

  @override
  bool occursOn(DateTime date) => false;

  @override
  String get frequency => 'None';

  @override
  List<int> get customWeekdays => const [];

  @override
  bool operator ==(Object other) => other is NoRecurrence;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// When a work item is scheduled.
sealed class TaskSchedule {
  const TaskSchedule();

  /// Whether the item is due on [date], as of the instant [now].
  bool isDueOn(DateTime date, {required DateTime now});

  /// Encodes this schedule for persistence.
  Map<String, dynamic> toJson();

  /// Parses a persisted schedule.
  ///
  /// Unknown or missing `kind` values fall back to [Unscheduled] rather than a
  /// recurring schedule: a record this build cannot read must not become a
  /// daily obligation the user never asked for.
  factory TaskSchedule.fromJson(Map<String, dynamic> json) {
    switch (json['kind']) {
      case 'once':
        return Once(DateTime.parse(json['dueDate'] as String));
      case 'recurring':
        return Recurring(
          RecurrenceRule.fromFrequency(
            json['frequency'] as String? ?? 'None',
            (json['customWeekdays'] as List?)?.cast<int>() ?? const [],
          ),
          dueAt: _dateFromJson(json['dueAt']),
          snoozedUntil: _dateFromJson(json['snoozedUntil']),
        );
      default:
        return const Unscheduled();
    }
  }
}

/// A backlog item with no schedule. Never due.
final class Unscheduled extends TaskSchedule {
  const Unscheduled();

  @override
  bool isDueOn(DateTime date, {required DateTime now}) => false;

  @override
  Map<String, dynamic> toJson() => const {'kind': 'unscheduled'};
}

/// A single occurrence on [dueDate].
///
/// Ignores [now]: history is answered by the date, and "is this one-off due
/// today" is the same question as "is today its date".
final class Once extends TaskSchedule {
  final DateTime dueDate;

  const Once(this.dueDate);

  @override
  bool isDueOn(DateTime date, {required DateTime now}) =>
      _isSameDay(date, dueDate);

  @override
  Map<String, dynamic> toJson() =>
      {'kind': 'once', 'dueDate': dueDate.toIso8601String()};

  @override
  bool operator ==(Object other) =>
      other is Once && _isSameDay(other.dueDate, dueDate);

  @override
  int get hashCode => Object.hash(dueDate.year, dueDate.month, dueDate.day);
}

/// A recurrence plus the two per-item overrides.
final class Recurring extends TaskSchedule {
  final RecurrenceRule rule;

  /// The moment this item should next become due, set by a reschedule.
  final DateTime? dueAt;

  /// While this is in the future the item is held out of the workload.
  final DateTime? snoozedUntil;

  const Recurring(this.rule, {this.dueAt, this.snoozedUntil});

  /// Whether the item is due on [date].
  ///
  /// [rule] is the default, but two overrides sit on top of it:
  ///
  /// * An active [snoozedUntil] removes the item from today and every future
  ///   day, so it leaves the workload the moment it is snoozed. Past days keep
  ///   their history - a snooze today must not rewrite last week's stats.
  /// * A [dueAt] reschedules a single occurrence. It suppresses the item on
  ///   every day before its own and forces it due on its own day even when the
  ///   recurrence would not pick it. Once its day is past, recurrence takes
  ///   over again. Like a snooze, the override applies only from today forward,
  ///   so rescheduling never rewrites a past day's history.
  @override
  bool isDueOn(DateTime date, {required DateTime now}) {
    final dateDay = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);

    final until = snoozedUntil;
    if (until != null && until.isAfter(now) && !dateDay.isBefore(today)) {
      return false;
    }

    final due = dueAt;
    if (due != null && !dateDay.isBefore(today)) {
      final dueDay = DateTime(due.year, due.month, due.day);
      if (dateDay.isBefore(dueDay)) return false;
      if (_isSameDay(dateDay, dueDay)) return true;
    }

    return rule.occursOn(date);
  }

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'recurring',
        'frequency': rule.frequency,
        'customWeekdays': rule.customWeekdays,
        'dueAt': dueAt?.toIso8601String(),
        'snoozedUntil': snoozedUntil?.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is Recurring &&
      other.rule == rule &&
      _sameMoment(other.dueAt, dueAt) &&
      _sameMoment(other.snoozedUntil, snoozedUntil);

  @override
  int get hashCode => Object.hash(rule, dueAt, snoozedUntil);
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime? _dateFromJson(Object? value) =>
    value is String ? DateTime.parse(value) : null;

bool _sameMoment(DateTime? a, DateTime? b) =>
    (a == null && b == null) ||
    (a != null && b != null && a.isAtSameMomentAs(b));
