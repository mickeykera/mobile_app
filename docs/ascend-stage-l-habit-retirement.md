# Stage L — Habit Retirement Design Audit

**Status:** design/audit only. No production code, schema, migration behaviour, or
tests were changed to produce this document.

**Question:** can the legacy `Habit` architecture be retired — entity, completion
log, controller, repository, dual-source abstraction — without losing user data or
changing what the user sees?

---

## 1. Executive conclusion

Retirement is **not** a deletion job. The bridge scaffolding for retiring `Habit`
is well built and mostly wired, but three things block it today:

1. **The migration has never run.** `MigrationService.runFullMigration` and
   `copyEligibleToTasks` have **zero production callers**. Only `runParityGate`
   is exposed, via `migrationReportProvider`
   (`lib/features/recurring/presentation/providers/recurring_providers.dart:127`).
   Every real install therefore still holds 100% legacy habits with
   `taskId == null`, and the code paths that make migrated habits behave like
   Tasks are dormant.
2. **The migration as written is not safely resumable and not verifiable.** It
   creates the Task before it writes the `taskId` link, and it treats
   `taskId != null` as proof of migration without checking the Task exists.
   (§7)
3. **`Task` cannot express six live `Habit` capabilities**, and the two streak
   models do not agree on what a streak *is*. Retiring the entity without
   resolving these silently changes numbers the user is shown. (§14)

Nothing here requires a rewrite. It requires an intermediate migration stage that
closes the verification gaps, resolves the capability gaps by explicit product
decision, and only then unwinds the dual-source abstraction.

---

## 2. Scope and method

**In scope.** Every reference to `Habit`, `HabitCompletion`, `HabitRepository`,
`HabitController`, and the recurring-work abstraction across `lib/` and `test/`;
the persistence shape of both stores; the correctness of the existing
Habit→Task migration.

**Method.** Read the actual working tree (not prior stage summaries). Enumerated
importers and symbol references, then read each dependent's call sites to
establish what it reads and what it writes.

**Out of scope.** Analytics and Focus correctness beyond their Habit coupling;
UI redesign; performance; anything requiring a code change to answer.

---

## 3. Dependency map

13 files outside `lib/features/habits/` import the habits feature. Of those, 5 are
real behavioural dependencies and 8 are comments or unrelated names.

### Real behavioural dependencies

| Consumer | Coupling | Classification |
|---|---|---|
| `recurring/domain/migration.dart` | Reads all habits + full log; writes Tasks, task completion rows, `taskId` | **Migration infrastructure** |
| `recurring/domain/recurring_work.dart` | `RecurringSource.habit` vs `.recurringTask`; builds both lists into one | **Required legacy compatibility** |
| `recurring/domain/streak_parity.dart` | Re-derives `Habit` counters from the log | **Required legacy compatibility** (pre-cutover gate) |
| `recurring/domain/task_streak.dart` | Derives Task streaks from the same `HabitCompletion` rows | **Current product usage** |
| `tasks/presentation/controllers/task_controller.dart` | Writes/deletes Task occurrence rows through `HabitRepository` | **Current product usage** |
| `analytics/data/repositories/analytics_repository_impl.dart` | Aggregates habits, per-habit heatmaps, `ownerId` correlations | **Current product usage — retirement-blocking** |
| `progress/domain/services/progress_service.dart` | Category/streak/day-set projections over habits + log | **Current product usage — retirement-blocking** |
| `today/domain/today_summary.dart` | Habit due-ness, plus task occurrence overlay for migrated | **Current product usage** |
| `today/presentation/screens/today_screen.dart` | Drives `HabitController` completion writes | **Current product usage** |
| `recurring/presentation/providers/recurring_providers.dart` | Composes both sources; hosts the parity + migration providers | **Required legacy compatibility** |
| `app/router.dart` | `/habits` → `HabitsScreen` | **Current product usage** |

### Non-dependencies (verified false positives)

`app/theme/app_colors.dart`, `app/widgets/glow_button.dart`,
`app/widgets/mini_week_strip.dart`, `core/constants/category_type.dart` (habit
*category colours*), `projects/presentation/controllers/project_controller.dart`
(comment), `tasks/domain/value_objects/task_schedule.dart` (doc reference),
`analytics/domain/analytics_repository.dart` (`getHabit*` method names),
`analytics/presentation/screens/analytics_screen.dart`, `focus/*`.

### Not a blocker

`focus_session.dart:25` carries `habitId` as an optional **`String?`**, persisted
as a raw string and filtered by equality
(`focus_repository_impl.dart:171,183`). It never loads a `Habit`. Retirement
leaves these as soft dangling references — a data-hygiene item, not a
compilation or correctness blocker. See §16, Stage 6.

---

## 4. Read inventory

| Reader | Reads | Via |
|---|---|---|
| `recurringWorkProvider` | `habitsProvider` + `taskControllerProvider.tasks` | `recurring_providers.dart:18` |
| `recurringWorkForProjectProvider` | same, filtered by project | `:31` |
| `recurringSourceCountsProvider` | same, counted by source | `:44` |
| `streakParityReportProvider` | habits + `getAllCompletions()` | `:70` |
| `taskOccurrenceTodayProvider` | `getAllCompletions()`, filters `itemType=='task'` | `:101` |
| `migrationReportProvider` | `runParityGate()` → habits + all completions | `:127` |
| `AnalyticsRepositoryImpl` | `getAllHabits(includeArchived: true)`, per-habit `getCompletionHeatmap(habit.id)`, `getCompletionsForHabit` | `analytics_repository_impl.dart:44,103,128,141` |
| `ProgressService` | `List<Habit>` + `List<HabitCompletion>` | `progress_service.dart:81,95,119,131,155` |
| `todaySummary` | habits + completions; keys migrated completion as `task:${taskId}` | `today_summary.dart:65,82,105,143` |
| `HabitsScreen` | `habitControllerProvider`, split providers, migrated completions | `habits_screen.dart:56-67` |
| `dueHabitsProvider` / `todaysProgressProvider` | controller state only | `habit_providers.dart:60,65` |

Every read above is served from in-memory caches hydrated once from
SharedPreferences (`HabitRepositoryImpl._ensureLoaded`, mirrored in
`TaskRepositoryImpl:20`).

---

## 5. Write inventory

| Writer | Legacy path | Task path |
|---|---|---|
| `HabitController.completeHabit` | habit row + counter update | **already delegates** to Task occurrence when `taskId != null` (`habit_controller.dart:279-284`) |
| `HabitController.uncompleteHabit` | deletes habit row, reverts counters | **already delegates** to Task occurrence delete (`:340-345`) |
| `MigrationService.copyEligibleToTasks` | — | creates Task, creates task rows, writes `taskId` (`migration.dart:143,159,164`) |
| `HabitRepositoryImpl.reconcileHabitToTask` | — | backfills missing task rows by day (`:503+`) |
| `TaskController` | — | records/deletes Task occurrences through `HabitRepository` |

The write bridge is the healthiest part of the design: completion routing already
keys off `taskId`. Retirement's write risk is therefore concentrated entirely in
the *migration*, not in the runtime path.

---

## 6. Persistence layer

| | `HabitRepositoryImpl` | `TaskRepositoryImpl` |
|---|---|---|
| Key | `DatabaseService.habitsKey` = `'habits'` | `tasksKey` = `'tasks'` |
| Shape | JSON list, cached in `_habits` | JSON list, cached in `_tasks` |
| Load guard | memoised `Future<void>? _loading` | same (`:16`) |
| Sort | `sortOrder` | `sortOrder` |

`habit_completions` is a **single shared log** for both entity kinds. Ownership
is discriminated at read time, not by separate storage:

- `itemType == 'habit'` with `habitId` set → legacy habit row
- `itemType == 'task'` with `habitId == null`, `itemId = taskId` → task occurrence
- `HabitCompletion.ownerId` and `isHabitCompletion` are the fallback path for
  rows written before `itemType` existed

Schema is at `currentSchemaVersion = 5` (`lib/core/database/database.dart:18`).
`tasks` was seeded at v3→v4; `habits` at v4→v5. `taskId` is documented as an
additive optional field requiring no rewrite of existing rows
(`database.dart:78-81`) — correct, and it means **no migration pass has ever
needed to touch a stored habit**. That is also precisely why nothing has been
migrated yet: the schema was prepared, the backfill was never invoked.

---

## 7. Migration completeness assessment

This is the section that decides the verdict.

### 7.1 It has never been executed

`copyEligibleToTasks` and `runFullMigration` appear only in
`test/features/recurring/domain/migration_test.dart`. Production reaches only
`runParityGate`. **There is no shipped code path from app launch to a migrated
habit.** The `migratedHabitsProvider` / `recurringTasksFromMigratedHabitsProvider`
/ `migratedHabitTaskCompletionsProvider` chain and the `HabitController`
`taskId` delegation branches all resolve to empty sets on every real device.

### 7.2 `taskId != null` is trusted as proof of migration

```dart
if (habit.taskId != null) continue;   // migration.dart:119
```

No lookup of the referenced Task. A habit whose Task was deleted — or one whose
`taskId` was written by a partial run — is **permanently excluded** from
re-migration while its data has no canonical home. Nothing in the codebase can
distinguish "migrated" from "linked to nothing".

### 7.3 Non-atomic create-then-link leaves a duplicate-Task window

Order of operations per habit:

1. `createTask(task)` — `migration.dart:143`
2. `createCompletion(...)` × N — `:159`
3. `updateHabit(habit.copyWith(taskId: taskId))` — `:163-164`

A crash or process kill between step 1 and step 3 leaves a fully created Task
with copied history and **no link on the habit**. The next run sees
`taskId == null`, skips nothing, and creates a **second** Task. The doc comment
claims "All operations are idempotent and resumable" (`migration.dart:61-62`);
that claim holds only for a clean run, which the test at `migration_test.dart:349`
does verify, but not for an interrupted one.

There is also no post-copy verification and no rollback. A write that reports
success is never re-read to confirm the target exists.

### 7.4 Archived habits are invisible to the migration

`runParityGate` calls `getAllHabits()` with no argument
(`migration.dart:74`), and the default is `includeArchived: false`
(`habit_repository_impl.dart:155-156`). Archived habits are therefore never
gated, never copied, never linked — and their completion rows stay legacy
forever. On retirement they have no destination.

Conversely, when a habit *is* copied, the Task is hard-coded to
`status: TaskStatus.todo` (`migration.dart:135`). `isArchived` has no mapping in
the other direction, so had archived habits been in scope they would have been
**resurrected as active tasks**.

### 7.5 Legacy rows are copied, never removed — and the two copy paths disagree

`copyEligibleToTasks` copies **every** legacy row (`:146-160`) and deletes
nothing. `reconcileHabitToTask` instead indexes task rows **by day** and
backfills only missing days (`habit_repository_impl.dart:520-535`), collapsing
same-day multiples.

So the two paths produce different row counts from the same history, and
whichever ran last determines the totals. Because both keep the legacy rows,
a migrated habit has **two** logical records of the same completion.

This directly corrupts Analytics, which reads `includeArchived: true` and counts
per-habit log rows matched by `ownerId` (`progress_service.dart:95-116`,
`analytics_repository_impl.dart:141`). Migrated completions are counted twice in
the heatmap, category totals, and mood/energy correlations.

### 7.6 Sorting collision

`sortOrder` is copied verbatim from the habit (`migration.dart:136`) into a list
already populated with task sort orders. Both stores sort by that field, so
migrated items land at arbitrary positions relative to existing tasks.

---

## 8. `Habit` entity retirement

`habit.dart` declares 24 fields. Mapping into `Task`:

| Habit field | Task destination | Fidelity |
|---|---|---|
| `id` | new generated `taskId` | **lost** — identity changes |
| `title`, `description`, `projectId`, `goalId`, `category`, `createdAt`, `sortOrder` | same-named `Task` fields | preserved (`migration.dart:129-140`) |
| `frequency` + `customWeekdays` | `Recurring(rule)` via `habit.recurringSchedule` | preserved |
| `dueAt`, `snoozedUntil` | `Recurring.dueAt` / `.snoozedUntil` (`habit.dart:127-131`) | **preserved** — the single best-fidelity part of the mapping |
| `updatedAt` | `AppClock.now()` | rewritten |
| `isArchived` | `status: todo` | **lost** (§7.4) |
| `targetCount`, `targetDuration`, `cue`, `timeOfDay`, `streakFreezesUsed` | — | **no destination** (§14) |
| `currentStreak`, `longestStreak`, `totalCompletions`, `lastCompletedAt` | derived, not stored | **semantics change** (§14.1) |
| `taskId` | — | the retirement marker itself |

The entity is freezed, so retiring it also retires `habit.freezed.dart` and every
`copyWith` call site, including the counter arithmetic in
`Habit._calculateNewStreak` (`habit.dart:219`).

---

## 9. `HabitCompletion` retirement

This is the **hardest** item and the reason retirement cannot be a single stage.

`HabitCompletion` is not a habit-owned type — it is the app's single polymorphic
activity log, shared by habits, task occurrences, and (by field) focus-adjacent
data. Retiring "the habit completion" therefore means retiring *the log*, or
splitting it, and both are large.

`TaskStreakComputer` (`task_streak.dart:24`) and `HabitLogProjection`
(`streak_parity.dart:110`) both take `List<HabitCompletion>`. `TaskRepository` has
no completion storage of its own: task occurrences live in
`habit_completions` and are reached only via `HabitRepository`. **Task streaks are
structurally dependent on the type Stage L proposes to retire.**

`getCompletionsInRange` (`habit_providers.dart:37`) is the shared week-range read
behind both the Today week strip and the migrated-task completion map.

---

## 10. `HabitController` retirement

`HabitController` still owns: habit CRUD, archive/unarchive, snooze/reschedule,
the counter arithmetic, the selected-date state machine, and the single-day
completion cache. Retirement requires moving `selectedDate` somewhere real — Today
and Habits both drive completion through it — before the controller can go.

The `taskId` branches (`habit_controller.dart:279-284, 340-345`) are the
retirement seam and are already correct.

---

## 11. `RecurringWork` and streak infrastructure

`recurring_work.dart` models `RecurringSource.habit` and
`.recurringTask` as first-class sources, with a shared projection consumed by
three providers. Retiring `Habit` collapses this to one source: the `habit`
branch, `RecurringSource.habit`, and the merge logic become dead weight, and
`recurringSourceCountsProvider` — whose stated purpose is to drive the legacy
count to zero — loses half its meaning.

`streak_parity.dart` is a **pre-cutover instrument**. It exists to answer "can
this habit's counters be trusted?" and is meaningless once no habits remain. It
should be kept through the migration, then retired — not before.

`task_streak.dart` is current product usage and stays.

### Stale documentation that will misdirect Stage 4

The `RecurringSource.recurringTask` doc comment (`recurring_work.dart:20-23`)
states that `occurrenceRecorded` "is false for every one of these today: a
recurring task records an occurrence by flipping its own `status` to `done`,
which leaves no history behind", and calls this "the largest single obstacle to
convergence and the reason Stage G stops where it does."

**That comment is no longer true.** Occurrence rows *are* now written —
`TaskController` records them through `HabitRepository` (§5) — and
`fromTaskWithHistory` (`recurring_work.dart:121-150`) reads them, with
`occurrenceRecorded` derived as `lastCompletedAt != null` (`:156-157`). The
stated blocker has already been lifted by later work; only the comment is stale.

This matters here because §16 Stage 4 collapses `RecurringWork` to a single
source. Anyone planning that stage from this comment would budget for engineering
work that is already done.

---

## 12. Infrastructure and providers

| Provider | Disposition |
|---|---|
| `habitRepositoryProvider` | **stays** — still the owner of the shared completion log and task occurrences |
| `habitControllerProvider` | retire last |
| `habitsProvider`, `todaysCompletionsProvider`, `dueHabitsProvider`, `todaysProgressProvider` | retire with controller |
| `nonMigratedHabitsProvider`, `migratedHabitsProvider` | converge to one list, then retire |
| `recurringTasksFromMigratedHabitsProvider`, `migratedHabitTaskCompletionsProvider` | become plain `tasksProvider` / occurrence providers |
| `habitCompletionsInRangeProvider` | **stays**, re-homed to whatever owns the log |
| `streakParityReportProvider`, `divergentStreakParityProvider`, `migrationReportProvider` | retire after cutover |
| `migrationServiceProvider` | retire after cutover |
| `recurringWorkProvider` and friends | stay, single-source |

`test/app/provider_uniqueness_test.dart` asserts single-instance providers;
provider consolidation must keep it green.

---

## 13. Schema impact

No destructive schema change is required, and none should be made at this stage.
`habits` and `habit_completions` are JSON lists under fixed keys — dropping them
is a delete of `DatabaseService.habitsKey` plus the repository, not a versioned
migration.

A **new** version is needed only when retirement becomes irreversible, and it
should be the last stage: bump past 5 to mark the legacy keys as intentionally
abandoned, and only after a verified backfill. Retirement must not remove the
ability to read legacy data until §17's gates have passed on real installs.

---

## 14. Capability gaps

### 14.1 The two streak models do not agree

| | `HabitLogProjection` | `TaskStreakComputer` |
|---|---|---|
| current streak | **day**-consecutive (`streak_parity.dart:155-169`) | **scheduled**-consecutive (`task_streak.dart:59-107`) |
| total | count of **distinct days** (`:146`) | **sum of `count`** across rows (`:55-57`) |

Consequences:

- A Mon/Wed/Fri habit with a day-consecutive streak of 3 reports **1** after
  migration. This is not a bug — both are documented as intentional, different
  metrics — but it *is* a user-visible number change on a number the app
  displays prominently.
- Any habit with `targetCount > 1` has a legacy row with `count > 1`. The habit's
  stored `totalCompletions` counted **days**; the Task's sums `count`. The two
  totals disagree immediately after a correct migration.
- `longestStreak` is a high-water mark the log cannot reconstruct
  (`streak_parity.dart:176-201`). It is not transferred anywhere and is
  **irrecoverably lost** at cutover.

These are product decisions, not bugs to be patched. Someone must decide which
number the user sees after migration, and the stored counter must be migrated to
match.

### 14.2 Fields with no Task home

`targetCount` (x-per-day), `targetDuration`, `cue`, `timeOfDay`,
`streakFreezesUsed`. Each is user-entered and visible in the habit form
(`habit_form_test.dart` covers it). Options: extend `Recurring`, extend `Task`,
or accept documented loss. Accepting loss silently is not available.

---

## 15. Risk register

| # | Risk | Severity | Evidence |
|---|---|---|---|
| R1 | Migration never runs; retirement would delete live user data | **Blocker** | zero production callers of `copyEligibleToTasks` |
| R2 | Interrupted migration creates duplicate Tasks | **Blocker** | `migration.dart:143` before `:164` |
| R3 | Dangling `taskId` permanently blocks re-migration | **Blocker** | `migration.dart:119` |
| R4 | Analytics double-counts every migrated completion | **Blocker** | legacy rows retained; `progress_service.dart:95-116` |
| R5 | Archived habits unmigrated, then deleted | **Blocker** | `migration.dart:74` + `habit_repository_impl.dart:155` |
| R6 | Streak/total numbers change on migration | High | §14.1 |
| R7 | `longestStreak` irrecoverable | High | `streak_parity.dart:176-201` |
| R8 | Five habit capabilities have no destination | High | §14.2 |
| R9 | `copyEligible` and `reconcile` disagree on row count | Medium | `migration.dart:146` vs impl `:520-535` |
| R10 | `sortOrder` collision in task list | Low | `migration.dart:136` |
| R11 | Focus `habitId` dangles | Low | `focus_session.dart:25` |
| R12 | Quarantined habits have no exit path | Medium | `QuarantinedHabit` is reported, never resolved |
| R13 | Stale `RecurringSource.recurringTask` doc names an already-lifted blocker as the reason convergence stopped | Medium | `recurring_work.dart:20-23` vs `:121-157` |

---

## 16. Staged retirement plan

Each stage is additive, idempotent, independently shippable, and reversible until
Stage 7. **No stage below deletes anything.**

**Stage 0 — Make migration reachable and correct.**
Add an explicit, user-visible or first-run-triggered entry point to
`runFullMigration`. Write the `taskId` link **before** copying history, or record
intent in the habit first so a crash resumes rather than duplicates. Replace the
`taskId != null` skip with a real check: load the Task; if absent, clear
`taskId` and re-migrate. Include archived habits explicitly. Remap `sortOrder`.
Make `copyEligible` and `reconcile` share one conversion function.

**Stage 1 — Resolve streak semantics.**
Decide the post-migration streak definition and migrate stored counters to it.
Persist whatever `longestStreak` information must survive, because the log cannot
reconstruct it.

**Stage 2 — Resolve capability gaps.**
Give `targetCount`, `targetDuration`, `cue`, `timeOfDay`, `streakFreezesUsed` a
home in the Task/Recurring model, or record an explicit accepted loss per field.

**Stage 3 — Cut legacy analytics over.**
Point Analytics at Task-owned reads (category exists on `Task`; heatmap and
correlation move to task ids) and confirm no completion is counted twice.

**Stage 4 — Single-source recurring work.**
Collapse `RecurringWork` to one source; retire the `habit` branch and
`recurringSourceCountsProvider`.

**Stage 5 — Retire Habit creation and the habits UI.**
Remove `/habits`, `HabitsScreen`, `HabitController`, and the split providers.
Creation flows produce Tasks. Keep the `HabitCompletion` log and `habits` key
readable.

**Stage 6 — Unlink residuals.**
Null out or drop dangling focus `habitId`s; resolve quarantined habits (migrate
after repair, or archive with a recorded reason); clear `taskId`-bearing habit
rows.

**Stage 7 — Drop the legacy store.**
Only after §17 gates pass on real installs. Delete `habitsKey`, `Habit`,
`habit.freezed.dart`, `streak_parity.dart`, `migration.dart`, and the retirement
providers. Bump the schema version. **The shared completion log survives** — it is
not a habit artifact.

---

## 17. Preconditions and gates

Before Stage 0 ships:

- `runParityGate` reports zero quarantined habits, or each quarantined habit has a
  recorded repair-or-archive decision.
- A crash-injection test proves an interrupted `copyEligibleToTasks` resumes
  without creating a second Task.
- A dangling-`taskId` test proves re-migration recovers rather than skipping.

Before Stage 7 ships:

- `recurringSourceCountsProvider[RecurringSource.habit] == 0` on real installs.
- No habit row has a `taskId` that fails to resolve to a live Task.
- Analytics totals for a migrated habit equal its pre-migration totals under the
  Stage 1 definition.
- Archived-habit count is zero, or archived habits are migrated with `status`
  preserved.
- Every one of the five §14.2 fields is either migrated or explicitly waived.

---

## 18. Test retention and removal

26 of 47 test files reference `Habit` — over half the suite.

**Retain unchanged:** `progress_service_test.dart`, `analytics/*`,
`today/*`, `task_controller_test.dart`, `task_schedule_test.dart`,
`habit_completion_test.dart` (it tests the *shared log*, which survives),
`focus/*`, `database_schema_version_test.dart`.

**Retire after Stage 7:** `habit_entity_test.dart`, `habit_scheduling_test.dart`,
`habit_controller_test.dart`, `habits_screen_smoke_test.dart`,
`habit_form_test.dart`, `habit_repository_impl_test.dart` (habit portions),
`streak_parity_test.dart`, `migration_test.dart`, `recurring_work_test.dart` (habit
branch), `recurring_providers_test.dart` (parity/migration providers).

**Rewrite:** `provider_uniqueness_test.dart` (provider consolidation),
`render/full_suite_test.dart` and `render/render_test.dart` (habits screen gone),
`regression_bug_fixes_test.dart` (verify no habit assumption).

`migration_test.dart` is the highest-value file in the repo for this stage and
must keep running through Stage 6 — it is the only executable proof that the
backfill is correct.

---

## 19. Non-goals

- Changing streak, progress, or analytics semantics for their own sake.
- Redesigning the Habits or Today UI.
- Splitting or renaming the shared completion log.
- Performance work, offline/sync, or backup.
- Fixing unrelated Analytics or Focus issues found along the way.
- Any code change in this stage.

---

## 20. Acceptance criteria

The retirement is complete when:

1. No `Habit` entity, controller, or repository remains in `lib/`.
2. `RecurringSource` has one member.
3. Every persisted habit has a verified live Task or an explicitly archived
   record.
4. No completion is double-counted in any aggregate.
5. Post-migration streaks and totals match the Stage 1 definition exactly.
6. Each §14.2 field is migrated or explicitly waived in writing.
7. The suite is green with the retained set from §18.
8. `habits` and `habit_completions` keys are removed only after 3–6 are verified
   on real installs.

---

## 21. Final recommendation

### `REQUIRES INTERMEDIATE MIGRATION`

Retirement is the correct end state and the surrounding design — shared schedule
vocabulary, `taskId` bridge, occurrence rows in one log, write-path delegation —
points the right way. But `Habit` cannot be retired from where the code stands:

- the migration has **never been executed** in production (R1),
- it is **not resumable** and does not **verify** its target (R2, R3),
- it **double-counts** every migrated completion in Analytics (R4),
- it **strands archived habits** (R5),
- and `Task` cannot yet express five live capabilities while the two streak
  models disagree on what a streak is (R6–R8).

The intermediate stage is Stages 0–2 of §16: make the migration reachable,
atomic, and verified; decide the streak definition and migrate the counters;
resolve the capability gaps. Only after those land does deletion become a
mechanical, low-risk final act rather than a data-loss event.

Nothing in this document should be read as a recommendation to delete `Habit`
now.