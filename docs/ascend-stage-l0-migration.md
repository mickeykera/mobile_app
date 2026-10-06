# Stage L0 — Safe Habit → Task migration foundation

Status: **complete**
Predecessor: `docs/ascend-stage-l-habit-retirement.md` (verdict:
`REQUIRES INTERMEDIATE MIGRATION`)
Successor stage: **L1** — not started, not authorised by this document.

Stage L0 does not retire anything. It makes the existing migration production-safe
so that Stage L1 can start cutting readers over to `Task` on real data.

---

## 1. Scope

In scope:

- Deterministic, resumable, idempotent migration from `Habit` to `Task`.
- Explicit per-habit outcomes and post-write verification.
- Archived habit handling.
- An explicit, recorded decision for each capability that has no `Task` home.
- A production execution point that runs once per install and retries when it
  did not actually finish.
- Tests for the seventeen required scenarios, plus failure-path coverage.
- Correction of documentation that describes the old behaviour.

Out of scope, and untouched by this stage:

- Deleting `Habit`, `HabitCompletion`, `HabitRepository`, `HabitController`, the
  legacy `habits` / `habit_completions` storage, or any UI that reads them.
- Schema changes. Schema version is unchanged at `5`.
- Any change to Analytics, Progress, or streak computation.
- Unrelated architecture, the rest of the feature work, or `RecurringWork`.

---

## 2. The two defects that made the migration unusable

Both were found while implementing L0, and both had to be fixed before any of the
acceptance criteria could be met. They are recorded here because they explain why
the original code could not simply be switched on.

### 2.1 `Habit.taskId` was never persisted

`taskId` existed on the `Habit` entity but appeared in neither `_habitToJson` nor
`_habitFromJson`. Every habit therefore read back with `taskId == null`, and
`updateHabit(habit.copyWith(taskId: ...))` silently discarded the link.

This alone made the migration non-idempotent across process restarts: each launch
would find no link, create another `Task`, and the user's history would fork. The
Stage L audit read the old migration as idempotent because the code path is
idempotent *within a single process*, where the in-memory object still holds the
value it just wrote.

Fixed in `lib/features/habits/data/repositories/habit_repository_impl.dart`.
Records written before the fix load unchanged, since an absent key reads as
`null`.

### 2.2 `getOrNull()` threw instead of returning null

`ResultGetOrNull.getOrNull()` was implemented as
`fold((_) => null as T, (value) => value)`. For any non-nullable `T` — which is
most of them, including `List<Habit>` — that cast raises a `TypeError`, so the
"safe null" accessor crashed rather than reporting a handled failure.

It had never surfaced because every existing call site happened to return a
nullable `T` (`Task?`, `Habit?`), where the cast succeeds. Fixed to read
`Either.right` directly. This matters for L0 specifically: §8 relies on being
able to distinguish "the read failed" from "the list is empty".

---

## 3. Execution path

```
main()
  └─ AscendApp (ConsumerStatefulWidget)
       └─ _initialize()                    ← the one future that gates the first frame
            ├─ DatabaseService.initialize()
            └─ HabitTaskMigrationRunner.runIfRequired()
                 ├─ marker present?  → return skipped
                 └─ MigrationService.runFullMigration()
                      ├─ runParityGate()            (no writes)
                      └─ migrateHabits(eligible)   (writes, then verifies)
```

`lib/app/app.dart` owns the future; `lib/features/recurring/domain/migration_runner.dart`
is the production entry point.

The runner is awaited rather than fired in the background, deliberately:

- `habitRepositoryProvider` and `taskRepositoryProvider` are cached providers, and
  each repository memoises its JSON list into an in-memory cache on first read. A
  background migration would write through a *different* instance than the UI
  reads, and the last writer wins — which, given the write is `taskId`, is a lost
  update.
- Running first means a half-migrated dataset is never rendered. The bridge paths
  already tolerate `taskId == null`, so this is belt-and-braces rather than a
  correctness requirement.

Cost is bounded and paid once: a fully migrated install reads one key and stops.

The migration is **not** wired into the debug parity gate. That provider exists to
exercise the gate on demand; production entry is the startup path above.

---

## 4. Marker and retry semantics

Marker: key `habit_task_migration`, version `1`. Schema version is untouched —
this is an additive key in existing storage, not a migration of the schema itself.

`isComplete` is `marker.version == 1`. A version bump re-runs the migration; the
idempotency in §6 is what makes that safe.

**The marker records completion, so it is written only when every eligible habit
verifies.** A run that produced a failure or an unverified outcome leaves the
marker absent, and the next launch retries. Writing it unconditionally would
retire the migration with the work unfinished and the retry would never happen.

Quarantined habits (§5) do **not** block the marker. They are a deliberate hold
awaiting a parity decision, not a failed write, and retrying them forever would
never resolve them.

`runIfRequired` never throws. A failure leaves the marker absent and the app
starts normally on unmigrated data, which is where every install already is and
which the legacy code paths handle correctly.

---

## 5. Parity gate

`runParityGate` includes archived habits by default. The Stage L audit found the
old gate called `getAllHabits()` with the repository default of
`includeArchived: false`, so archived habits were never gated, never copied and
never linked — and would have been dropped outright at retirement.

A habit is eligible when `HabitLogProjection` agrees with its stored counters.
Otherwise it is quarantined with its `ParityVerdict` recorded, and left
completely untouched.

**A read failure is not an empty install.** The gate throws if habits cannot be
read. Reporting "nothing to do" on a failed read is the worst available outcome:
it looks like a clean pass, and the runner would write its completion marker over
an install whose habits it never actually saw.

---

## 6. Identity, determinism and idempotency

`lib/features/recurring/domain/habit_task_identity.dart`:

| | id |
|---|---|
| `Task` for a habit | `task_hm_<habitId>` |
| copied completion row | `completion_hm_<legacyCompletionId>` |

Both are pure functions of stable inputs, so two runs on the same data produce
byte-identical records. Nothing in the migration uses a fresh random id.

Per-habit state machine, in resolution order:

1. `Task` exists under the deterministic id, and the habit already links to it →
   `alreadyMigrated`, no writes.
2. `Task` exists under the deterministic id but the link is missing or different →
   deterministic id, link rewritten.
3. Habit links to a `Task` that **exists** under a different id (an older
   attempt's random id) → `existingLink`, adopt that `Task`.
4. Habit links to a `Task` that **no longer exists** → dangling: clear the link,
   then `recoveredDanglingLink`; the replacement `Task` is created or adopted.
5. No link, no deterministic `Task`, but a `Task` matches the habit's content and
   is unclaimed by any other habit → `logicalAdoption`, adopt the lowest id.
6. Otherwise → create the `Task` under the deterministic id.

`createdTask` is keyed off `identitySource`, not off `state`. The most specific
state wins, so a dangling recovery that then creates a `Task` reports
`recoveredDanglingLink` — a `state == migrated` check would undercount the run.

**Adoption does not double history.** When an older attempt already copied
occurrences into a `Task` under random ids, an id-based check finds nothing to
dedupe against and re-copies every row, doubling that `Task`'s history and
inflating its streak. Occurrences are therefore matched on *day + count +
duration*, which recognises what an earlier attempt wrote while still letting
two genuinely distinct same-day rows through. Verification uses the same
occurrence identity, so preserved history is not misreported as missing.

---

## 7. Verification

Every migrated habit is verified by re-reading **persisted** state. Trusting the
in-memory object would verify nothing: it is the copy the migration just wrote.

| Check | Guards against |
|---|---|
| `linkPersisted` | the link write being silently dropped |
| `taskExists` | the `Task` write not landing |
| `taskIsRecurring`, `schedulePreserved` | recurrence lost or flattened |
| `projectIdPreserved`, `goalIdPreserved` | scope lost in the move |
| `archivedStatePreserved` | an archived habit resurfacing as live work |
| `legacyCapabilitiesPreserved` | any of the five fields being lost |
| `streakCountersPreserved` | the migration restating the user's history |
| `historyPreserved` | occurrences missing from the `Task` |
| `noDuplicateLogicalTask` | this run creating more than one `Task` |

`noDuplicateLogicalTask` is scoped to *this run*: it created at most one `Task`.
Duplicates left by an older attempt are a pre-existing condition, reported on the
outcome as `duplicateTaskIds` rather than counted as a fresh failure — otherwise
adopting one would read as a failure and a retry would never converge.

`linkPersisted` is verified as its own condition rather than inferred from the
`Task` having been created, because a dropped `taskId` looks identical to success
until the next launch starts the whole thing over.

---

## 8. Capability decisions

`Task` has no representation for five user-entered fields. Each decision is
recorded explicitly; none is silent loss.

| Capability | Decision | Where it lives |
|---|---|---|
| `targetCount` | **legacy-only** | retained on `Habit` |
| `targetDuration` | **legacy-only** | retained on `Habit` |
| `cue` | **legacy-only** | retained on `Habit` |
| `timeOfDay` | **legacy-only** | retained on `Habit` |
| `streakFreezesUsed` | **legacy-only** | retained on `Habit` |

Rationale: `Task` has no field to hold any of them. Inventing a lossy mapping
(e.g. `targetCount` → `schedule.every`) would change scheduling behaviour as a
side effect of a data migration. Because Stage L0 retains the `Habit` record
untouched, the legacy-only choice is lossless *today*, and it is reversible: the
fields are all still there when L1 gives them a home.

`LegacyHabitCapabilities` makes the decision typed and testable, and
`fieldsLostFrom` turns it into a verification condition rather than a comment.

L1 must resolve these before any UI reads a migrated `Task`, or a user who set
"3x per day" sees a habit that only ever asks for one.

---

## 9. Completion history

The legacy rows stay canonical and are **not** deleted. Copies are written to the
`Task` with `habitId: null` and `itemType: 'task'`, which is the existing
discriminator the codebase already uses for Task occurrences.

This is a copy, not a move, and it is deliberate at this stage: the legacy rows
are what the legacy UI reads, and deleting them would be irreversible while
`Habit` is still live.

---

## 10. Analytics strategy

**No production Analytics change is required at L0.** The copied rows are already
invisible to every habit-scoped read:

- `ProgressService` filters on `ownerId == habitId` / `isHabitCompletion`.
- `AnalyticsRepositoryImpl.getCompletionHeatmap` filters on `habitId == habitId`.

Both exclude a row with a null `habitId`, so a migrated habit's heatmap, streaks
and correlations are unchanged by the copy.

This corrects the Stage L audit, which listed double-counting as a realised
blocker. It would become real at L1, when a migrated habit's numbers are read
from the `Task` side while the legacy rows still exist — so the two representations
must not both be summed. The regression test in
`test/features/recurring/domain/migration_l0_test.dart` pins the current
behaviour so the invariant cannot be lost silently.

---

## 11. Streak strategy and L1 gate

`HabitLogProjection` counts **day**-consecutive streaks and counts total
completions as distinct days. `TaskStreakComputer` counts
**scheduled**-consecutive streaks and sums `count` across rows. The two disagree
by design, and a Mon/Wed/Fri habit with a 3-day streak reports 1 on the Task side.

L0 does not reconcile this. The migration **does not touch `currentStreak`,
`longestStreak` or `totalCompletions`**, and `streakCountersPreserved` fails
verification if anything does. It moves storage; it does not restate numbers.

The reason this is safe at L0: `taskStreaksByCategory` has **no production
caller**. No user-visible number is derived from `TaskStreakComputer` yet, so the
semantic gap is currently unreachable. The Stage L audit described it as visibly
changing a displayed number; that is true of the eventual L1 wiring, not of
today's build.

L1 must decide which definition the user sees, and migrate the stored counter to
match. `kStreakSemanticsDelta` records the gap in code.

---

## 12. Schema

Unchanged. Version `5`.

No data is deleted, no key is repurposed, and the marker is a new additive key.
The `habits` and `habit_completions` lists keep their existing shape; `taskId` is
newly serialised *within* the existing `habits` record, which older readers ignore
because they only read keys they know.

---

## 13. Non-goals

- No retirement, deletion or deprecation of any `Habit` type, repository,
  controller, storage key or screen.
- No UI change.
- No streak, Analytics or Progress behaviour change.
- No `RecurringWork` change beyond correcting documentation that described the
  old behaviour.
- No unrelated refactoring.

---

## 14. Test coverage

`test/features/recurring/domain/migration_l0_test.dart` runs against real
repository implementations over mocked `SharedPreferences`, so every assertion
below is about persisted state, not about an in-memory object.

| # | Scenario |
|---|---|
| 1 | Clean habit → one `Task`, linked, history copied |
| 2 | Repeated runs append nothing; no `Task` created on a second pass |
| 3 | Interrupted mid-migration resumes and converges |
| 4 | Valid `taskId` + valid `Task` is not touched |
| 5 | Dangling `taskId` is cleared and re-migrated |
| 6 | Unlinked random-id `Task` is adopted by content; a `Task` claimed by another habit is not stolen |
| 7 | Duplicate logical `Task`s are reported, not deleted |
| 8 | Archived habits are gated, become archived `Task`s, and an active habit never yields an archived `Task` |
| 9 | All five capabilities survive |
| 10 | History is complete, unmutated and not duplicated |
| 11 | Analytics heatmap is byte-identical before and after |
| 12 | Streak counters unchanged; semantics delta recorded |
| 13 | Verification passes cleanly; a lost write fails and names the cause; a missing habit fails without throwing |
| 14 | A read failure is reported, not silently treated as "nothing to do" |
| 15 | Multiple habits each get their own `Task`; a quarantined habit is left alone |
| 16 | An empty install is a clean no-op |
| 17 | An already-migrated relaunch verifies without rewriting anything |
| — | `taskId` survives a reload; a record written without it loads as `null` |
| — | Runner: runs once, short-circuits on the marker, records quarantine, needs no UI |
| — | Marker integrity: no marker after an unverified run, and a healthy retry converges |

`test/features/recurring/domain/migration_test.dart` — the pre-existing suite,
extended so the dangling-`taskId` case asserts recovery instead of skipping.

---

## 15. Known failures outside this stage

`flutter test` is green except for ten pre-existing failures, none of which
involve migration code and none of which this stage introduced:

- **Six** in `test/features/habits/presentation/habits_screen_smoke_test.dart`
  ("Non-migrated Habits" group). Cause: a Flutter SDK assertion — *"ListTile
  background color or ink splashes may be invisible"* — fired by the
  `ListTile`s inside the actions sheet in `habits_screen.dart`. A framework
  version issue in a file this stage did not touch.
- **Four** golden tests in `test/render/full_suite_test.dart`
  (`habits_phone_dark`, `habits_phone_light`, `habits_tablet_dark`,
  `habits_tablet_light`). `test/render/goldens/` is untracked and was never
  regenerated after the previous stage's theme restyle, so the habits baselines
  are stale. The other eight screen goldens match.

`flutter analyze` reports zero errors. The three remaining `lib/` warnings are
pre-existing, in `habits_screen.dart` (two unused private methods) and
`tasks_screen.dart` (one unused local), all in files this stage did not touch.

---

## 16. L1 blockers

Stage L1 must not begin until each of these has a decision:

1. **Streak semantics.** Which definition does the user see after migration, and
   how is the stored counter converted? `longestStreak` is a high-water mark the
   log cannot reconstruct; it is currently irrecoverably lost at cutover.
2. **The five legacy-only capabilities.** Each needs a `Task` home, or an explicit
   product decision to drop it. They are preserved today only because the
   `Habit` record survives.
3. **No double counting at cutover.** §10 is safe now because habit-scoped reads
   filter Task rows out. When a migrated habit is read from the `Task` side, the
   two representations must not both be summed.
4. **Parity quarantine resolution.** The migration deliberately holds habits whose
   log disagrees with their counters. They need a repair path, not another retry.
5. **Duplicate `Task` cleanup policy.** Extras from older attempts are reported on
   `duplicateTaskIds` and left alone. Deciding what to do with them is a product
   decision, and deleting user-visible `Task`s is not L0's call.
6. **Marker version bump.** Any change to the identity scheme needs
   `_markerVersion` incremented, which re-runs the migration under the §6
   idempotency guarantees.
