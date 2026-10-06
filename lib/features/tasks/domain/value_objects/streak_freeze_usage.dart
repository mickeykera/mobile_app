import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';

/// How many of a recurring item's streak-freeze allowance have been spent.
///
/// ## Why this is a value object and not an `int`
///
/// `streakFreezesUsed` survived Stage L0 as a bare counter on `Habit`. Stage
/// L1.3 moved it onto [Task] as the canonical home, but a bare `int` on the
/// item record would be the wrong shape for two reasons:
///
///  * it has an invariant - usage is meaningful only against an allowance, and
///    an unbounded counter silently loses the "N left" the UI shows, and
///  * it is not task *configuration*: it is spent state that belongs to the
///    item's recurring record, so it needs to read as a distinct concept from
///    `targetCount`/`cue`/`timeOfDay`, which configure what the work is.
///
/// Wrapping it makes both facts checkable: `exhausted` and `remaining` are
/// derived rather than recomputed at every call site, and `use()` refuses to
/// spend more than the allowance so the invariant holds on the write path
/// rather than only in the widget that renders it.
///
/// ## What it does not do
///
/// Today this records **usage**, not protection. `HabitController.useStreakFreeze`
/// increments the counter; no read path consults it to protect a chain, and
/// [AppConstants.maxStreakFreezes] is the only limit it enforces. Stage L1.3
/// deliberately did not invent a freeze effect - that is a product decision
/// with streak-semantics consequences and belongs to a later stage. What L1.3
/// guarantees is that the number a user has already accumulated is preserved
/// verbatim through the migration and keeps incrementing in exactly the same
/// way it did before.
@immutable
class StreakFreezeUsage {
  /// Freezes spent so far. Never negative and never above [allowance] for a
  /// value produced by [use]; a persisted record can still hold a larger number
  /// if it was written by a build with a different allowance, and it is read
  /// back rather than clamped so nothing the user already spent is discarded.
  final int used;

  const StreakFreezeUsage([this.used = 0]);

  /// The per-item allowance.
  int get allowance => AppConstants.maxStreakFreezes;

  /// How many remain, floored at zero.
  int get remaining => (allowance - used).clamp(0, allowance);

  /// Whether the allowance is fully spent.
  bool get exhausted => used >= allowance;

  /// Spends one freeze, or returns `this` when the allowance is spent.
  ///
  /// The guard lives here rather than at the call site so a future write path
  /// cannot push the counter past the allowance by forgetting the check.
  StreakFreezeUsage use() => exhausted ? this : StreakFreezeUsage(used + 1);

  @override
  bool operator ==(Object other) =>
      other is StreakFreezeUsage && other.used == used;

  @override
  int get hashCode => used.hashCode;

  @override
  String toString() => 'StreakFreezeUsage($used/$allowance)';
}
