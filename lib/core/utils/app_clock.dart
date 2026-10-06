import 'package:flutter/foundation.dart';

/// The one place the app asks what time it is.
///
/// Reads through here rather than calling [DateTime.now] directly, because the
/// UI genuinely depends on the calendar: the hour picks the greeting, the
/// weekday picks which day is highlighted, and `isToday` decides whether a habit
/// counts as done. That is correct for the app and hostile to a golden test -
/// a screenshot taken at 20:28 fails at 09:00, and one taken on a Monday fails
/// on a Saturday, with no code change to explain it.
///
/// Tests that render pixels pin this to a fixed instant with [debugSetNow], so
/// what they capture is the layout rather than the day it happened to run on.
/// Production never pins it, so [now] is the wall clock.
class AppClock {
  const AppClock._();

  static DateTime Function() _source = DateTime.now;

  /// The current instant.
  static DateTime now() => _source();

  /// Replaces the clock with [source]. Tests only - a UI that pins this stops
  /// advancing, which is the point, and is never what shipped code wants.
  @visibleForTesting
  static void debugSetNow(DateTime Function() source) => _source = source;

  /// Restores the wall clock. Pair with [debugSetNow] in a `tearDown`.
  @visibleForTesting
  static void debugResetNow() => _source = DateTime.now;
}
