# Stage L1.5 Cutover Preparation

**Status:** preparation only. **No final cutover occurred.** No Habit/Task field was
deleted, no completion history rewritten, no behavior change in production, no
marker bump, no schema bump. Everything added in this stage is additive and
proven not to change behavior while `CutoverGate.enabled == false` (the
production default).

**Scope:** prove that the `Task` is a complete, canonical, writable work item for
every recurring item; enumerate who owns each write today; expose — without
fixing — the divergences that a future write-path stage must resolve before the
final cutover; and provide a tested, inert gate and a read-only readiness audit
for that future stage.

---

## 1. The ownership contract TODAY (audited 2026-10-06)

One migratable recurring item is stored twice: the legacy `Habit` record and its
canonical `Task` (linked via `Habit.taskId`, deterministic `task_hm_<habitId>`).
These are the writes, per ownership:

| Concern | Non-migrated habit (`taskId == null`) | Migrated habit (`taskId != null`) |
|---|---|---|
| Create | `HabitController.createHabit` → `HabitRepository.createHabit` | n/a inside the legacy path — the migration creates the Task; `D4` covers new habits |
| Completion | `HabitController.completeHabit` → `createCompletion` (habit row) **+** `updateHabit` (counters) | `HabitController.completeHabit` → `recordRecurringTaskOccurrence` (Task row, `habitId: null`, `itemType: 'task'`); Habit counters **frozen** |
| Un-completion | `uncompleteHabit` → `deleteCompletion` + `updateHabit` | `uncompleteHabit` → `deleteRecurringTaskOccurrence`; Habit untouched |
| Five capabilities (`targetCount`, `targetDuration`, `cue`, `timeOfDay`, `streakFreezesUsed`) | written to the Habit | written to the **Habit** (form / `useStreakFreeze`); converged to the Task by the launch-time bridge (`MigrationService.syncTaskCapabilities`) |
| Narration / context (`title`, `category`, `description`, `projectId`, `goalId`) | Habit | **Habit only — never synced** (`D1`) |
| Recurrence due-ness (`snoozedUntil`, `dueAt` via `snoozeHabit`/`rescheduleHabit`) | Habit | **Habit only** — Task `Recurring` overrides stay at migration-time copy (`D5`, by design for the bridge period) |
| Archive / unarchive | Habit | **Habit only — Task status untouched** (`D2`) |
| Delete | Habit + its completion rows | Habit + its (frozen, legacy) completion rows; the canonical Task **survives orphaned** (`D3`) |
| Order (`sortOrder`) | Habit | Habit; the Task's own `sortOrder` is the migration-time copy |

Write sites referenced by file:line:

- `lib/features/habits/presentation/controllers/habit_controller.dart:164,183,205,223,239,267,308-327,339-350,369-383,405,417-442` — the legacy write path.
- `lib/features/habits/presentation/screens/habits_screen.dart:655,686-688,1057,1423-1435` — migrated-card "Edit Habit" goes through `showHabitFormSheet` → `updateHabit`; delete goes through `habitController.deleteHabit`.
- `lib/features/habits/data/repositories/habit_repository_impl.dart:232-244` — `deleteHabit` removes rows where `habitId == id` only, never the Task's occurrence rows (`habitId: null`).
- `lib/features/recurring/domain/migration.dart:590-608,736-741,772-827` — Task creation, per-habit capability sync, and the launch-time capability bridge.
- `lib/features/tasks/presentation/controllers/task_controller.dart:29,117-133,183-238,287-336` — the Task-side write path (including `recordOccurrence`/`deleteOccurrence`).

## 2. Verified invariants already pinned

These are proven by existing tests (L0, L1.2, L1.3, L1.4) over the real
repositories and are the load-bearing truths the cutover-prep tests restate:

1. The Task round-trips all five capabilities and defaults a keyless Task to the
   legacy defaults (`targetCount 1`, `Duration.zero`, `''`, `Morning`, `0`).
2. Completion rows are owner-typed (`isHabitCompletion` / `itemType == 'task'`),
   and every habit-scoped read collapses the two halves through
   `ProgressService.habitIdByTaskId` / `migratedHabitsProvider`.
3. The read ownership rule is single-source: `taskId == null` reads stored
   counters; `taskId != null` reads the Task occurrence log; never both.
4. The capability bridge is diff-based, writes only on divergence, never creates
   or links Tasks, never writes the Habit, and is retried every launch.
5. The migration marker (`habit_task_migration` v1) records completion only after
   full per-habit verification; failure leaves it absent and retryable.
6. Deterministic identity: a Task this run creates must carry
   `HabitTaskIdentity.taskIdForHabit`.

## 3. Findings — divergences that exist TODAY and are NOT fixed here

Each is a real gap between the Habit and the canonical Task for an already-
migrated item. They are reported (and, via `CutoverAuditor`, machine-detected),
not silently repaired, because the correct resolution is an architectural
decision for the write-path stage — which this stage explicitly is not.

| # | Divergence | Where it bites | Status |
|---|---|---|---|
| **D1** | Editing a migrated habit (`title`, `category`, `description`, `projectId`, `goalId`) writes the Habit only. The bridge converged **only the five capabilities** (`migration.dart:772-827`), so narration/context edits never reach the Task. The migrated card renders from the Habit (`habits_screen.dart:591` `habitByTaskId`), while Tasks / Projects / Today read the Task — the two stale apart. | A `title` change shows updated on the Habits screen and stale in Tasks/Today. | Needs an explicit sync-or-source-of-truth decision (L2). |
| **D2** | Archiving a migrated habit (`archiveHabit`) flips `Habit.isArchived` only; `Task.status` stays `todo` and the Task keeps surfacing in `recurringWorkFrom` (`recurring_work.dart:218-224`). | An "archived" recurring task keeps appearing as work. | Needs a dual-archive decision (L2). |
| **D3** | "Delete Recurring Task" on a migrated habit deletes the Habit and its frozen legacy rows only; the canonical Task and its occurrence rows survive as an orphan (`habit_repository_impl.dart:236` removes `habitId == id`, not `itemId == taskId`). Dialog text promises history deletion that does not happen. | Orphaned `task_hm_*` Tasks accumulate; their occurrence rows survive deletion. | `CutoverAuditor` detects orphans; deletion policy is an L2 decision. |
| **D4** | A habit created **after** the migration marker is written is never migrated: the marker gates the whole `runIfRequired` migration, and nothing re-runs it for new items. New habits remain `taskId == null` forever. | Reads are consistent (the `taskId == null` path is fully supported), but the fraction of work living in `Task` stops growing. | Cutover must either migrate-on-create or create recurring work as `Task` directly (L2). |
| **D5** | Snooze / reschedule of a migrated habit writes `Habit.snoozedUntil`/`dueAt` only; the Task `Recurring` overrides stay at the migration-time copy. | Task-side due-ness (Today's `Recurring` reads) ignores a later snooze. | Documented by design in L1.1 §4 ("Habit gate applies"); must be reversed at cutover. |

None of D1–D5 is a data-loss bug in the current code: nothing has been deleted or
overwritten, every write has a defined reader, and the legacy record is still the
readable writer it has always been. They are cutover blockers, which is why this
stage exists: before the Habit write path can be retired, each one needs an
explicit, approved rule.

## 4. The cutover gate — the seam (default off)

`lib/features/recurring/domain/cutover_readiness.dart` defines the only switch a
future write-path stage flips:

```dart
abstract final class CutoverGate {
  /// L1.5: inert. NOTHING in production reads this yet.
  /// Flip to `true` only as part of the write-path stage (L2+), after
  /// D1–D5 have a decided resolution AND the "route writes to Task" tests
  /// (`l1_5_*`) pass with it on.
  static const bool enabled = false;
}
```

The gate is deliberately inert: no production read path consults it, and the L1.5
spec asserts `enabled == false` (the "no final cutover" guarantee). The seam it
opens is `CutoverAuditor`, which takes the gate's value as a parameter and records
it on the report, so the same audit function can certify a dataset under either
regime without writing a byte.

**Let me know if I should flip this** — it is the entire point of the stage *not*
to.

## 5. The readiness audit — read-only detection

`CutoverReadinessReport` / `CutoverAuditor` (see `cutover_readiness.dart`) scan
every linked pair and report, per field:

- `selfHealing == true` — one of the five capabilities, which the launch bridge
  (`syncTaskCapabilities`) will converge on its own; listed for completeness, not
  alarms.
- `selfHealing == false` — a `D1`/`D2`/`D5`-class field (narration, context,
  schedule overrides, archived state): no mechanism repairs these; the write-path
  stage must.

It also reports `danglingTaskIds` (a `taskId` pointing at no Task; L1.4's recovery
state machine handles these) and `orphanedMigratedTaskIds` (a `task_hm_*` Task no
habit claims; `D3`'s residue). It **never writes** — its contract is the same as
the parity gate: detect and report, leave repair to the stage that has a decided
rule.

## 6. Test inventory added by this stage

Over the **real** repositories (same harness as L0–L1.4):

- `test/features/recurring/l1_5_write_ownership_test.dart` — the audit of §1,
  through the **real** `HabitController`: completing / un-completing a migrated
  item writes the Task occurrence log only (Habit counters proven frozen), a
  failing Task write propagates instead of silently falling back to the Habit
  path, capabilities converge through the bridge, narration/context writes land
  on the Habit and are detected as `D1`, archive as `D2`, orphaned delete as
  `D3`, and a post-marker habit is `D4`.
- `test/features/recurring/l1_5_task_roundtrip_test.dart` — a `Task` built from a
  `Habit` through `LegacyHabitCapabilities.applyTo` reads back byte-identical; a
  keyless Task reads as a default Habit; schedule/frequency and per-item overrides
  (`dueAt`/`snoozedUntil`) round-trip through `Recurring` JSON on both models.
- `test/features/recurring/l1_5_recurrence_completion_ownership_test.dart` —
  completion ownership at the repository boundary (a migrated tick writes exactly
  one Task row and never moves the frozen Habit; un-ticking removes exactly it)
  and recurrence ownership: the migrated Task is the pair's due-calculator, with
  `D5` (a legacy-side snooze diverges) and overrides copied at migration time
  honoured on the Task.
- `test/features/recurring/l1_5_read_path_test.dart` — the user-facing read paths
  (streaks, completion counts, the recurring list, the migrated-card habit map)
  under mixed data: legacy items from counters, migrated items from the Task log,
  never both; proof of legacy-absence tolerance (a migrated item's frozen counters
  can be zeroed with no change to any read); and no double counting of the two
  halves.
- `test/features/recurring/l1_5_audit_gate_test.dart` — `CutoverGate.enabled` is
  `false`; the audit is pure (re-running mutates nothing) and reads storage, not a
  cache; divergences are detected with the right `selfHealing` label; dangling +
  orphan detection; a mixed dataset splits into migrated/unlinked/orphan counts;
  re-running the migration state machine over a migrated install is a byte-safe
  no-op.

## 7. Where the audit is allowed to run

`CutoverAuditor` is pure domain glue over the same collections `ProgressService`
takes, so it is exercised entirely through tests in this stage. It is **not**
wired into `app.dart`, `HabitTaskMigrationRunner`, or any provider: this stage
does not add a startup pass. Wiring the audit into a diagnostics surface is a
decision for L2 (and would be the first consumer of `CutoverGate`).

## 8. What must be true before the FINAL cutover (the future flip)

Restated from the L1.1 retirement condition and expanded with D1–D5:

1. Every field a migrated item needs has a Task-side carrier that round-trips
   (proven here for the capabilities, recurrence and schedule; narration lives on
   `Task` already).
2. D1–D5 each has an approved resolution and a test that the resolution holds.
3. `CutoverReadinessReport.isClean` holds on a representative install.
4. The five writers move to the Task side **in the same change** that deletes the
   bridge (`syncTaskCapabilities` is the named removal point), or the legacy copy
   drifts ahead of canonical and the bridge overwrites it back.
5. No legacy field is deleted until its replacement is read in production.

## 9. Boundary statement

No marker bump, no schema bump, no field deletions, no history rewrite, no UI
change, no production behavior change, no new dependency, no migration execution.
The only production file added is the inert gate + audit in `cutover_readiness.dart`.

---

**End of stage document.**