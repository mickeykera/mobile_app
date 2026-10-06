# Stage L1 Design: Recurring Task Streak Semantics and Capability Ownership

**Status:** design-only, audit. No production code changes, schema changes, migrations, UI changes, or field deletions.

**Scope:** Resolve the 8 blockers that prevent the Habit → Task retirement from proceeding past Stage L0.

---

## 1. Canonical Recurring Task Streak Semantics

### CURRENT

- `HabitLogProjection` in `lib/features/recurring/domain/streak_parity.dart:155-169` walks back **calendar days** from the most recent completion one day at a time. This matches what `Habit._calculateNewStreak` computes on write. It is day-consecutive: a Mon/Wed/Fri habit with completions on those three days reports a day-consecutive streak of 3.

- `TaskStreakComputer` in `lib/features/recurring/domain/task_streak.dart:59-107` walks **scheduled days** back through only the days the Task's `RecurrenceRule` marks as due. It is scheduled-consecutive: a Mon/Wed/Fri habit completed on those three days reports a scheduled-consecutive streak of 1 (each skipped Tuesday breaks the chain).

- `ProgressService.habitStreaksByCategory` (`lib/features/progress/domain/progress_service.dart:119-123`) reads `habit.currentStreak` — the **stored** habit counter. It is the **only production caller** of habit streaks.

- `ProgressService.taskStreaksByCategory` (`lib/features/progress/domain/progress_service.dart:145`) constructs a `TaskStreakComputer` from `List<HabitCompletion> completions, List<Task> tasks` — **no production caller**. It is test infrastructure only.

- `AnalyticsRepositoryImpl.getHabitStreaksByCategory` (`lib/features/analytics/data/repositories/analytics_repository_impl.dart:157`) calls `_progress.habitStreaksByCategory(habitsResult.right!)`, which reads `Habit.currentStreak` — the stored value.

- UI: `habit_card.dart:183` displays `habit.currentStreak`, `habit_card.dart:230` checks `habit.currentStreak == 0`, and `habits_screen.dart:156-159` reduces `nonMigratedActive.map((h) => h.currentStreak).reduce(math.max)` for the overview. `habits_screen.dart:416` passes `currentStreak: habit.currentStreak` to the card widget.

- The parity report (`streak_parity_test.dart`) confirms: day-consecutive is the parity-definition metric; scheduled-consecutive would flag every non-daily habit as divergent.

### DECISION

Already approved in Stage G:

> "Streak parity is day-consecutive, matching the existing Habit write path." — `ascend-stage-l-habit-retirement.md:472-485`

The definition resolves: day-consecutive = like-for-like comparison with `Habit._calculateNewStreak`. Scheduled-consecutive is a different metric requiring its own stage.

### PROPOSAL

**The canonical recurring Task streak semantics are day-consecutive**, matching the Habit write path. This is the only semantics that:

- Preserves user-visible numbers across migration (habit `currentStreak` → Task occurrence log-derived `currentStreak` produce identical values when counters are migrated correctly).
- Keeps the parity gate meaningful (scheduled-consecutive would flag all non-daily habits as divergent, making the gate a no-op).
- Aligns with `ProgressService.habitStreaksByCategory`, the only production consumer of streak numbers.

The Task `TaskStreakComputer` remains the **authoritative derivation function** for the Task-side, but its numbers are **not displayed** until Stage J (or later) when the read path is wired. The gate stays day-consecutive.

**Recommendation:** Adopt day-consecutive as the canonical metric. `TaskStreakComputer` will produce day-consecutive results when fed `HabitCompletion` rows with `itemType == 'task'` — since each row represents a completed calendar day, walking the sorted completion dates one day at a time yields the same streak as `HabitLogProjection`. This is the "like-for-like" comparison Stage G mandates.

---

## 2. Current vs Recoverable longestStreak Data

### CURRENT

- `Habit` stores `longestStreak` as a **frozen** field updated only by `Habit.copyWithCompletion`/`copyWithUncompletion`.
- `Habit.copyWithUncompletion` deliberately **leaves `longestStreak` alone** (see `habit.dart:197-200,207-211`): removing today's completion destroys the log's only evidence of the prior high-water mark, so the log cannot reconstruct `longestStreak`.
- `TaskStreakComputer.longestStreak` (`task_streak.dart:110-147`) re-derives from the occurrence log but **cannot reconstruct the high-water mark** when completions have been un-completed. It reports the longest run in the current log.
- The parity report (`HabitStreakParity`) **reports `loggedLongestStreak` but deliberately excludes it from the verdict** (`streak_parity.dart:218`): including it would flag a divergence after every `copyWithUncompletion`, which is correct behavior but not an actionable gate.

### DECISION

Already approved in Stage G:

> "`longestStreak` is reported but excluded from the verdict. Writing the tests turned up the reason: `copyWithUncompletion` decrements `currentStreak` and `totalCompletions` but deliberately leaves `longestStreak` alone, because the run *was* achieved." — `ascend-stage-l-habit-retirement.md:501-503`

### PROPOSAL

**`longestStreak` stays on the Habit entity for migrated habits.** For the bridge period:

- Migrated habits retain their Habit entity (with `taskId != null`) and their stored `longestStreak` is preserved as-is.
- The Task occurrence log's `longestStreak` (derived via `TaskStreakComputer`) is a **diagnostic-only** number; it is not displayed on any screen and not used in any aggregate.
- When a habit is fully retired (Stage 7+), `longestStreak` is the last known value from the Habit entity, since the log cannot reconstruct it.
- **No schema change** is needed: `longestStreak` remains a field on `Habit`, simply becoming read-only for migrated items.

**Action:** Document that `longestStreak` on the Task side is diagnostic-only; the canonical value resides on the Habit entity until full retirement.

---

## 3. Ownership of Five Legacy Capabilities

### CURRENT

The five fields `targetCount`, `targetDuration`, `cue`, `timeOfDay`, `streakFreezesUsed` exist **only** on `Habit` (`lib/features/habits/domain/entities/habit.dart:14-31`). `Task` has no representation for any of them.

| Field | Habit home | Task home | Decision |
|---|---|---|---|
| `targetCount` | `int` on Habit (x per day) | none — `Recurring` models *when*, not *how much* | legacy-only |
| `targetDuration` | `Duration` on Habit | none — occurrence rows carry `duration`, the Task does not | legacy-only |
| `cue` | `String` free-text trigger | none | legacy-only |
| `timeOfDay` | `'Morning'|'Afternoon'|'Evening'` | none — `Recurring` has `dueAt`, not a time-of-day label | legacy-only |
| `streakFreezesUsed` | `int` — streak freeze count | none — `TaskStreakComputer` has no freeze concept | legacy-only |

`LegacyHabitCapabilities` (`habit_task_identity.dart:85-166`) structurally preserves these fields and adds `matchesHabit` / `fieldsLostFrom` so a future change that loses any of them fails a test.

### DECISION

Already approved in Stage L0 and documented in `habit_task_identity.dart:57-84`:

> "Adding five fields to `Task` would be inventing product semantics, which is Stage L1+ work and explicitly out of scope here. So the decision is **legacy-only for now, explicitly preserved and explicitly declared** rather than silently dropped."

### PROPOSAL

**The five fields remain on `Habit` only.** No migration adds them to `Task` or `Recurring`.

- `LegacyHabitCapabilities.fromHabit(habit)` reads all five from the Habit entity; this is the canonical snapshot.
- For migrated habits (`taskId != null`), the Habit entity **is retained** (not deleted) solely as the guardian of these five fields. The Habit is excluded from `RecurringWork` lists (per the logical deduplication rule: if `Habit.taskId != null`, treat the Task as the canonical item and do not expose the Habit separately).
- If/when a later stage resolves each field's canonical home, the Habit field is migrated and the Habit field can be retired. But **no field is deleted or migrated in L1.1**.
- The `LegacyHabitCapabilities` type and its `matchesHabit` verification remain active — any future migration that loses these fields will fail a verification test.

**Action:** No code changes for L1.1. Document that the five fields are Habit-only and preserved structurally via `LegacyHabitCapabilities`.

---

## 4. Snooze/Reschedule Interaction with Streaks

### CURRENT

- **Snooze:** `Habit.snoozedUntil` holds a `DateTime`. While active, the habit is held out of the workload (`habit.isSnoozed`). Completions during snooze still write to the habit completion log and update `currentStreak`/`totalCompletions`/`lastCompletedAt` — the snooze only affects *due-ness*, not completion recording.
- **Reschedule:** `Habit.reschedule` (via `lib/features/habits/domain/habit_scheduling.dart`) can change `dueAt` and `snoozedUntil`. A rescheduled occurrence does **not** rewrite past days' history.
- **Task:** Recurring tasks currently have **no occurrence history** (Stage H constraint). The `HabitController.completeHabit` dual-write (`→ HabitCompletion + → recordRecurringTaskOccurrence`) is the only way task occurrences get written. There is no `Task.snoozedUntil` equivalent in the current code.

### DECISION

Already documented in `work-item-model.md:554-565` (Stage H constraints) and `ascend-stage-l-habit-retirement.md:465-466`:

> 4. A recurring task MUST be able to record an occurrence before Habit converges.
> 5. `currentStreak` and `totalCompletions` are the stored values migration must reproduce exactly.
> 6. Streak parity = DAY-CONSECUTIVE, matching the existing Habit write path.

### PROPOSAL

**Snooze/reschedule semantics carry over to the Task side with the same definitions.**

- A migrated habit (`taskId != null`) that is snoozed carries its `snoozedUntil` on the Habit entity. The Task itself remains `todo`/`doing`; completion is always through occurrence rows, never through `TaskStatus.done`.
- **Snooze does not break the Task occurrence chain.** The Habit's `snoozedUntil` gate operates independently of the Task's occurrence log. During the bridge, completing a snoozed habit via the Habit UI still writes to both the Habit log and the Task occurrence mirror (dual-write, Stage J removal pending).
- **Reschedule** on the Habit side (`dueAt`/`snoozedUntil`) maps to the same fields on the Recurring Task schedule. The Task's `Recurring.dueAt` and `Recurring.snoozedUntil` are the per-item overrides.
- For the bridge period, the Habit entity remains the authoritative source for the five legacy capabilities + `snoozedUntil`. The Task mirrors the schedule but the Habit gate still applies.

**Action:** No changes in L1.1. Document the carry-over semantics for the bridge period.

---

## 5. Cutover from Legacy Completion History to Task History

### CURRENT

- **Shared completion log:** `HabitCompletion` rows are owned discriminated by `itemType` (`'habit'` | `'task'`) and `ownerId` (`habitId` for habit rows, `taskId` for task rows, fallback `ownerId = itemId ?? habitId`).
- **Habit reads:** `HabitRepository.getCompletionsForHabit(habitId)` filters `habitId == habitId`. `HabitLogProjection.from(completions, habitId)` filters `isHabitCompletion` (`itemType == 'habit'`).
- **Task reads:** `TaskStreakComputer` takes `List<HabitCompletion> completions` and filters `completion.itemId == task.id && completion.itemType == 'task'`.
- **Mixed read:** `RecurringWork` projects both sources tagged with `RecurringSource.habit` or `RecurringSource.recurringTask`. Consumers filter by source.
- **Parity gate:** `HabitLogProjection.from(completions, habit.id).compareTo(habit)` runs against **habit-filtered** completions only (rows where `isHabitCompletion == true`).

### DECISION

Already approved in Stage G and H:

> "Habit and Task completion rows coexist in the shared log, distinguished by `itemType`. Reads filter by ownership." — `work-item-model.md:141-148`

> "Parity gate only processes Habits with verdict `agrees`." — `ascend-stage-l-habit-retirement.md:579-581`

### PROPOSAL

**Cutover strategy: incremental provider migration, not data migration.**

L1.1 does **not** move any completion rows. The cutover is entirely at the read/provider level:

1. **Add `taskStreaksByCategory` consumer** to `ProgressService` — already exists but not wired. L1.1 wires it for the Task side.
2. **Add `taskStreaksByCategory` provider** to `recurring_providers.dart` — produces Task-derived streaks per category, keyed off `Task.category`.
3. **HabitsScreen split view** — L1.1 documents the split: non-migrated habits (`taskId == null`) continue showing `Habit.currentStreak`; migrated habits (`taskId != null`) derive streak from `TaskStreakComputer` on the occurrence log.
4. **No data move:** Legacy `HabitCompletion` rows with `itemType == 'habit'` remain untouched. New task occurrence rows (`itemType == 'task'`, `habitId: null`, `itemId: taskId`) are the Task's completion log.
5. **Parity gate stays on Habits:** Only Habits with `agrees` verdict are eligible for migration. The gate does not shift to Tasks in L1.1.

**Action:** Document the read-path split. No writes change. The cutover is provider-level: two parallel `currentStreak` computations (Habit-stored vs Task log-derived) until Stage J switches the UI entirely to the Task path.

---

## 6. Parity-Quarantine Recovery

### CURRENT

- `MigrationService.runParityGate()` (`migration_runner.dart:291-325`) runs `HabitLogProjection.from(completions, habit.id).compareTo(habit)` for every habit.
- Habits with `agrees` verdict → **eligible** for migration.
- Habits with **divergent** verdict → **quarantined** with `QuarantinedHabit(habitId, verdict, reason)`.
- Quarantined habits are **left untouched** — the marker is not written if any eligible habit fails verification (migration_runner.dart:81-93).
- The migration marker `habit_task_migration` version `1` is written only when `failed == 0 && unverified == 0` (migration_runner.dart:81-82).

### DECISION

Already approved:

> "Quarantined habits do not block the marker. They are a deliberate hold awaiting a parity decision, not a failed write, and retrying them forever would never resolve them." — `ascend-stage-l0-migration.md:120-122`

> "A habit is eligible when `HabitLogProjection` agrees with its stored counters. Otherwise it is quarantined." — `ascend-stage-l-habit-retirement.md:137-139`

### PROPOSAL

**Quarantine remains as-is in L1.1.** No recovery path is added in this stage.

- Quarantined habits stay on the legacy Habit path. They are excluded from migration eligibility.
- The parity report (`divergentStreakParityProvider`) continues to list divergent habits with their `ParityVerdict.name` and `reason`.
- **No auto-repair:** Divergent stored counters are not overwritten. This is intentional — the gap is reported, and a manual decision (repair or archive) is required before the habit can migrate.
- Recovery path (reconciling the counter to agree with the log, or archiving with a recorded reason) is Stage L2+ work.

**Action:** Document that quarantine is permanent per-habit until manual resolution. No code changes in L1.1.

---

## 7. Duplicate Task Policy

### CURRENT

- The migration state machine (`migration_runner.dart:353-454`) handles duplicate detection via `MigrationIdentitySource`:
  1. `existingLink` — habit already points at a Task that exists; adopt it.
  2. `deterministicId` — deterministic `task_hm_<habitId>` Task already exists; relink.
  3. `logicalAdoption` — an older attempt created a Task with a random id; match on content (title, schedule, projectId, goalId, category) and adopt the lowest id.
  4. `created` — create a new Task under the deterministic id.

- The `_logicalMatchesFor` method (`migration_runner.dart:574-599`) matches on: `t.title == habit.title`, `t.createdAt == habit.createdAt`, `t.projectId == habit.projectId`, `t.category == habit.category`, `t.schedule is Recurring`, and `jsonEncode(t.schedule.toJson()) == jsonEncode(habit.recurringSchedule.toJson())`.

- Duplicate Tasks are **reported** on the outcome (`HabitMigrationOutcome.duplicateTaskIds`) but **never deleted** — Stage L explicitly avoids a safe deletion mechanism.

### DECISION

Already approved:

> "Duplicates left behind by an older attempt are a pre-existing condition, reported separately on the outcome rather than counted here - otherwise adopting one would read as a fresh failure and a retry would never converge." — `migration_runner.dart:736-738`

> "Stage L has NOT been retired." — `ASCEND_AGENT_CONTEXT.md:420`

### PROPOSAL

**Duplicate Task policy stays as-is in L1.1.** The migration state machine handles duplicates at migration time; L1.1 does not change the policy.

- The `MigrationIdentitySource` enum and the six-step resolution order remain unchanged.
- `_logicalMatchesFor` matching criteria remain unchanged.
- Duplicates are reported but not auto-deleted. A future stage may add a cleanup policy, but L1.1 preserves the status quo.
- The key invariant: **one logical recurring item → at most one Task**. The adoption logic (step 3) ensures that if an older attempt already created a Task for this habit, the new run adopts it rather than creating a second.

**Action:** No changes. Document the existing duplicate-handling policy as the L1.1 baseline.

---

## 8. Migration Marker Versioning

### CURRENT

- Marker key: `habit_task_migration`
- Marker version: `1` (const `HabitTaskMigrationRunner._markerVersion = 1`)
- `isComplete` = `marker.version == _markerVersion`
- Written only when `failed == 0 && unverified == 0` (migration_runner.dart:81-82,93-98)
- A version bump re-runs the migration; idempotency in the state machine makes that safe.

### DECISION

Already approved in Stage L0:

> "Marker: key `habit_task_migration`, version `1`. Schema version is untouched — this is an additive key in existing storage, not a migration of the schema itself." — `ascend-stage-l0-migration.md:109-110`

> "`isComplete` is `marker.version == 1`. A version bump re-runs the migration; the idempotency in §6 is what makes that safe." — `ascend-stage-l0-migration.md:112-113`

### PROPOSAL

**Marker version `1` remains unchanged in L1.1.**

- No version bump. The migration continues to be gated on `marker.version == 1`.
- The marker records: `version`, `completedAt`, `migrated` count, `verified` count, `quarantined` count, `failed` (always 0 since write is gated), `duplicatesReported`.
- Since L1.1 makes **no production code changes**, no migration runs in production. The marker version stays at `1` as the baseline for when production migration eventually starts.
- If a future stage requires a version bump (e.g., to distinguish L0 from L1 migration behavior), that is explicitly out of L1.1 scope.

**Action:** Document marker version `1` remains the baseline. No changes.

---

## Resolved L1 Decisions

All 8 L1 blockers were resolved in prior stages. L1.1 documents the established decisions:

| # | Decision | Status | Rationale |
|---|----------|--------|-----------|
| 1 | Canonical recurring Task streak semantics | **RESOLVED** | Stage G approved day-consecutive as parity-definition metric, matching `Habit._calculateNewStreak`. `TaskStreakComputer` produces day-consecutive when fed `HabitCompletion` rows with `itemType == 'task'`. |
| 2 | Current vs recoverable longestStreak data | **RESOLVED** | Stage G approved reporting `longestStreak` but excluding from verdict because `copyWithUncompletion` deliberately preserves the high-water mark achieved. Canonical value remains on Habit entity; Task log-derived `longestStreak` is diagnostic-only during bridge. |
| 3 | Ownership of five legacy capabilities | **RESOLVED** | Stage L0 approved legacy-only preservation. `LegacyHabitCapabilities` structurally preserves the five fields on `Habit` with `matchesHabit`/`fieldsLostFrom` verification. No migration adds them to `Task`/`Recurring` in L1. |
| 4 | Snooze/reschedule interaction with streaks | **RESOLVED** | Stage H constraints require recurring task to record occurrence before Habit converges. Semantics carry over: snooze/reschedule on Habit entity affect due-ness but not completion recording; Task occurrence chain unaffected by snooze. |
| 5 | Cutover from legacy completion history to Task history | **RESOLVED** | Stage G/H approved shared completion log with `itemType` discrimination. Cutover is incremental provider migration: legacy `HabitCompletion` rows (`itemType == 'habit'`) remain canonical; new task occurrence rows (`itemType == 'task'`, `habitId: null`) written. No data move in L1. |
| 6 | Parity-quarantine recovery | **RESOLVED** | Stage L0 approved quarantine as deliberate hold awaiting parity decision, not failed write. Quarantined habits do not block migration marker; recovery path (manual decision) is L2+ work. |
| 7 | Duplicate Task policy | **RESOLVED** | Stage L0 approved duplicate handling: migration state machine resolves duplicates at migration time; pre-existing duplicates reported separately (`duplicateTaskIds`) and never auto-deleted to avoid treating adoption as fresh failure. |
| 8 | Migration marker versioning | **RESOLVED** | Stage L0 approved marker semantics: key `habit_task_migration`, version `1`, written only on full verification (`failed == 0 && unverified == 0`). Version bump re-runs migration under idempotency guarantees. No version bump in L1.1. |

---

## Files Inspected

| File | Purpose |
|---|---|
| `docs/ASCEND_AGENT_CONTEXT.md` | Project contract, stage history, test baselines |
| `docs/ascend-stage-l0-migration.md` | L0 marker, parity gate, marker semantics |
| `docs/ascend-stage-l-habit-retirement.md` | L0→L1 blockers, 8 items, acceptance criteria |
| `docs/architecture/work-item-model.md` | Stage A–I delivery status, constraint summaries |
| `docs/stage_k_design.md` | Stage K read-path unification, write-path migration |
| `lib/features/recurring/domain/habit_task_identity.dart` | Deterministic task id (`task_hm_<habitId>`), `LegacyHabitCapabilities` |
| `lib/features/recurring/domain/task_streak.dart` | `TaskStreakComputer` — scheduled-consecutive streaks |
| `lib/features/recurring/domain/streak_parity.dart` | `HabitLogProjection` — day-consecutive, `ParityVerdict` |
| `lib/features/tasks/domain/value_objects/task_schedule.dart` | `TaskSchedule` / `Recurring` / `RecurrenceRule` |
| `lib/features/tasks/domain/entities/task.dart` | `Task` entity, `TaskSchedule`, `TaskStatus` |
| `lib/features/habits/domain/entities/habit.dart` | `Habit` entity, five legacy capabilities, `currentStreak`/`longestStreak`/`totalCompletions` |
| `lib/features/habits/domain/entities/habit_completion.dart` | Shared completion log, `itemType`/`ownerId` discrimination |
| `lib/features/recurring/domain/migration.dart` | `MigrationService`, state machine, `_verify`, verification checks |
| `lib/features/recurring/domain/migration_runner.dart` | `HabitTaskMigrationRunner`, marker gating, `runIfRequired` |
| `lib/features/habits/data/repositories/habit_repository_impl.dart` | `reconcileHabitToTask`, streak getters, completion read/write |
| `lib/features/progress/domain/services/progress_service.dart` | `habitStreaksByCategory` (production caller), `taskStreaksByCategory` (no caller) |
| `lib/features/analytics/data/repositories/analytics_repository_impl.dart` | `getHabitStreaksByCategory` → `_progress.habitStreaksByCategory` |
| `lib/features/recurring/presentation/providers/recurring_providers.dart` | `recurringWorkProvider`, `recurringSourceCountsProvider`, parity report |
| `lib/features/recurring/domain/recurring_work.dart` | `RecurringWork`, `fromHabit`, `fromTask`, `fromTaskWithHistory`, source tagging |

---

## Documentation Changed

**Created:** `docs/ascend-stage-l1-design.md`

**No production code files modified.** No schema changes. No migration execution. No UI changes. No legacy field deletions.

---

## Remaining Open Decisions (Post-L1.1)

| # | Decision | Owner | Blocked By |
|---|---|---|---|
| 1 | Extend `Recurring` or `Task` to host the five legacy capabilities (`targetCount`, `targetDuration`, `cue`, `timeOfDay`, `streakFreezesUsed`) | L1+ product decision | Must resolve before Habit retirement |
| 2 | Migrate `longestStreak` from Habit to Task log-derived value, or document it diagnostic-only forever | L1+ design | Requires product decision on whether Task longest streak matters |
| 3 | Snooze/reschedule full migration to Task side (currently Habit-authoritative) | L1+ implementation | Stage J handles Today/Habits screen routing |
| 4 | Parity-quarantine repair path (auto-fix divergent counters vs manual decision) | L2 design | Requires defined canonical home for each field |
| 5 | Duplicate Task cleanup policy (currently: report only, never delete) | L2 design | Safety: no safe delete mechanism established |
| 6 | Migration marker version bump (currently v1; when/if to bump) | L0/L1 metadata | Only on schema version change, not L1.1 scope |
| 7 | `RecurringWork` exclusion rule for `Habit.taskId != null` — confirmed as design | Stage G/H | Already approved; L1.1 documents it |
| 8 | `longestStreak` display policy post-migration (currently: Habit-stored, Task diagnostic-only) | L1+ product | Depends on #1 and #2 resolution |

---

## L1 Implementation Sequence (Proposed)

The L1 design is **design-only**. The implementation sequence for the actual code changes (when the team is ready) would be:

### Phase 1: Audit & Documentation (L1.1 — complete)
- Produce this design doc (`ascend-stage-l1-design.md`).
- Confirm no production code changes.
- Freeze the 8 audit items as the L1 baseline.

### Phase 2: Read-Path Unification (L1.2 — complete)

One arithmetic, three callers. `RecurringStreak` (`lib/features/recurring/domain/recurring_streak.dart`)
now owns the day-consecutive rule, and the two projections that used to each carry
their own are thin adapters over it:

- `HabitLogProjection` (`streak_parity.dart`) keeps its shape — `parityReportFor`
  and the L0 gate still compare a logged habit against its stored counters — but
  computes `currentStreak`, `longestStreak` and totals through `RecurringStreak`.
- `TaskStreakComputer` (`task_streak.dart`) likewise, and no longer takes a `now`:
  the canonical rule is ageing-free, so there is nothing for a clock to decide.
  A Task is not "due yesterday, so the streak broke".

The Mon/Wed/Fri case is the one the two definitions disagreed on, and it is worth
stating plainly: under the canonical day-consecutive rule a Task completed on
Monday, Wednesday and Friday scores **1**, because Tuesday is missing. It scored 3
under the old scheduled-consecutive rule. `recurring_streak_test.dart` pins that
number so the change cannot be quietly reverted.

Reads wired to the canonical path:

- `ProgressService` — `taskStreaksByCategory`, `recurringStreaksByCategory`,
  `recurringCompletionsByCategory`, `recurringCompletionsByCategoryFromLog`,
  `recurringCompletionHeatmap`, and `habitIdByTaskId` as the ownership map.
- `AnalyticsRepositoryImpl` — takes a `TaskRepository` and resolves every habit read
  through one ownership map over one shared completion log, instead of a per-habit
  query that could not see the other half of a migrated habit.
- `Today` — `weekDayStates`, `weekCompletionCount` and `bestCurrentStreak`.
  `bestCurrentStreak` re-derives a migrated habit from its Task log, because its
  stored counter is frozen at whatever it was on the migration day and never moves
  again.
- `HabitsScreen` — the hero's due count, completed count and progress all read the
  same non-migrated set, so they cannot disagree with each other.
- `recurring_providers.dart` — `taskStreaksByCategoryProvider`.

The ownership rule is the whole point of the stage, and it is one rule:

- `Habit.taskId == null` → its stored counters are still live; read them.
- `Habit.taskId != null` → the Task occurrence log is live; read that.
- Never sum both halves of one logical owner and day.

`longestStreak` stays where L0 put it: the persisted value is the high-water mark,
and the derived value is diagnostic only. Reading it never writes it back. A derived
longest cannot replace the stored one — un-completing today shortens the log while
the mark stays where the user achieved it — which is exactly why the two are not
interchangeable.

Nothing in this phase touches the schema, the migration, the `Habit` or `Task`
entities, or the quarantine behaviour. `kStreakSemanticsDelta` still names both
definitions, because naming the delta is what the gate reconciles; changing the
string would hide the difference rather than resolve it.

### Phase 3: Canonical Legacy Capability Model (L1.3 — complete)

### Canonical Legacy Capability Model

This is the definitive statement of where each of the five legacy `Habit`
capabilities lives after Stage L1.3, why it lives there, how the value gets
there without data loss, and the exact condition under which the legacy
counterpart may be retired.

#### The decision, field by field

| Capability | Canonical home | Boundary | Evidence | Why not somewhere else |
|---|---|---|---|---|
| `targetCount` | `Task.targetCount: int` | per-occurrence target: task-level **configuration** | form label "Target Count"; shown as a >1 badge on the Today list; not consulted by streak, analytics, or due-ness | `Recurring`/`TaskSchedule` model *when*, completion rows record *what happened*; neither owns *how much is aimed for*. Storing it in the schedule would claim it changes due-ness — it does not. |
| `targetDuration` | `Task.targetDuration: Duration` | aimed-at duration of one occurrence: task-level **configuration** | form label "Duration (min)"; shown on the habit card as "N min" | `HabitCompletion.duration` is the *measured* duration; folding the two together would erase the target every time the work is actually finished. Not a Focus session duration either — Focus never reads it. |
| `cue` | `Task.cue: String` | free-text trigger: task-level **metadata** | form label "Cue / Trigger (optional)", e.g. "After brushing teeth" | Nothing derives behaviour from it, so it cannot be a schedule concept. A plain metadata field. |
| `timeOfDay` | `Task.timeOfDay: String` | Morning/Afternoon/Evening presentation & scheduling-*intent* label | label shown on habit card and Today list; **not** consulted by `Recurring`, `dueAt`, `snoozedUntil`, snooze, reschedule, completion or streaks | It reads like a schedule, but promoting it into `TaskSchedule` would have invented behaviour: nothing would consume it, and a `dueAt` that suddenly appeared would change when the item surfaced. L1.3 kept the label on the Task and pinned (by test) that it stays out of scheduling JSON. |
| `streakFreezesUsed` | `Task.streakFreezeUsage: StreakFreezeUsage` | spent **streak state** on the surviving item record, not configuration | incremented only by `HabitController.useStreakFreeze`; displayed as "Use Streak Freeze (N left)" | It is not a schedule, not a completion, and not a target. It is usage *history* with an invariant (the allowance), so it is typed as a value object with `remaining`/`exhausted`/`use()` rather than a bare `int` that any writer could over-spend. |

All five default on `Task` to the legacy defaults (`1`, zero, `''`, `Morning`, `0`).
That is deliberate: a Task written by the Stage L0 build carries none of these
keys, and a keyless Task must read as identical to a *default* `Habit` so the
bridge performs no write for it and only a genuinely customised habit causes a
write. It also means a "completely old" habit record (no capability keys at all)
loads with defaults rather than throwing, and migrates cleanly.

#### The two-writer bridge period

`Task` is now the canonical *home*, but the **Habit remains the writer** until
Stage L2 moves the write path. Nothing has moved the five fields' write site;
the entity, repository, and UI still read and write the `Habit`. The canonical
copy is created and maintained here:

| Mechanism | When | What it does |
|---|---|---|
| `_createTaskFor` (migration) | a Task is first created | writes all five onto the Task (`LegacyHabitCapabilities.applyTo`) so a Task is born complete even if the run dies before the next step |
| `_syncCapabilities` (inside `migrateHabit`) | every path through the state machine, including adopting an older Task | writes the five only if the persisted Task diverges, then `_verify` re-reads and asserts them (`taskCapabilitiesPresent` / `taskCapabilitiesLost`) |
| `MigrationService.syncTaskCapabilities` (the **capability bridge**) | every launch, from `HabitTaskMigrationRunner.runIfRequired` | diff over all linked habits vs their Tasks; writes only on divergence; never creates Tasks, never writes a `taskId`, never writes the Habit |

The bridge is deliberately **not marker-gated**. It is a cheap in-memory diff
(no write on a converged install), and a marker would give a post-L0 install
exactly one launch to be backfilled before the per-launch gate shut forever —
which is the install shape L1.3 exists for. Being diff-based also means a value
edited after migration (the habit form still edits the `Habit`) is picked up
without a second mechanism, and a write that fails is retried next launch.

Idempotence is inherited from the state machine: `_createTaskFor` and
`_syncCapabilities` write only on divergence, `_verify` re-reads persisted state
rather than trusting memory, and `migrateHabit` never double-writes a converged
record. The L1.3 tests pin byte-identical storage across a second migration and
a second launch.

#### Compatibility with the legacy constraint set

- **No legacy field was deleted.** `Habit` keeps all five; `LegacyHabitCapabilities` keeps `matchesHabit` (the legacy side still verifies unchanged).
- **No schema version bump, no marker bump.** `habit_task_migration` stays v1 and `currentSchemaVersion` stays 5. All five Task keys are additive and read with defaults, so older builds that cannot read them are unaffected (their flags simply lookup-default when a newer build writes).
- **No history rewrite.** Copying capabilities never touches completion rows, streak counters, `longestStreak`, schedule, or `taskId`. Documentation suggesting a `targetCount` > 1 means "a row per tap" is **aspirational, not behaviour** — `completeHabit` refuses a second same-day completion — and L1.3 did not change it.
- **No new freeze effect.** `useStreakFreeze` still only increments; no read path consults the value to protect a chain. The move is of the *number*, not the semantics, and that gap is pinned by test rather than darkened.
- **No UI change.** The habit form and cards still read/write the `Habit`.

#### Retirement condition (Stage L2+ corollary)

The five `Habit` fields may be retired **together with (or after) the write-path
migration**, and not before. Before any production read switches from the
`Habit` to the `Task`, the writer for each of the five must move to the Task
side, or the legacy copy — still the only thing the form edits — will drift
ahead of canonical values and the next divergence check will overwrite
canonical with stale legacy data. The bridge methods
(`_syncCapabilities`, `syncTaskCapabilities`) are the specifically-named removal
point: they exist to carry the value across the gap, and their existence after
the writer moves is the bug. `LegacyHabitCapabilities` then drops `matchesTask`/
`fieldsLostFromTask`/`applyTo`, and the `Habit` fields are removed by the
deletion gate.

#### What verification now proves

`MigrationVerification` gained two assertions (beside the L0 legacy-side one):

- `taskCapabilitiesPresent` — the persisted Task reads back all five values.
- `taskCapabilitiesLost` — the field names that did not, so a failure names the lost capability.

Both are asserted against re-read persisted state, so a migration that preserved
the Habit but never wrote the Task — the exact "moved a field and silently
dropped it" failure — now fails verification instead of looking clean.

#### Data-loss risk register

| Risk | Mitigation |
|---|---|
| Post-L0 install (marker set, Tasks keyless) never gets capabilities | the bridge runs on every launch |
| Edit after migration leaves canonical stale | the bridge is diff-based; picks it up next launch |
| Partial/interrupted capability write | `migrateHabit` syncs before every verify; the bridge converges on retry |
| Bridge overwrites canonical with stale legacy | disabled by construction today (legacy is the writer); the retirement condition above names when it must be deleted |
| Dangling `taskId` | the bridge reports `unmatched` and never fabricates a Task; recovery stays with the L1.4 state machine |
| Corrupt/missing habit keys | habit deserialiser reads the five tolerantly (defaults) instead of throwing |

#### Tests

- `test/features/tasks/domain/streak_freeze_usage_test.dart` — the value object.
- `test/features/recurring/l1_3_capability_ownership_test.dart` — 29 tests over the real repositories: field ownership and defaults, persistence round-trip, migrate-and-verify, completely-old records, L0-shaped backfill behind the marker, partial top-up, failed-write surfaced with retry convergence, mixed datasets, no-write convergence, targetCount/duration as configuration vs history, `timeOfDay` staying out of scheduling, freeze usage survival and allowance.

### Phase 4: Parity-Gate and Migration Prerequisites (L1.4 — complete)

**What L1.4 hardened, before any final history cutover:**

- **The parity gate must fail loudly, not look empty.** A completions read
  failure now throws `StateError`, symmetric with the habits read: an
  unreadable log must not read as "every log is empty" and quarantine the whole
  install behind a fake parity finding. The gate still performs no writes and
  quarantines on genuine divergence.
- **Deterministic identity is asserted, not assumed.** `MigrationVerification`
  gained `deterministicIdentity`: a Task this run *created* must carry
  `HabitTaskIdentity.taskIdForHabit(...)`, else the check fails (`created Task
  id is not deterministic`). Adopted Tasks (an older attempt's random-id copy)
  are exempt — the check is scoped to what this run introduced, so a retry
  after a lost link can always rediscover the Task.
- **Marker write is an injectable boundary.** `HabitTaskMigrationRunner.writeMarker`
  is a `@visibleForTesting` method so a marker that fails to land is testable;
  the contract it upholds is unchanged — the marker records *completion* and is
  written only when every eligible habit verifies, so an absent/partial write
  reads as unmigrated and the next launch retries.
- **Dangling-`taskId` recovery** (missing Task, malformed/partial capability
  data, deterministic Task, older random-id Task adoption) is exercised across
  repeated launches. Recovery never fabricates duplicates and never auto-deletes;
  duplicates are reported on the outcome.
- **Idempotency across launches** is pinned by test: after the first run every
  later launch performs no habit/task/completion writes (marker short-circuit +
  diff-based bridge), streak counters, legacy rows, and unrelated Tasks stay
  byte-identical, and no duplicate rows appear over any number of runs.
- **Failure/crash injection** at each write boundary (Task creation, completion
  copy part-way, verification, marker write, capability-sync write) leaves the
  marker absent, the install retryable, and a healthy retry converges without
  duplicating work.
- **Parity quarantine preserved**: quarantined habits still do not block the
  marker (`quarantined` recorded in it), are never claimed migrated, stay
  byte-identical, and remain detectable by the gate on later launches.
- **Data safety** asserted: copied rows are owner-isolated (`habitId` null,
  `itemType` task), habit-scoped reads are unchanged, no double counting, and
  the capability bridge stays retryable.

Unchanged and deferred to Phase 5+ (as before): moving the five writers to
Task, deleting the bridge, the parity-quarantine repair workflow, and
Habit/Task retirement. No marker bump, no schema bump, no field deletions.

#### Tests

- `test/features/recurring/l1_4_parity_hardening_test.dart` — 21 tests in six
  groups over the real repositories: per-habit parity-checklist/sabotage matrix
  (incl. `deterministicIdentity` and the completions-read throw), dangling-
  `taskId` recovery (incl. orphan adoption and malformed capability data),
  repeated-migration idempotency matrix, failure/crash injection, parity-
  quarantine preservation, and data-safety assertions.

### Phase 5: Write-Path Migration (L2+)
- Add `TaskController.completeTask` / `uncompleteTask` (already designed in Stage H).
- Modify `HabitController.completeHabit`/`uncompleteHabit` to delegate when `taskId != null`.
- Remove dual-write once all consumers route through Task side (Stage J).

### Phase 6: Full Retirement (L7+)
- Delete `Habit` entity, `HabitController`, `HabitsScreen` (kept for legacy only).
- Remove `habitsKey` / `habit_completions` from storage after 3–6 verified on real installs.
- Bump schema version.

**Each stage is independently shippable and revertable. No stage below deletes anything.**

--- 

**End of design document.**