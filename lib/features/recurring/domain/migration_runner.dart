import 'package:flutter/foundation.dart';

import 'package:ascend/core/database/database.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'cutover_readiness.dart';
import 'migration.dart';

/// The production execution point for the Habit -> Task migration.
///
/// ## Why a marker key
///
/// The migration has to run exactly once per install, not once per launch. It is
/// gated on a single stored marker rather than on "are there habits without a
/// `taskId`", because the latter would re-read and re-verify every habit on
/// every single launch forever - the migration's own output is what makes the
/// check pass, so the check can never retire. Reading one key is cheap and lets
/// a fully migrated install skip the work entirely.
///
/// ## Why it is awaited at startup
///
/// The runner is awaited inside the same future that gates the first frame
/// (`app.dart`), immediately after `DatabaseService.initialize`. That is
/// deliberate and is the one place a data migration must not be casual:
///
///  * `habitRepositoryProvider` and `taskRepositoryProvider` are cached
///    providers, and each repository loads its JSON list into an in-memory cache
///    on first read. If the migration ran while the UI were already reading
///    through a *different* instance, the two caches would race and the last
///    write would win - which, given the migration writes `taskId`, is a lost
///    update. Running first means every later reader sees the migrated state.
///  * Running before the UI also means a half-migrated dataset is never
///    rendered. The bridge paths tolerate `taskId == null` correctly, so this is
///    belt-and-braces rather than a correctness requirement.
///
/// The cost is bounded and paid once: the marker short-circuits every launch
/// after the first, and the work itself is a handful of JSON list operations.
/// The one per-launch addition since Stage L1.3 is the *capability bridge*
/// (`MigrationService.syncTaskCapabilities`), which is deliberately not
/// marker-gated: it is a diff over two already-loaded in-memory lists that
/// writes nothing on a converged install, so it stays cheap, and making it
/// one-shot would give a post-L0 install exactly one chance to pick up
/// capability values that were written before this stage existed.
class HabitTaskMigrationRunner {
  static const String _markerKey = 'habit_task_migration';
  static const int _markerVersion = 1;

  final MigrationService _migration;
  final DatabaseService _database;

  HabitTaskMigrationRunner({
    required MigrationService migration,
    required DatabaseService database,
  })  : _migration = migration,
        _database = database;

  /// Whether this install has already completed the migration.
  bool get isComplete {
    final marker = _database.getJson(_markerKey);
    return marker?['version'] == _markerVersion;
  }

  /// Runs the migration if this install has not completed it.
  ///
  /// Never throws: a failed migration leaves the marker unwritten so the next
  /// launch retries, and the app starts normally on unmigrated data - which the
  /// legacy code paths handle, since that is where every install already is.
  /// Quarantined habits are recorded in the marker rather than retried
  /// forever; they need a parity decision, not another attempt.
  Future<HabitTaskMigrationRunResult> runIfRequired() async {
    final result = isComplete
        ? const HabitTaskMigrationRunResult.skipped()
        : await _runMigration();

    // Stage L2 (D4): with the cutover gate open, adopt every eligible habit
    // that never got a link - a habit created just before a crash, or one whose
    // migrate-on-create failed. This is not marker-gated: it must keep checking
    // on every launch, because a new unlinked habit can appear at any time.
    // It runs before the bridge so a freshly adopted habit's capabilities are
    // already canonical when the bridge diffs the linked set.
    await _backfillUnlinkedQuietly();

    // Stage L1.3: the capability bridge runs on every launch, complete or not.
    // See MigrationService.syncTaskCapabilities for why it is diff-based
    // rather than marker-gated - and for the retirement condition.
    await _syncCapabilitiesQuietly();

    return result;
  }

  /// Runs the D4 backfill when the cutover gate is open, swallowing failures.
  ///
  /// Same policy as the bridge: a failed backfill must not stop the app, and it
  /// simply retries next launch. The backfill is idempotent and skips anything
  /// already linked, so retrying is safe.
  Future<void> _backfillUnlinkedQuietly() async {
    if (!CutoverGate.enabled) return;
    try {
      final outcomes = await _migration.migrateUnlinkedHabits();
      final failed = outcomes.where((o) => !o.isSuccess).length;
      if (failed > 0) {
        debugPrint('Unlinked habit backfill left $failed habit(s) unlinked; '
            'will retry next launch.');
      }
    } catch (e) {
      debugPrint('Unlinked habit backfill failed, will retry next launch: $e');
    }
  }

  Future<HabitTaskMigrationRunResult> _runMigration() async {
    try {
      final result = await _migration.runFullMigration();

      final failed = result.outcomes.where((o) => !o.isSuccess).length;
      final unverified = result.outcomes
          .where((o) => o.isSuccess && !o.verification.isVerified)
          .length;

      // The marker records *completion*, so it may only be written when every
      // eligible habit actually verifies. Writing it after a run that left
      // failures or unverified outcomes behind would retire the migration with
      // the work unfinished: the retry this design depends on would never happen,
      // and the unverified link would look migrated forever. Quarantined habits
      // do not block the marker - they are a deliberate hold, not a failed write.
      final complete = failed == 0 && unverified == 0;
      if (complete) {
        await writeMarker({
          'version': _markerVersion,
          'completedAt': AppClock.now().toIso8601String(),
          'migrated': result.migratedCount,
          'verified': result.outcomes.where((o) => o.isSuccess).length,
          'quarantined': result.report.quarantined.length,
          'failed': 0,
          'duplicatesReported': result.outcomes
              .where((o) => o.duplicateTaskIds.isNotEmpty)
              .fold(0, (sum, o) => sum + o.duplicateTaskIds.length),
        });
      } else {
        debugPrint(
          'Habit->Task migration incomplete ($failed failed, $unverified '
          'unverified); marker not written, will retry next launch.',
        );
      }

      return HabitTaskMigrationRunResult(
        ran: true,
        migratedCount: result.migratedCount,
        quarantined: result.report.quarantined.length,
        failed: failed,
        unverified: unverified,
        outcomes: result.outcomes,
        report: result.report,
      );
    } catch (e) {
      // Deliberately not rethrown: a migration failure must not stop the app
      // from starting, and leaving the marker absent means the next launch
      // retries from the same idempotent starting point.
      debugPrint('Habit->Task migration failed, will retry next launch: $e');
      return HabitTaskMigrationRunResult(
        ran: true,
        migratedCount: 0,
        quarantined: 0,
        failed: 0,
        unverified: 0,
        error: '$e',
      );
    }
  }

  Future<void> _syncCapabilitiesQuietly() async {
    try {
      final report = await _migration.syncTaskCapabilities();
      if (!report.isClean) {
        debugPrint('Capability bridge incomplete: $report');
      }
    } catch (e) {
      // Same policy as the migration itself: a failed pass must not stop the
      // app, and reporting it only in logs keeps the diagnosis from being
      // mistaken for a crash.
      debugPrint('Capability bridge failed, will retry next launch: $e');
    }
  }

  /// Persists the completion marker.
  ///
  /// A named method rather than an inline `setJson` so a failure at this one
  /// boundary is injectable. The contract it enforces is the same one the
  /// whole runner upholds: a marker that did not land leaves the install
  /// reading as unmigrated, so the next launch retries - which is the repair
  /// path, not a second mechanism.
  @visibleForTesting
  Future<void> writeMarker(Map<String, dynamic> payload) async {
    await _database.setJson(_markerKey, payload);
  }
}

/// What one runner invocation did.
@immutable
class HabitTaskMigrationRunResult {
  /// False when the install was already complete and nothing was read or
  /// written.
  final bool ran;

  final int migratedCount;
  final int quarantined;
  final int failed;

  /// Habits whose writes succeeded but whose verification did not fully hold.
  /// Non-zero means the next launch should re-examine them.
  final int unverified;

  final List<HabitMigrationOutcome> outcomes;
  final MigrationReport? report;
  final String? error;

  const HabitTaskMigrationRunResult({
    required this.ran,
    required this.migratedCount,
    required this.quarantined,
    required this.failed,
    required this.unverified,
    this.outcomes = const [],
    this.report,
    this.error,
  });

  const HabitTaskMigrationRunResult.skipped()
      : ran = false,
        migratedCount = 0,
        quarantined = 0,
        failed = 0,
        unverified = 0,
        outcomes = const [],
        report = null,
        error = null;

  bool get isClean => failed == 0 && unverified == 0 && error == null;

  @override
  String toString() => 'HabitTaskMigrationRunResult(ran: $ran, '
      'migrated: $migratedCount, quarantined: $quarantined, '
      'failed: $failed, unverified: $unverified)';
}
