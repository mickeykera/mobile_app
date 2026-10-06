import 'package:intl/intl.dart';

import '../utils/app_clock.dart';

/// Shared date/time helpers used across every feature.
extension DateTimeExtensions on DateTime {
  DateTime get startOfDay => DateTime(year, month, day);
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);
  DateTime get startOfWeek => startOfDay.subtract(Duration(days: weekday - 1));
  // The milliseconds matter: `endOfDay` and `endOfMonth` both land on .999, and
  // a half-open range that stops a millisecond short silently drops the final
  // instant of the period.
  DateTime get endOfWeek => startOfWeek
      .add(const Duration(days: 7))
      .subtract(const Duration(milliseconds: 1));
  DateTime get startOfMonth => DateTime(year, month, 1);
  DateTime get endOfMonth => DateTime(year, month + 1, 0, 23, 59, 59, 999);

  bool get isToday => startOfDay == AppClock.now().startOfDay;
  bool get isYesterday =>
      startOfDay == AppClock.now().startOfDay.subtract(const Duration(days: 1));
  bool get isTomorrow =>
      startOfDay == AppClock.now().startOfDay.add(const Duration(days: 1));
  bool get isThisWeek => startOfWeek == AppClock.now().startOfWeek;
  bool get isThisMonth =>
      year == AppClock.now().year && month == AppClock.now().month;

  String format({String pattern = 'MMM d, yyyy'}) =>
      DateFormat(pattern).format(this);
  String formatTime({String pattern = 'h:mm a'}) =>
      DateFormat(pattern).format(this);

  String formatRelative() {
    final now = AppClock.now();
    final difference = now.difference(this);

    // A timestamp in the future produces a negative duration, which used to
    // fall through every branch below and report "Just now" for a date three
    // days ahead. Journal entries can be backdated or scheduled, so say so
    // explicitly instead.
    if (difference.isNegative) {
      final ahead = this.difference(now);
      if (ahead.inDays > 365) {
        return 'in ${ahead.inDays ~/ 365}y';
      } else if (ahead.inDays > 30) {
        return 'in ${ahead.inDays ~/ 30}mo';
      } else if (ahead.inDays > 0) {
        return 'in ${ahead.inDays}d';
      } else if (ahead.inHours > 0) {
        return 'in ${ahead.inHours}h';
      } else if (ahead.inMinutes > 0) {
        return 'in ${ahead.inMinutes}m';
      }
      return 'Just now';
    }

    if (difference.inDays > 365) {
      return '${difference.inDays ~/ 365}y ago';
    } else if (difference.inDays > 30) {
      return '${difference.inDays ~/ 30}mo ago';
    } else if (difference.inDays > 7) {
      return '${difference.inDays ~/ 7}w ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String get dayOfWeek => DateFormat('EEEE').format(this);
  String get shortDayOfWeek => DateFormat('EEE').format(this);
  String get monthName => DateFormat('MMMM').format(this);
  String get shortMonthName => DateFormat('MMM').format(this);
}

extension DateTimeRangeExtensions on DateTime {
  /// Every day between [start] and [end] inclusive, stepping by [step].
  static List<DateTime> range(DateTime start, DateTime end,
      {Duration step = const Duration(days: 1)}) {
    final list = <DateTime>[];
    var current = start.startOfDay;
    final endDay = end.startOfDay;
    while (!current.isAfter(endDay)) {
      list.add(current);
      current = current.add(step);
    }
    return list;
  }
}
