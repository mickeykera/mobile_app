import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/week_strip.dart';
import '../../../core/extensions/date_extensions.dart';
import '../../../core/utils/app_clock.dart';
import '../../focus/domain/entities/focus_session.dart';
import '../../focus/presentation/controllers/focus_controller.dart';
import '../../habits/domain/entities/habit.dart';
import '../../habits/domain/entities/habit_completion.dart';
import '../../habits/presentation/providers/habit_providers.dart';
import '../../progress/domain/services/progress_service.dart';
import '../../recurring/domain/recurring_streak.dart';

/// Time-of-day greeting for the Today header.
///
/// No name is appended: the app stores no user profile, and inventing a
/// placeholder ("Good morning, User") reads worse than the plain greeting and
/// would paper over the fact that there is nowhere to put a real name yet.
///
/// [hour] is a parameter rather than being read from the clock inside, so the
/// boundaries are testable without waiting for 4am.
String greetingForHour(int hour) {
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

/// Work minutes logged on [day].
///
/// [FocusSession.totalWorkMinutes] is cumulative for the session and
/// [startedAt] is fixed at creation, so a session that ran across midnight is
/// attributed entirely to the day it started. Splitting it would need the
/// per-interval log the session does not keep, and a few boundary minutes are
/// not worth a schema change.
///
/// In-progress sessions count too, using what they have accumulated so far:
/// the alternative is a session that is visibly running contributing nothing to
/// the day's total, which reads as a bug.
int focusMinutesOn(DateTime day, List<FocusSession> sessions) {
  final target = day.startOfDay;
  var total = 0;
  for (final session in sessions) {
    if (session.startedAt.startOfDay != target) continue;
    total += session.totalWorkMinutes;
  }
  return total;
}

/// Whether [habit] was due on [day].
///
/// Delegates to [Habit.isDueOnDate] rather than re-deriving the schedule, so
/// the week strip and the Today list can never disagree about what was due.
/// The old copy of the frequency switch here silently ignored snoozes and
/// reschedules, which made today look partial after a habit was snoozed away.
bool _wasDue(Habit habit, DateTime day) => habit.isDueOnDate(day);

/// Per-day completion state for the week containing [reference].
///
/// A day is [WeekDayState.partial] when some - but not all - of the habits due
/// that day were completed, which is the state a user is actually in most of
/// the time. Days after today are always [WeekDayState.upcoming]: nothing is
/// missed until the day has actually passed, otherwise Monday morning shows
/// Tuesday as a failure.
///
/// Ownership of a migrated habit's rows is resolved by
/// [ProgressService.completedHabitIdsByDay] rather than here, so this function
/// and the Analytics screen cannot disagree about which day a migrated habit
/// was done.
List<WeekDayState> weekDayStates({
  required DateTime reference,
  required List<Habit> habits,
  required List<HabitCompletion> completions,
}) {
  final today = reference.startOfDay;
  final monday = today.startOfWeek;

  const progress = ProgressService();
  final completedByDay = progress.completedHabitIdsByDay(
    completions,
    ProgressService.habitIdByTaskId(habits),
  );

  return List<WeekDayState>.generate(7, (index) {
    final day = monday.add(Duration(days: index));
    if (day.isAfter(today)) return WeekDayState.upcoming;

    final due =
        habits.where((habit) => !habit.isArchived && _wasDue(habit, day));
    if (due.isEmpty) return WeekDayState.upcoming;

    final completedOnDay = completedByDay[day] ?? const <String>{};
    final done = due.where((h) => completedOnDay.contains(h.id)).length;

    if (done == 0) {
      return day.isBefore(today) ? WeekDayState.missed : WeekDayState.upcoming;
    }
    if (done < due.length) return WeekDayState.partial;
    return WeekDayState.complete;
  });
}

/// Completions logged in the week containing [reference], counted once per
/// habit-day rather than per row.
///
/// A habit set to `targetCount: 3` writes a completion row on each tap, so the
/// raw row count would report three completions for one day's work.
///
/// Pass [habits] when the log may contain migrated habits. Their Task occurrence
/// rows are then counted under the habit's own id, which collapses the copied
/// row and the legacy row it was copied from into the single habit-day they
/// describe. Without [habits] a Task row has no habit to be attributed to and is
/// dropped: a Task belonging to no habit is not a habit-day, and guessing an
/// owner would double-count any habit that has been migrated.
int weekCompletionCount({
  required DateTime reference,
  required List<HabitCompletion> completions,
  List<Habit> habits = const [],
}) {
  final monday = reference.startOfWeek;
  final end = monday.add(const Duration(days: 7));
  final taskIdToHabitId = ProgressService.habitIdByTaskId(habits);

  final days = <String>{};
  for (final completion in completions) {
    final day = completion.completedAt.startOfDay;
    if (day.isBefore(monday) || !day.isBefore(end)) continue;

    final String? habitId;
    if (completion.isHabitCompletion) {
      habitId = completion.ownerId;
    } else if (completion.itemType == 'task') {
      habitId = taskIdToHabitId[completion.itemId];
    } else {
      continue;
    }
    if (habitId == null) continue;

    days.add('$habitId@${day.year}-${day.month}-${day.day}');
  }
  return days.length;
}

/// The longest current streak across all habits.
///
/// The Today header answers "how am I doing" with the best chain the user has
/// going, not the average: a single strong habit is the one worth nudging, and
/// averaging would let one reset habit drag a twelve-day streak toward nothing.
///
/// Pass [completions] to include migrated habits honestly. Their legacy record
/// keeps the counters the migration froze, so reading those reports the streak
/// as it stood on the day the habit was migrated and never moves again; their
/// Task occurrence log carries the history the counter is supposed to describe,
/// and is re-derived through the canonical day-consecutive rule. Archived habits
/// are skipped either way, so a retired chain is never the headline.
int bestCurrentStreak(
  List<Habit> habits, [
  List<HabitCompletion> completions = const <HabitCompletion>[],
]) {
  var best = 0;
  for (final habit in habits) {
    if (habit.isArchived) continue;
    final taskId = habit.taskId;
    final streak = taskId == null
        ? habit.currentStreak
        : RecurringStreak.forTaskLog(completions, taskId).currentStreak;
    if (streak > best) best = streak;
  }
  return best;
}

/// Greeting for right now.
final greetingProvider = Provider<String>(
  (ref) => greetingForHour(AppClock.now().hour),
);

/// Work minutes logged today.
final todayFocusMinutesProvider = Provider<int>((ref) {
  final sessions = ref.watch(focusControllerProvider).recentSessions;
  return focusMinutesOn(AppClock.now(), sessions);
});

/// True when a focus session is running right now, so the header can offer to
/// jump back into it instead of starting a second one.
final hasActiveFocusProvider = Provider<bool>((ref) {
  return ref.watch(focusControllerProvider).activeSession != null;
});

/// Longest streak currently running across habits.
///
/// Reads migrated habits through their Task occurrence log so the badge does not
/// freeze on whatever the streak happened to be the day a habit was migrated.
/// The stored counters stay as the value while that log is still loading: they
/// are a lower bound rather than a different number, and for an account with no
/// migrated habits the resolved value is identical to the fallback.
final bestStreakProvider = Provider<int>((ref) {
  return bestCurrentStreak(
    ref.watch(habitsProvider),
    ref.watch(allCompletionsProvider).valueOrNull ?? const <HabitCompletion>[],
  );
});

/// Completions across the week strip's range.
///
/// Watches the controller's completion list purely as an invalidation signal.
/// Without it this provider is read once and then cached forever, so completing
/// a habit updates the Today list but leaves the week strip showing the
/// previous totals - the screen contradicting itself a frame later.
final weekCompletionsProvider =
    FutureProvider<List<HabitCompletion>>((ref) async {
  ref.watch(habitControllerProvider.select((state) => state.todaysCompletions));
  final today = AppClock.now();
  return ref.watch(habitCompletionsInRangeProvider)(today);
});

/// The week's total, counting habit-days rather than rows.
///
/// A provider rather than a call at the call site so the number on screen and
/// the strip beside it come from the same read and cannot disagree.
final weekCompletionCountProvider = Provider<int>((ref) {
  return weekCompletionCount(
    reference: AppClock.now(),
    completions: ref.watch(weekCompletionsProvider).valueOrNull ??
        const <HabitCompletion>[],
    habits: ref.watch(habitsProvider),
  );
});

/// Per-day state for the current week.
///
/// Reads the same range as [weekCompletionsProvider] rather than the day's
/// slice the habits controller keeps in memory: a Monday-only user would
/// otherwise see six empty days because only Monday was ever loaded.
final weekDayStatesProvider = Provider<List<WeekDayState>>((ref) {
  final completions = ref.watch(weekCompletionsProvider).valueOrNull ??
      const <HabitCompletion>[];
  return weekDayStates(
    reference: AppClock.now(),
    habits: ref.watch(habitsProvider),
    completions: completions,
  );
});
