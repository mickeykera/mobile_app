# Stage L2: Task Write-Path Cutover

**Status:** the write-path stage named by `docs/ascend-stage-l1-5-cutover-prep.md`
§3/§8. This document is the decision record for D1–D5 and the contract the
implementation and its tests follow. L1.5 stays untouched: same marker, same
schema, same fields, same history, same migration semantics.

**Scope:** move every *normal* recurring-work write (create / update / complete /
archive / unarchive / delete / snooze / reschedule / streak-freeze) onto the
canonical `Task` behind the existing `CutoverGate`, reduce `Habit` to a
compatibility + history copy that is written only as a **mirror** of the canonical
write, and close D1–D5. No UI redesign, no field deletion, no history rewrite, no
new flag mechanism.

---

## 1. The gate becomes the wiring switch

L1.5 shipped `CutoverGate` inert (`static const bool enabled = false`,
read by nobody). L2 changes it in two ways and documents both:

```dart
abstract final class CutoverGate {
  static bool enabled = false;   // mutable; flipped to `true` as L2's final step
}
```

* **Mutable**, so a test can pin either regime (`setUp` → `false` keeps a
  legacy-regime suite green; `true` certifies the production regime).
* **Read in production at exactly four places** — the gate decides whether the
  app *wires* the cutover path, not whether each write checks it:

  | # | Site | Effect when `true` |
  |---|---|---|
  | 1 | `habitControllerProvider` | passes a `CutoverWritePath` into `HabitController` |
  | 2 | `taskControllerProvider` | passes the same path into `TaskController` |
  | 3 | `HabitTaskMigrationRunner.runIfRequired` | also backfills unlinked habits (D4) |
  | 4 | `CutoverAuditor.audit(routeWritesToTask:)` | default now `bool?` → `?? CutoverGate.enabled` (a non-const default is illegal once the field is non-const) |

**Routing is capability-driven inside the controllers**: a controller routes a
write when it *holds* a `CutoverWritePath` and the operation qualifies (migrated
item, or create). A directly-constructed controller without the path is the
explicit legacy regime — which stays real in production for quarantined habits
and is what the L0–L1.5 suites construct. There is therefore **no silent
Task→Habit fallback anywhere**: when the path is held, a failed canonical write
returns `Left` and the legacy row is never touched; when it is not held, the
controller is a legacy controller by construction, not by recovery.

## 2. The canonical write path — canonical first, mirror second

New: `lib/features/recurring/domain/cutover_write_path.dart`
(`CutoverWritePath`, holding `HabitRepository` + `TaskRepository` and building
its own `MigrationService`). One definition of the mapping, shared by both
controllers.

Every gated write follows the same three-step shape:

1. **Canonical write** to the `Task`. Failure → `Left`, nothing else runs.
2. **Compat mirror** of the 12 `kCutoverOwnedFields` onto the `Habit`
   (re-read, `copyWith`, only the owned fields). Failure → **compensating
   rollback**: re-write the previous canonical value (best effort), then `Left`.
3. `Right`.

Rollback exists because of §8.4 (below): without it a mirror failure would leave
the pair divergent with the canonical side ahead, and the launch bridge would
then push the stale legacy capability values back over the canonical write. With
it, a returned `Left` means the pair converges on the *pre-operation* value —
the operation failed, and the data says so. If the rollback itself fails the
residue is a divergence, which `CutoverAuditor` reports; retrying the operation
converges (the writes are idempotent re-applications of the same values).

### 2.1 Field mapping (both directions)

| Owned field | Canonical `Task` | Compat `Habit` |
|---|---|---|
| `title` | `title` | `title` |
| `description` | `description` | `description` (`?? ''` on the way out) |
| `category` | `category` | `category` (habit value kept when the Task's is null) |
| `projectId` / `goalId` | same | same |
| `schedule` | `Recurring(rule, dueAt, snoozedUntil)` | `frequency` + `customWeekdays` + `dueAt` + `snoozedUntil` (only when the schedule is `Recurring`; a migrated pair always is — see §6) |
| `archived` | `status == archived` (+ `archivedAt`) | `isArchived` |
| `targetCount`, `targetDuration`, `cue`, `timeOfDay` | same-named fields | same-named fields |
| `streakFreezesUsed` | `streakFreezeUsage` (`LegacyHabitCapabilities`) | `streakFreezesUsed` |

**Not owned:** `sortOrder` (each screen keeps its own order, as today — L1.5 §1),
`createdAt`, `completedAt`, streak/counter fields (`currentStreak`,
`longestStreak`, `totalCompletions`, `lastCompletedAt` — frozen on the legacy
side for migrated items, derived from the Task occurrence log everywhere else).

### 2.2 Operations, per controller

`HabitController` (gate holds path):

| Method | Gated when | Canonical | Mirror |
|---|---|---|---|
| `createHabit` | always (path held) | `MigrationService.migrateHabit(newId)` — migrate-on-create; on failure/failed verification **delete the just-created habit and return `Left`** (no silent unlinked fallback; if even the rollback delete fails the habit is picked up by the D4 backfill next launch) | n/a — the habit comes back linked |
| `updateHabit` (and everything that funnels through it: `snoozeHabit`, `rescheduleHabit`) | `taskId != null` | `updateTask(canonicalFrom(habit))` | `updateHabit(habit)` |
| `useStreakFreeze` | `taskId != null` | same as update (capability write) | same |
| `archiveHabit` / `unarchiveHabit` | `taskId != null` | same as update with `isArchived` mapped to `status`/`archivedAt` | `archiveHabit`/`unarchiveHabit` |
| `deleteHabit` | `taskId != null` | see §5 (ordered pair delete) | — |
| `completeHabit` / `uncompleteHabit` | unchanged | already canonical (`recordRecurringTaskOccurrence`) when `taskId != null` | none — legacy counters stay frozen by design |
| `reorderHabits` | not gated | `sortOrder` is not an owned field and no UI calls it | — |

`taskId == null` (legacy / quarantined) keeps the exact legacy path — that is
the ownership rule (L1.5 §1), not a fallback.

`TaskController` (gate holds path) — the Tasks screen is a second edit surface
for migrated items, so it mirrors the other way:

| Method | Gated when | After canonical write |
|---|---|---|
| `updateTask` (covers `setStatus`, `fileUnderProject`, TaskForm save) | a habit claims the task | mirror the 12 owned fields onto that habit; mirror failure → rollback the task write → `Left` |
| `archiveTask` / `unarchiveTask` | a habit claims the task | mirror `isArchived`; same failure rule |
| `deleteTask` | a habit claims the task | delegate to the ordered pair delete (§5) |
| `recordOccurrence` / `deleteOccurrence` | — | already canonical; no mirror (counters frozen) |
| `createTask` / `reorderTasks` | — | no habit can claim a task that does not exist yet / order not owned |

"Claims the task" = scan `getAllHabits(includeArchived: true)` for
`habit.taskId == task.id`. Deterministic ids would allow a substring inverse, but
migration may adopt a non-deterministic id, so the scan is the correct general
rule (both repositories keep their lists cached in memory).

## 3. D1–D5: the resolutions

Each row is the L1.5 finding, the rule now in force, and the test that pins it.
"No data loss" means: no write discards a value a reader still reads; every
failure surfaces as `Left`; retry converges.

| # | L1.5 finding | L2 rule | Pinned by |
|---|---|---|---|
| **D1** | Editing a migrated habit wrote narration/context (`title`, `category`, `description`, `projectId`, `goalId`) to the Habit only; the two screens showed different values. | Canonical write to the Task, mirror to the Habit — for edits from **either** surface (Habits card `Edit Habit` → `updateHabit`; Tasks screen `Edit` → `updateTask`). Both readers stay correct without touching a single read site, because the mirror keeps the pair equal. | `l2_*_test`: edit via habit → Task carries it (and `CutoverAuditor.pairDivergences` is empty); edit via task → Habit carries it. |
| **D2** | `archiveHabit` flipped `Habit.isArchived` only; the Task kept surfacing as work. | Archive is an owned field: canonical `status`/`archivedAt`, mirror `isArchived`, both directions (`archiveHabit`/`unarchiveHabit` and `archiveTask`/`unarchiveTask`/`setStatus(archived)`). | `l2_*_test`: archive from Habits → task archived and gone from `recurringWorkFrom`/`tasksProvider`; archive from Tasks → habit `isArchived`. |
| **D3** | "Delete Recurring Task" deleted the Habit + frozen legacy rows; the canonical Task and its occurrence rows survived as an orphan, while the dialog promised history deletion. | Ordered pair delete (§5): Task, then its occurrence rows, then the Habit + legacy rows. From either surface (`deleteHabit`, `deleteTask`). Partial states are named, reported by `CutoverAuditor`, and converge on retry. | `l2_*_test`: full delete removes task + all `itemType == 'task'` rows + habit + legacy rows; injected failure at each step asserts the documented residue. |
| **D4** | A habit created after the migration marker never migrated; the Task population stopped growing. | **Migrate-on-create** (`createHabit` → `migrateHabit`, rollback + `Left` on failure) **plus** a parity-gated startup backfill (§4) so every eligible `taskId == null` habit is linked the first launch after the gate opens. Quarantined habits stay legacy — reported, never forced. | `l2_*_test`: created habit comes back `taskId != null` with a canonical Task under `task_hm_*`; backfill links eligible unlinked habits, skips quarantined and dangling links; a failing Task write rolls the create back. |
| **D5** | Snooze/reschedule wrote `Habit.snoozedUntil`/`dueAt` only; the Task's `Recurring` overrides stayed at the migration-time copy, so Task-side due-ness ignored them. | Snooze/reschedule are owned `schedule` writes: canonical `Recurring(dueAt:, snoozedUntil:)`, mirror to `habit.dueAt`/`snoozedUntil`. Reverses the L1.1 §4 "Habit gate applies" bridge-period rule as L1.5 required. | `l2_*_test`: snooze → `task.schedule is Recurring` carries `snoozedUntil` and `Recurring.isDueOn` agrees with `habit.isDueOnDate`; reschedule clears the snooze on both sides. |

No STOP condition is hit: every field a migrated item needs has a Task carrier
that round-trips (L1.5 §6 proved it), identity stays deterministic, no duplicate
Task can be created (migrate-on-create runs the existing idempotent state
machine, which adopts rather than duplicates), and no normal write still
*requires* the Habit once the path is wired.

## 4. D4 backfill — where and what

`HabitTaskMigrationRunner.runIfRequired()` keeps its marker semantics untouched
(no bump) and gains one gate-gated pass after the marker/bridge logic:

```dart
if (CutoverGate.enabled) await _backfillUnlinkedQuietly();
```

which calls a new `MigrationService.migrateUnlinkedHabits()`:

1. `runParityGate(includeArchived: true)` — quarantined habits are excluded
   (they are a deliberate hold, not a repair job).
2. Read all habits, keep `taskId == null` **only**. Dangling links
   (`taskId != null` but no Task) are deliberately *not* fed to `migrateHabit`
   here: the state machine would clear the link and re-create the Task, which
   would resurrect a pair whose delete partially failed. Dangling links belong
   to L1.4's recovery state machine and are listed by the auditor.
3. `migrateHabits(eligible ∩ unlinked)` — idempotent, adopts an existing
   deterministic Task if one is already there.

Runs every launch while unlinked habits exist (a diff over two cached lists,
same cost class as the capability bridge) so post-marker habits converge on the
first launch after the flip. It is *not* marker-gated: a marker would retire it
for exactly the population it exists to serve.

## 5. D3 delete — order, residue, retry

Order inside `CutoverWritePath.deleteMigratedPair(habit)`:

1. `taskRepository.deleteTask(taskId)`
2. delete every occurrence row (`itemId == taskId && itemType == 'task'` — via
   `getAllCompletions` + `deleteCompletion`, so no repository interface changes)
3. `habitRepository.deleteHabit(habitId)` (removes the habit + its legacy rows)

Rationale: each step that can fail leaves the *most recoverable* residue behind:

| Fails at | Residue | Why it is the good one |
|---|---|---|
| 1 | nothing changed | clean `Left` |
| 2 | dangling link + orphaned rows | the habit (with its legacy history) is intact and readable; L1.4 handles dangling links; the auditor reports them; retry deletes the rows (step 2 is a filter — idempotent) |
| 3 | dangling link, task + rows gone | the habit still shows its legacy history; nothing the user can see was half-deleted; retry finishes |

The reverse order (habit first) is what ships today and is D3 itself: it leaves
an orphan Task that still appears as work in the Tasks screen. Deletions are not
rolled back — there is no pre-image to restore — so the contract for this
operation is: *first failure returns `Left`, every residue is either invisible or
listed by `CutoverAuditor` (`danglingTaskIds`, `orphanedMigratedTaskIds`), and
retrying the delete converges.* The auditor does **not** auto-repair any of it.

## 6. The TaskForm schedule bug (in scope: it would destroy D5's carrier)

`task_form._save` rebuilds `schedule` as `Once`/`Unscheduled` for an existing
task, so saving an edit on any recurring (i.e. migrated) task replaces its
`Recurring` schedule and the item vanishes from every recurring list — and
`recordOccurrence` then fails validation (a `Left` the Today screen swallows).
L2 fixes it: when the existing `base.schedule is Recurring`, the save preserves
it (the form cannot *create* recurring tasks, so every recurring task in the
system is a migrated one). This is what makes "the Tasks screen is a canonical
edit surface for migrated items" (D1, §2.2) safe.

## 7. §8.4 — the bridge, resolved without deleting it

L1.5 §8.4: *"the five writers move to the Task side in the same change that
deletes the bridge, or the legacy copy drifts ahead of canonical and the bridge
overwrites it back."* The hazard is real; the L2 answer is not deletion but
making the preimage impossible:

* Every canonical write mirrors its capabilities onto the Habit in the same
  operation → after any successful write the pair is **equal** → the bridge
  (`syncTaskCapabilities`, diff-based, habit→task) finds nothing to write.
  **Testable invariant: "the launch bridge performs zero writes after a
  successful gated write."**
* If the mirror fails, the compensating rollback (§2) restores the canonical
  side to the habit's value before the error is returned, so the bridge again
  finds nothing to write. Only when the rollback *also* fails can the bridge
  push capability values — and that is the correct direction for a failed
  operation: the op failed, so the field returns to its pre-op value.
* The bridge is left exactly as it is (not flipped, not extended, not deleted)
  so the legacy regime's only self-healing mechanism keeps working for
  quarantined and pre-gate installs, and the L1.5 retirement point is
  documented rather than silently consumed: deleting `syncTaskCapabilities` is
  now safe *because* of the invariant above, and remains a post-cutover
  cleanup decision.

Non-capability fields (D1/D2/D5) have no bridge: a residual divergence there
after a failed rollback is reported by `CutoverAuditor` and repaired by the next
edit through either surface (which mirrors). L2 does **not** add a
pre-flip residue sweeper: pre-L2, *both* screens wrote one side independently
(Habits card edits → Habit; Tasks screen edits → Task), so the "newer" side is
genuinely ambiguous, and picking a winner automatically would discard real user
edits — a data-loss risk, not a repair. Residue is reported, never guessed.

## 8. Test plan

Two regimes, pinned per file (the gate is mutable, and Dart runs each test file
in its own isolate, so `setUp` pinning is leak-free):

* **Legacy regime (`enabled = false`, or a controller built without the path)**
  — keeps L0–L1.5 green and keeps covering the path production still uses for
  quarantined habits: the existing 27 `l1_5_*` divergence tests, the migration
  suites, the fake-repository controller tests.
* **Cutover regime (path held; `enabled = true` where the gate itself is
  read)** — new `test/features/recurring/l2_*_test.dart` files over the real
  repositories (same harness as L1.5: real `HabitRepositoryImpl` /
  `TaskRepositoryImpl` over mocked `SharedPreferences`, `AppClock.debugSetNow`):
  1. `l2_write_routing_test` — D1/D2/D5 in both directions, migrate-on-create,
     ordered delete, streak freeze, and the §8.4 bridge-no-op invariant.
  2. `l2_failure_safety_test` — canonical failure touches nothing; mirror
     failure rolls back; delete-step failures leave the documented residue;
     create failure leaves no habit.
  3. `l2_backfill_test` — runner backfill links eligible unlinked habits,
     skips quarantined/dangling, is idempotent; marker semantics unchanged.

`CutoverAuditor` is used inside these tests as the assertion of "no divergence",
which is also the §8.3 readiness proof.

## 9. Flip procedure and verification

1. Implement §2–§6 with `CutoverGate.enabled` still `false` (production
   unchanged; new tests prove the routed path).
2. Full suite green at baseline: **730 pass / 10 known fails** (6 legacy-flow
   smoke + 4 render snapshots — untouched), `flutter analyze` at the 25
   pre-existing issues.
3. Flip `CutoverGate.enabled = true`; update the one L1.5 contract assertion
   that pins the old default (`l1_5_audit_gate_test`) to assert the flipped
   default with a comment; pin `false` in `setUp` of files whose subject *is*
   the legacy regime and that would otherwise be rewritten.
4. Re-run: `flutter test`, `flutter analyze`, `flutter build linux --debug`
   (Android APK stays blocked — no SDK, do not install).
5. UI check: habits / today / tasks screens — migrated card, quick-create,
   snooze, archive, delete; no layout change.

## 10. Boundary statement

No schema bump, no marker bump, no field deletion, no completion-row rewrite,
no ID regeneration, no UI redesign, no new feature-flag mechanism, no
repository-interface change. Files added: `cutover_write_path.dart`, the
`l2_*_test.dart` suite, this document. Files changed: the two controllers, the
two providers, `migration.dart` (backfill entry), `migration_runner.dart`
(gate-gated call), `cutover_readiness.dart` (mutable gate + `bool?` audit
default), `task_form.dart` (Recurring preservation).

---

**End of stage document.**
