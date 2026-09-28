import 'package:intl/intl.dart';

/// Shared date/time helpers used across every feature.
extension DateTimeExtensions on DateTime {
  DateTime get startOfDay => DateTime(year, month, day);
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);
  DateTime get startOfWeek => startOfDay.subtract(Duration(days: weekday - 1));
  DateTime get endOfWeek => startOfWeek
      .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  DateTime get startOfMonth => DateTime(year, month, 1);
  DateTime get endOfMonth => DateTime(year, month + 1, 0, 23, 59, 59, 999);

  bool get isToday => startOfDay == DateTime.now().startOfDay;
  bool get isYesterday =>
      startOfDay == DateTime.now().startOfDay.subtract(const Duration(days: 1));
  bool get isTomorrow =>
      startOfDay == DateTime.now().startOfDay.add(const Duration(days: 1));
  bool get isThisWeek => startOfWeek == DateTime.now().startOfWeek;
  bool get isThisMonth =>
      year == DateTime.now().year && month == DateTime.now().month;

  String format({String pattern = 'MMM d, yyyy'}) =>
      DateFormat(pattern).format(this);
  String formatTime({String pattern = 'h:mm a'}) =>
      DateFormat(pattern).format(this);

  String formatRelative() {
    final now = DateTime.now();
    final difference = now.difference(this);

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
