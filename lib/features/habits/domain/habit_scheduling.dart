/// Pure date maths for the Snooze and Reschedule options.
///
/// Kept out of the widgets so the meanings of "Later today", "This weekend" and
/// "Next week" are fixed in one place and can be tested against a pinned clock
/// instead of whatever day the suite happens to run on.
library;

/// The hour a date-only reschedule lands on.
///
/// The UI works in days; the entity stores an instant. Anchoring future-dated
/// options to the morning keeps the stored value stable and explainable.
const int kDefaultSchedulingHour = 9;

/// Today at [kDefaultSchedulingHour].
DateTime todayAt(DateTime from) => _atHour(from, kDefaultSchedulingHour);

/// Tomorrow at [kDefaultSchedulingHour].
DateTime tomorrowAfter(DateTime from) => _atHour(
    _startOfDay(from).add(const Duration(days: 1)), kDefaultSchedulingHour);

/// The upcoming Saturday strictly after [from].
///
/// Strictly after, so picking "This weekend" on a Saturday plans the next one
/// instead of silently targeting the same day.
DateTime thisWeekend(DateTime from) => _nextWeekday(from, DateTime.saturday);

/// The upcoming Monday strictly after [from].
DateTime nextWeek(DateTime from) => _nextWeekday(from, DateTime.monday);

/// A few hours from now, clamped inside the current day.
///
/// If "later today" would spill past midnight it lands on 23:59 instead, so the
/// snooze still ends today rather than quietly rolling over.
DateTime laterToday(DateTime from) {
  final candidate = from.add(const Duration(hours: 3));
  final endOfDay = DateTime(from.year, from.month, from.day, 23, 59);
  return candidate.isAfter(endOfDay) ? endOfDay : candidate;
}

DateTime _nextWeekday(DateTime from, int weekday) {
  final days = (weekday - from.weekday + 7) % 7;
  final offset = days == 0 ? 7 : days;
  return _atHour(
      _startOfDay(from).add(Duration(days: offset)), kDefaultSchedulingHour);
}

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _atHour(DateTime d, int hour) =>
    DateTime(d.year, d.month, d.day, hour);
