import 'package:flutter/foundation.dart';

import '../../habits/domain/entities/habit.dart';
import '../../habits/domain/entities/habit_completion.dart';
import 'recurring_streak.dart';

/// How a habit's stored streak counters relate to its completion log.
///
/// A habit keeps two records of the same history. The **counters**
/// (`currentStreak`, `longestStreak`, `totalCompletions`) live on the entity and
/// are updated at write time by `Habit._calculateNewStreak`, which looks only at
/// `lastCompletedAt` — it never opens the log. The **log** is a list of
/// `HabitCompletion` rows. Nothing keeps them in step but the convention that
/// `HabitController` updates both, so a missed or duplicated write leaves them
/// quietly disagreeing.
///
/// Stage G exists to measure that gap, because Stage H cannot safely migrate
/// writes until it knows which record to trust.
enum ParityVerdict {
  /// The log re-derives all three counters exactly.
  agrees,

  /// The counters claim completions the log has no rows for.
  ///
  /// Either a completion row was never written, or it was deleted without the
  /// counter being reverted.
  counterAheadOfLog,

  /// The log has completions the counters do not account for.
  logAheadOfCounter,

  /// Both, or the chain length differs while the totals match — the counters are
  /// internally inconsistent with the log in a way no single direction explains.
  ///
  /// Kept distinct rather than folded into the two above because it means the
  /// divergence is not a missed write: the totals balance but the chain does
  /// not, which points at the streak arithmetic rather than at the log.
  chainDisagrees,
}

/// A habit's stored counters beside the same values re-derived from its log.
@immutable
class HabitStreakParity {
  final String habitId;

  /// What the entity says.
  final int storedCurrentStreak;
  final int storedLongestStreak;
  final int storedTotalCompletions;

  /// What the completion log implies.
  final int loggedCurrentStreak;

  /// The longest run the log implies.
  ///
  /// Reported but **not** part of [verdict]. The log cannot reconstruct a
  /// lifetime high-water mark once a row is un-completed, so this differs from
  /// `storedLongestStreak` in normal, correct operation. See
  /// [HabitLogProjection.compareTo].
  final int loggedLongestStreak;

  /// Completions the log accounts for, one per completed day.
  final int loggedTotalCompletions;

  final ParityVerdict verdict;

  /// The most recent day the log has a completion for, or `null` when empty.
  final DateTime? lastLoggedCompletion;

  const HabitStreakParity({
    required this.habitId,
    required this.storedCurrentStreak,
    required this.storedLongestStreak,
    required this.storedTotalCompletions,
    required this.loggedCurrentStreak,
    required this.loggedLongestStreak,
    required this.loggedTotalCompletions,
    required this.verdict,
    this.lastLoggedCompletion,
  });

  bool get isConsistent => verdict == ParityVerdict.agrees;

  @override
  String toString() => 'HabitStreakParity($habitId, ${verdict.name}, '
      'stored: $storedCurrentStreak/$storedLongestStreak/'
      '$storedTotalCompletions, logged: $loggedCurrentStreak/'
      '$loggedLongestStreak/$loggedTotalCompletions)';
}

/// Re-derives a habit's streak counters from its completion log.
///
/// ## What "streak" means here
///
/// **Day-consecutive, deliberately.** Walking back from the most recent
/// completion one calendar day at a time is exactly what the habit write path
/// computes on every completion, so this is a like-for-like comparison and a
/// disagreement means a real divergence rather than two definitions meeting.
///
/// The alternative — walking the habit's *recurrence* backwards, skipping days it
/// was never scheduled — is a genuinely different metric rather than a better
/// reading of this one. A Mon/Wed/Fri habit completed on those three days scores
/// **1** here and **3** under the scheduled rule, because Tuesday and Thursday
/// are gaps. Adopting the scheduled reading would also make almost every
/// non-daily habit report a longer streak than the counter it shares its history
/// with, which is what would turn the parity gate into noise. Stage L1 settled it
/// and [RecurringStreak] is where that decision now lives; this class is kept
/// because the parity gate is expressed in terms of it, and it is now a thin
/// adapter — it owns no arithmetic, so the two sides of a migrated item cannot
/// drift apart again.
///
/// A scheduled-consecutive streak would still need its own stage and its own
/// migration of the stored counter.
class HabitLogProjection {
  /// Days on which this habit has at least one completion, newest first.
  ///
  /// A day appears once however many rows it has: the counters count *days*, not
  /// rows. `completeHabit` refuses to double-complete a day and `targetCount`
  /// rides on a single row's `count`, so summing `count` here would measure
  /// something the streak never tracked.
  final List<DateTime> completedDays;

  /// The canonical projection this view delegates to.
  final RecurringStreak _streak;

  const HabitLogProjection._(this.completedDays, this._streak);

  /// Derives the projection for [habitId] from every row in [completions].
  ///
  /// Only rows for this habit count, and only ones that are genuinely habit
  /// completions. `HabitCompletion.isHabitCompletion` is the discriminator, and
  /// it exists precisely because completion rows are owner-typed: a row with
  /// `itemType` other than `'habit'` belongs to some other work item and must not
  /// be counted here.
  factory HabitLogProjection.from(
    List<HabitCompletion> completions,
    String habitId,
  ) {
    final streak = RecurringStreak.forHabitLog(completions, habitId);
    return HabitLogProjection._(streak.completedDays, streak);
  }

  /// Total completions: one per completed day.
  int get totalCompletions => _streak.totalCompletedDays;

  /// Length of the unbroken run of days ending at the most recent completion.
  ///
  /// Zero when the log is empty. Note this is a run of *completed* days, not of
  /// days since the last completion: a habit last done a week ago has a logged
  /// current streak of whatever it had then, which is exactly what the stored
  /// counter also holds. Ageing is a separate concern from parity and neither
  /// side applies it.
  int get currentStreak => _streak.currentStreak;

  /// Longest run of consecutive days anywhere in the log.
  ///
  /// Diagnostic only — see [RecurringStreak.longestStreak].
  int get longestStreak => _streak.longestStreak;

  /// Compares this projection against [habit]'s stored counters.
  ///
  /// The verdict is decided on [Habit.currentStreak] and
  /// [Habit.totalCompletions] only. [Habit.longestStreak] is reported but
  /// deliberately excluded, because it is a **high-water mark the log cannot
  /// reconstruct**: `copyWithUncompletion` decrements the current streak and the
  /// total but deliberately leaves the longest alone, because the run *was*
  /// achieved. Removing today's row destroys the log's only evidence of it, so
  /// comparing the two would report a divergence after every un-completion —
  /// flagging correct behaviour, which makes a gate that fires on the normal path
  /// no gate at all. The same reasoning is why [RecurringStreak.longestStreak]
  /// stays diagnostic: it is reported, never applied to a stored counter.
  ///
  /// This was found by writing the tests, not by reading the code, which is the
  /// argument for running the comparison before migrating writes onto it.
  HabitStreakParity compareTo(Habit habit) {
    final loggedCurrent = currentStreak;
    final loggedTotal = totalCompletions;

    final storedTotal = habit.totalCompletions;
    final chainMatches = habit.currentStreak == loggedCurrent;

    final ParityVerdict verdict;
    if (chainMatches && storedTotal == loggedTotal) {
      verdict = ParityVerdict.agrees;
    } else if (!chainMatches && storedTotal == loggedTotal) {
      // Totals balance but the chain does not: not a missed write, and
      // `currentStreak` *is* reconstructible, so this is a real inconsistency.
      verdict = ParityVerdict.chainDisagrees;
    } else if (storedTotal > loggedTotal) {
      verdict = ParityVerdict.counterAheadOfLog;
    } else {
      verdict = ParityVerdict.logAheadOfCounter;
    }

    return HabitStreakParity(
      habitId: habit.id,
      storedCurrentStreak: habit.currentStreak,
      storedLongestStreak: habit.longestStreak,
      storedTotalCompletions: storedTotal,
      loggedCurrentStreak: loggedCurrent,
      loggedLongestStreak: longestStreak,
      loggedTotalCompletions: loggedTotal,
      verdict: verdict,
      lastLoggedCompletion: completedDays.isEmpty ? null : completedDays.first,
    );
  }
}

/// Runs the parity check over every habit, given every completion row once.
List<HabitStreakParity> parityReportFor({
  required List<Habit> habits,
  required List<HabitCompletion> completions,
}) {
  return [
    for (final habit in habits)
      HabitLogProjection.from(completions, habit.id).compareTo(habit),
  ];
}

/// The habits whose log and counters disagree.
List<HabitStreakParity> divergentParities(List<HabitStreakParity> report) =>
    report.where((p) => !p.isConsistent).toList();
