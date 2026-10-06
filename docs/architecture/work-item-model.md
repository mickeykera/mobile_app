# The Work-Item Model

How goals, projects, tasks, schedules, focus and progress relate in Ascend, and
the staged plan for getting there without a rewrite.

Status: **stages A–E shipped, stage F in progress.** The status of each stage is
recorded in [Delivery status](#delivery-status).

---

## 1. Confirmed decisions

These are settled. They are not reopened by later stages, and code that
contradicts one of them is a bug rather than an alternative design.

### 1.1 Goal and project statuses

```
active → completed → archived
```

Three states, no more. `paused` and `onHold` are deliberately **not** modelled
yet: a paused project needs a "when do I resume" date and a rule for what happens
to its tasks in the meantime, and guessing at that now would bake a wrong answer
into storage. Adding two enum values later is cheap; un-migrating data is not.

The lifecycle is encoded in `lib/core/constants/item_status.dart` as `ItemStatus`,
shared by `Goal` and `Project`. It is kept **separate** from `TaskStatus` on
purpose — see §1.3.

### 1.2 Project progress uses dual metrics

A project reports **two independent numbers**, never one blended score:

| Metric | Answers | Source |
| --- | --- | --- |
| Finite task completion % | "Is the work list shrinking?" | non-recurring tasks with `status == done` / all non-recurring tasks |
| Focus / activity | "Is this getting real time?" | `FocusSession.totalWorkMinutes` where `session.projectId` matches |

Both live on `ProjectProgress` (`lib/features/progress/domain/progress_metrics.dart`).

Recurring habit completions are **excluded from the task percentage**. A habit's
occurrences are virtual and recorded as completion rows, so the habit task itself
is never `done`; counting it would leave a permanently unfinished item sitting at
0% in every project that adopts one. Habit activity is reported separately via
`habitCount` / `habitCompletionCount`.

### 1.3 One-off task status

```
todo → doing → done → archived
```

Encoded in `lib/features/tasks/domain/value_objects/task_status.dart` as
`TaskStatus`. `doing` exists because a task is *worked on*; a goal or project is
not. `TaskStatus` is deliberately **not** merged into `ItemStatus`: sharing one
enum would let a task accept `doing` semantics it cannot have, or a project
accept `doing`, and the two vocabularies would drift into each other.

Unarchiving returns a task to `todo`, not to `doing` — archive records no
previous status, and resurrecting a stale in-progress claim is worse than
restarting.

### 1.4 `Task` is the canonical work item

A habit is **a recurring `Task`**, not a parallel work-item system. There is one
entity, one repository, one completion log, one schedule vocabulary.

This is a *destination*, not a starting point. `Habit` keeps its own storage and
its own streak bookkeeping until the convergence below is done. What makes the
destination reachable is that the schedule was extracted first (§ Stage A): a
habit already knows how to describe itself as a `Recurring` schedule, so
converting it later is a codec change, not a redesign.

The precondition was *"a dual-read period and a streak-parity proof before any
write changes."* **Stage G** delivered the read half — `RecurringWork` reads both
sources, and the parity report re-derives every habit's streaks from its
completion log to check the stored counters against it. **Stage H** delivered the
write half — recurring tasks now record occurrence history, and the migration
service copies Habits to Tasks behind a parity gate. The read and write halves
are complete; the remaining work is UI migration and retirement of the legacy
path.

### 1.5 Additive migration, never a rename

There is no "rename `Habit` to `Task`" commit. The strategy is additive: extract
the value objects, version the schema, add the new entities and repositories,
add nullable links, then migrate the spine and the screens one at a time. Every
stage is independently shippable and independently revertable.

### 1.6 The Inbox is a query, not a collection

A task does **not** require a project or a goal. The Inbox is exactly the tasks
that nothing has claimed:

```dart
bool get isInbox => projectId == null && goalId == null;
```

There is no `inbox` key in storage and no "move to inbox" write. Filing a task
sets a link and it leaves; clearing the link puts it back. The Inbox can
therefore never disagree with the links, because it *is* the links.

---

## 2. The conceptual hierarchy

```
Goal     = why
Project  = body of work
Task     = unit of work
Schedule = when
Focus    = time spent
Completion = what happened
Progress = derived result
```

Two rules follow from this that constrain the whole design:

**Stored vs derived.** `Goal`, `Project` and `Task` store only facts about
themselves — identity, title, links, timestamps, status, schedule. Anything
answerable ("is this overdue", "how far along is this", "what is due today") is
computed from those facts by `ProgressService` and the summary functions. No
entity carries a cached progress number, because two copies of a derived value
will disagree and there is no principled way to choose between them.

**Separation of concerns.** Schedule is a value object, not a column, because
"when" is the one axis that differs between a one-off task and a recurring one.
Focus and Completion are separate append-only logs keyed by id, never counters on
the entity. Progress is a pure function over (tasks, completions, sessions) that
takes plain collections rather than repositories, so it is testable with no
database and no clock.

### Feature layout

```
lib/features/
  goals/     domain/entities/goal.dart        data/repositories/goal_repository_impl.dart
  projects/  domain/entities/project.dart     data/repositories/project_repository_impl.dart
  tasks/     domain/entities/task.dart        data/repositories/task_repository_impl.dart
             domain/value_objects/task_schedule.dart   (TaskSchedule + RecurrenceRule)
             domain/value_objects/task_status.dart
  progress/  domain/progress_metrics.dart     domain/services/progress_service.dart
  today/     domain/today_summary.dart        presentation/screens/today_screen.dart
```

`progress` and `today` are cross-cutting read models, not features with their own
storage. They depend on the entities; nothing depends on them.

---

## 3. The staged plan

Each stage below is **independently shippable**: it can be merged, released and
rolled back on its own, and the full test suite is green at every one of them.
No stage depends on a later one.

### Stage A — Extract `TaskSchedule` / `RecurrenceRule`

**Files**

- `lib/features/tasks/domain/value_objects/task_schedule.dart` (new)
- `lib/features/tasks/domain/value_objects/task_status.dart` (new)
- `lib/core/utils/app_clock.dart` (new)
- `lib/features/habits/domain/entities/habit.dart` (schedule accessors delegate out)
- `lib/features/habits/domain/habit_scheduling.dart` (new — date maths for Snooze/Reschedule)

**Data model** — No persisted change. `RecurrenceRule` is a sealed hierarchy
(`DailyRecurrence`, `WeekdayRecurrence`, `WeekendRecurrence`, `CustomRecurrence`,
`NoRecurrence`) over the *existing* `frequency` / `customWeekdays` strings.
`TaskSchedule` is a sealed hierarchy (`Unscheduled`, `Once`, `Recurring`) that
wraps a rule plus the two per-item overrides `dueAt` and `snoozedUntil`.

**Migration** — None. Pure refactor of in-memory logic.

**Tests** — Round-trip every rule and schedule through `toJson`/`fromJson`;
unknown `kind` and unknown `frequency` fall back safely; snooze suppresses today
and future days but not history; `dueAt` forces its own day and suppresses
earlier days; overrides never rewrite a past day. `now` is always a parameter, so
every case runs against a pinned `AppClock`.

**Unchanged** — Habit storage keys and row shape, byte for byte. Streak maths.
Every existing habit screen.

**Acceptance** — `Habit.isDueOnDate` and the week strip produce identical results
for every seeded frequency, before and after.

---

### Stage B — Schema versioning

**Files**

- `lib/core/database/database.dart`
- `test/core/database_schema_version_test.dart` (new)

**Data model** — Adds a `schema_version` int key and
`DatabaseService.currentSchemaVersion`, currently **4**. Migration runs one step
at a time, in order, from the recorded version.

| Version | Introduces |
| --- | --- |
| 1 | versioning itself; no data change |
| 2 | `goals`, `projects` collections |
| 3 | optional `projectId` / `goalId` on habits; no rewrite |
| 4 | `tasks` collection; optional `itemId`/`itemType` on completions; optional `taskId`/`projectId`/`outcome` on focus sessions |

**Migration** — Every step is *additive and idempotent*. `_seedJsonListIfAbsent`
guards on `containsKey`, so a second pass cannot overwrite a list the user has
since filled. A missing version reads as 0. An install that skipped a release
still applies each intervening step once, and a crash mid-migration resumes
correctly because the version is written once at the end.

**Tests** — Each version step asserted individually; existing rows byte-identical
after migration; re-running never clobbers seeded data; a version ahead of the
build is left alone; a fresh install ends with every collection present but empty.

**Unchanged** — Every existing storage key. `DatabaseService` stays a
`SharedPreferences` wrapper — this is not a move to SQLite.

**Acceptance** — A user on any prior build upgrades with no data loss and no
visible change; the migration is safe to interrupt at any point.

---

### Stage C — `Goal` and `Project` entities and repositories

**Files**

- `lib/core/constants/item_status.dart` (new)
- `lib/core/utils/id_generator.dart` (`generateGoalId`, `generateProjectId`)
- `lib/features/goals/domain/entities/goal.dart`, `domain/repositories/goal_repository.dart`, `data/repositories/goal_repository_impl.dart`
- `lib/features/projects/domain/entities/project.dart`, `domain/repositories/project_repository.dart`, `data/repositories/project_repository_impl.dart`
- tests mirroring each

**Data model** — Both are freezed plain data with `status: ItemStatus`,
`sortOrder`, nullable `goalId` (project only), nullable `targetDate`,
`category`, `color`, `completedAt`, `archivedAt`. Both have a `.create`
constructor that stamps id + timestamps via `AppClock`.

Neither stores progress. See §2.

**Migration** — Collections already seeded empty in v2, so nothing to do here.

**Tests** — Entity defaults and `.create` stamping; `ItemStatus` round-trip and
its fallback to `active`; repository CRUD, archive/unarchive and reorder; the
memoised-load guard against concurrent duplicate loads (a plain `bool` guard
loses that race and doubles every row).

**Unchanged** — Nothing reads these collections yet. No screen changes. The
existing 251-test baseline is untouched.

**Acceptance** — Goal and project data round-trips through storage with no
schema version bump, and no existing feature can tell the difference.

---

### Stage D — Nullable `projectId` / `goalId` relationships

**Files**

- `lib/features/tasks/domain/entities/task.dart` (`projectId`, `goalId`, `isInbox`)
- `lib/features/habits/domain/entities/habit.dart` (`projectId`, `goalId`)
- `lib/features/habits/domain/entities/habit_completion.dart` (`itemId`, `itemType`, `ownerId`, `isHabitCompletion`)
- `lib/features/focus/domain/entities/focus_session.dart` (`taskId`, `projectId`, `outcome`)
- `lib/features/tasks/data/repositories/task_repository_impl.dart` (new)

**Data model** — Every new field is **optional**, and every codec writes `null`
rather than omitting the key. `HabitCompletion` gains the generic
`itemId`/`itemType` pair while keeping `habitId`; `ownerId` is `itemId ?? habitId`
and a row with no `itemType` is a habit completion by definition, so legacy rows
keep their meaning with no rewrite.

`TaskSchedule` is stored under a `schedule` key. A task row whose `schedule` is
missing or unreadable decodes to `Unscheduled` — a record this build cannot
understand must not become a daily obligation the user never asked for.

**Migration** — None needed, by construction. Optional fields plus a
pass-through fallback means v2/v3/v4 rows stay valid as-is.

**Tests** — `Task.isInbox` for every combination of links; the `schedule` key
absent / `null` / malformed; `HabitCompletion` legacy rows still resolving
`ownerId` and `isHabitCompletion`; task repository CRUD, inbox and per-project
queries, archive/unarchive, reorder.

**Unchanged** — Habit completion writes still produce rows that read exactly as
before. Streaks, analytics and the journal are unaffected — nothing counts task
rows yet.

**Acceptance** — A task can be created with no project and no goal and still
round-trips; the Inbox is a query and never a stored list.

---

### Stage E — Migrate the integration spine

**Files**

- `lib/features/progress/domain/progress_metrics.dart` (new)
- `lib/features/progress/domain/services/progress_service.dart` (new)
- `lib/features/today/domain/today_summary.dart` (new)
- `lib/features/analytics/data/repositories/analytics_repository_impl.dart`
- `lib/features/focus/data/repositories/focus_repository_impl.dart`
- `lib/features/habits/data/repositories/habit_repository_impl.dart`

**Data model** — No new persisted fields. This stage makes the *existing* fields
mean something: `progress_service.dart` is the single place `projectProgress`
and `goalProgress` are computed, from plain collections and no clock.

`goalProgress` counts a task towards its goal by **either** route — naming the
goal directly, or belonging to one of the goal's projects. Both are legitimate
(a goal holds work before it has projects; a project adds its own tasks) and
restricting to one would silently drop the other's work.

Archived tasks and habits are excluded from progress: an archived item is out of
the user's sight, so counting it would move a number for something they can no
longer act on.

**Migration** — None. Read-only over v4 data.

**Tests** — Dual metrics computed independently; recurring tasks excluded from
the finite ratio and counted separately; archived items excluded; both goal
attribution routes; a project with no finite tasks reports `hasFiniteTasks ==
false` rather than a misleading 0%; empty-input behaviour for every helper.

**Unchanged** — No screen reads any of this yet. Habit analytics totals, streaks
and the Today header keep their exact current numbers.

**Acceptance** — Progress is derivable from stored facts alone, with no second
copy of any number persisted anywhere.

---

### Stage F — Migrate the screens

The first stage where users see anything. Split into two independently
shippable halves.

#### Stage F1 — The Tasks surface

**Files**

- `lib/features/tasks/presentation/controllers/task_controller.dart` (new, freezed state)
- `lib/features/tasks/presentation/providers/task_providers.dart` (new)
- `lib/features/tasks/presentation/screens/tasks_screen.dart` (new)
- `lib/features/tasks/presentation/widgets/task_form.dart` (new)
- `lib/app/router.dart` (`/tasks` route + 7th nav destination)
- `test/render/render_test.dart`, `test/render/full_suite_test.dart` (tab lists, `_routes`)

**Data model** — None. Reads and writes `tasks` through the existing repository.

**Migration** — None.

**Tests** — `task_controller_test.dart` (load, create, status transitions,
`doing`/`done`/archive/unarchive, file-under-project, reorder, error paths);
`tasks_screen_test.dart` (inbox renders, project section renders, a task filed to
a project leaves the inbox, empty states, overflow-free at phone size); the nav
bar's per-item width assertion re-run with seven items.

**Unchanged** — The Today screen's habit list, progress ring, streak badge, focus
card and week strip; the Habits, Focus, Journal, Analytics and Premium screens;
every existing completion path.

**Acceptance** — A task can be created from the app, ticked, moved to `doing`,
filed under a project and archived, and it leaves the Inbox the moment it is
filed. The bar still clears 48dp per item at 411dp width.

#### Stage F2 — Project and goal detail

**Files**

- `lib/features/projects/presentation/controllers/project_controller.dart` (new)
- `lib/features/projects/presentation/providers/project_providers.dart` (new)
- `lib/features/goals/presentation/controllers/goal_controller.dart` (new)
- `lib/features/goals/presentation/providers/goal_providers.dart` (new)
- `lib/features/progress/presentation/providers/progress_providers.dart` (new)
- `lib/features/projects/presentation/screens/project_detail_screen.dart` (new)
- `lib/features/goals/presentation/screens/goals_screen.dart` (new)
- `lib/app/router.dart` (`/goals`, `/projects/:id`)
- `test/features/goals/presentation/`, `test/features/projects/presentation/`,
  `test/render/full_suite_test.dart` (`_routes`)

**Data model** — None new. Reading `ProjectProgress` / `GoalProgress` off the
Stage E service.

**Tests** — Controller CRUD and lifecycle; the detail screen shows **both**
metrics side by side and never a blended number; a project with no finite tasks
shows the activity metric alone rather than a 0% ring; goal rollup across both
attribution routes.

**Unchanged** — Everything in F1, plus all five pre-existing screens.

**Acceptance** — `active → completed → archived` is reachable from the UI for a
project and a goal; progress on screen is the Stage E number, recomputed, never a
stored copy.

#### Two provider bugs this stage surfaced

Worth recording because both were invisible to the suite, and both would have
been invisible to a user too until the data disagreed with itself.

1. **`taskRepositoryProvider` was declared twice** — once in
   `task_repository_impl.dart`, once in `task_providers.dart`. Nothing referenced
   the data-layer copy, so it was dead code. Worse, it was *importable* and any
   test that overrode it would have silently overridden the wrong provider and
   seen an empty task list. The dead declaration is gone.
2. **`habitRepositoryProvider` was declared twice, and both were live.**
   `analytics_repository_impl.dart` used the data-layer one while `HabitController`
   used the presentation one, so Analytics and the Habits screen each held a
   *separate* `HabitRepositoryImpl` cache over the same `SharedPreferences` — the
   exact drift `task_providers.dart` warns about two files away. Analytics now
   reads the single live provider.

The lesson generalises: a provider duplicated by name in two libraries is a
silent-failure machine. One declaration per provider, in the layer that owns it.

---

### Stage G — Habit → Task convergence, read-only half

The first half of the destination in §1.4. §1.4 records the precondition:
*"a dual-read period and a streak-parity proof before any write changes."* This
stage is that proof. **It changes no write path.** Nothing migrates, nothing is
converted, no screen moves. It produces the two things a later stage needs in
order to be safe to write, and a report saying whether they hold.

**Why this is read-only.** A habit's streaks are not derived from its completion
log — they are **stored counters**, updated at write time by
`Habit._calculateNewStreak`, which looks only at `lastCompletedAt` and
`currentStreak` and never opens the log. The log and the counters are therefore
two independent records of the same history, kept in step by convention rather
than by construction. Migrating writes before proving they agree would freeze
whichever set of numbers is wrong. So Stage G measures the gap first.

**Files**

- `lib/features/recurring/domain/recurring_work.dart` (new — the unified read shape)
- `lib/features/recurring/domain/streak_parity.dart` (new — log-derived streaks + report)
- `lib/features/recurring/presentation/providers/recurring_providers.dart` (new)
- `lib/features/habits/domain/entities/habit.dart` (`recurringSchedule` getter; pure refactor)
- `lib/features/habits/domain/repositories/habit_repository.dart` and its impl
  (`getAllCompletions`; read-only, additive)
- `test/features/recurring/domain/recurring_work_test.dart`,
  `test/features/recurring/domain/streak_parity_test.dart`,
  `test/features/recurring/presentation/recurring_providers_test.dart` (new)

**Data model** — None. Reads `habits`, `tasks` and `habit_completions` through the
existing repositories. Nothing is written and no schema version moves.

**`RecurringWork`** — one read-only shape over both sources. A `Habit` and a
`Task` whose schedule `is Recurring` both project into it, tagged with a
`RecurringSource`. Consumers that only need "the user's recurring work" can read
one list instead of two, which is what makes a later screen migration a
one-line change rather than a rewrite. It exposes the fields both already share —
`id`, `title`, `schedule`, `projectId`, `goalId` — and nothing that only one of
them has, because a union with per-source extras is just the old two lists with
extra steps. `lastCompletedAt` is `null` for a recurring task *even when it is
done today*, because "done" and "has a history" are different claims and
`occurrenceRecorded` is there to keep that distinction honest.

**`Habit.recurringSchedule`** — `isDueOnDate` and `RecurringWork.fromHabit` both
need the habit's `Recurring`, and rebuilding it at each use is how two call sites
end up disagreeing about whether a habit is due. That is not hypothetical: it is
the bug `isDueOnDate` was extracted to fix. The getter makes it impossible to
reintroduce.

**`getAllCompletions`** — parity compares a habit's counters against its *entire*
history. The existing range calls would report divergence for every habit whose
history reaches outside the window, which is a fabricated result rather than a
finding, so the report reads the whole log.

**Parity definition — and the fork this had to resolve.** "Streak parity" is
ambiguous, and the definition decides the answer:

- **Day-consecutive (chosen).** Walk back from the most recent completion one
  calendar day at a time. This is exactly what `_calculateNewStreak` computes on
  write, so parity is a like-for-like comparison.
- **Scheduled-consecutive (rejected for this stage).** Walk the habit's
  *recurrence* backwards, skipping days it was never scheduled. This is arguably
  the more meaningful number, and it disagrees with the write path for every
  non-daily habit. A Mon/Wed/Fri habit completed on those three days has a
  **day-consecutive streak of 1** (each completion is two days after the last, so
  each breaks the chain) and a scheduled-consecutive streak of **3**. Adopting
  the latter would report almost every non-daily habit as divergent and make the
  gate meaningless.

So a Mon/Wed/Fri habit showing a 1-day streak is **correct under this
definition**, not a defect. A scheduled-consecutive streak is a different metric
that would need its own stage and its own migration of the stored counter.

**`ParityVerdict`** — per habit, the stored `currentStreak` / `longestStreak` /
`totalCompletions` beside the same values re-derived from the log, plus a verdict
naming the divergence when they disagree: `agrees`, `counterAheadOfLog`,
`logAheadOfCounter`, `chainDisagrees`. A verdict is what tells a later stage
whether to trust the counter or the log; counters that merely differ are not
actionable on their own.

**`longestStreak` is reported but excluded from the verdict.** Writing the tests
turned up the reason: `copyWithUncompletion` decrements `currentStreak` and
`totalCompletions` but deliberately leaves `longestStreak` alone, because the run
*was* achieved. Removing today's row destroys the log's only evidence of it, so
the log can never re-derive that high-water mark. Including it in the verdict
would report a divergence after every un-completion — a gate that fires on the
normal path is no gate at all. `currentStreak` and `totalCompletions` *are*
reconstructible, so those two decide the verdict, and a balanced total with a
broken chain is the `chainDisagrees` case. Finding this by running the comparison
is the argument for running it before migrating writes onto it.

**Tests** — parity agrees on a consistent history, including one built by driving
the real `copyWithCompletion`/`copyWithUncompletion` write path rather than by
hand-setting counters; each verdict is produced by the history that should produce
it; a same-day double completion does not double-count; a multi-day gap breaks the
chain on both sides; a non-daily habit derives an occurrence count rather than a
day count; `RecurringWork` projects a habit and a recurring task into the same
shape, excludes `Once`/`Unscheduled` tasks, and agrees with `isDueOnDate`; the
parity provider reads the whole log; and the write paths are untouched — asserted
by running the existing `HabitController` and `TaskController` suites unchanged
and the render suite with no golden updated.

**Unchanged** — Every write path in `HabitController` and `TaskController`; both
existing repositories' behaviour; all nine screens; the stored schema; Stages
A–F in full.

**Acceptance** — `RecurringWork` reads both recurring sources through one shape;
the parity report agrees for every habit whose log is complete; every verdict the
report can name has a test that produces it; and **no write path or screen is
modified**, so the stage is a no-op for users and independently revertable.

**What this stage deliberately does not do** — It does not make recurring tasks
write completion rows, though `HabitCompletion` is already shaped for it
(`itemId` + `itemType`, with `ownerId` falling back to the legacy `habitId`). It
does not convert a stored habit into a task, and it does not reconcile the
counters it finds divergent — reporting the gap is this stage's whole job. A
recurring task still records an occurrence only by flipping its own `status` to
`done`, with no history, and that remains the largest obstacle to convergence.

**Result** — Shipped. 43 new tests; suite green at 521 with no golden updated.
Two findings changed the design rather than just confirming it, and both are
recorded above: the parity metric has to be day-consecutive or it flags every
non-daily habit, and `longestStreak` is not reconstructible from the log at all.
Neither is visible by reading the code; both are why the proof precedes the
migration.

### Stage H — Habit → Task convergence, write half

**Shipped.** This stage makes recurring tasks record occurrence history and
migrates stored Habits into recurring Tasks, using the additive strategy:
**create the Task copy, dual-read from both during the transition, then retire
the Habit path**. No giant rename, no destructive schema change.

**Non-negotiable constraints from Stage G**

1. Task is the canonical work item; a Habit is a recurring Task.
2. Stage G was read-only; no write path changed.
3. Recurring tasks currently have NO occurrence history.
4. A recurring task MUST be able to record an occurrence before Habit converges.
5. `currentStreak` and `totalCompletions` are the stored values migration must
   reproduce exactly (what the user sees).
6. Streak parity = DAY-CONSECUTIVE, matching the existing Habit write path.
7. `longestStreak` is diagnostic-only; not reconstructed from incomplete log.
8. `RecurringWork` is the unified read projection.
9. Migration is additive and reversible.
10. No giant Habit → Task rename.
11. No silent change to existing metric meanings.

**Load-bearing guarantees (identified during design review)**

12. **Mandatory parity gate before migration.** Stage G established that Habit
    stored counters and `HabitCompletion` history can diverge. Migration MUST
    NOT blindly copy every Habit. Before migrating each Habit:
    - Run the existing streak parity logic from Stage G.
    - If the verdict is `agrees`, the Habit is eligible for migration.
    - If the verdict is divergent, do NOT migrate that Habit.
    - Produce a deterministic migration report containing:
      * eligible habits
      * divergent/quarantined habits
      * reason/verdict for each divergent habit
    - Do not silently repair or overwrite divergent stored counters.
    - Acceptance: every migrated Habit must pass parity; "parity report empty for
      all migrated items" means exactly that — no migrated item had a divergent
      verdict.

13. **Non-atomic dual-write behavior.** The persistence layer uses whole-list
    `SharedPreferences` writes and provides NO transactions. Dual-writes are
    explicitly NOT atomic. During the bridge:
    - Habit remains the authoritative representation.
    - Task occurrence history is the mirror.
    - If the Habit write succeeds but the Task mirror write fails, the system
      must have a deterministic recovery path: `reconcileHabitToTask(habitId)`
      rebuilds the Task occurrence history from the authoritative Habit
      completion history.
    - This is recovery/reconciliation, NOT transactionality.
    - Required test coverage:
      * successful dual-write
      * Habit write succeeds / Task mirror fails
      * reconciliation restores Task occurrence history
      * repeated reconciliation is idempotent
    - Do not introduce a database/transaction migration as part of Stage H.

14. **Logical deduplication between Habit and Task.** After migration, a
    single logical recurring item temporarily exists as both a Habit and a Task,
    linked by `Habit.taskId`. `RecurringWork` and its consumers MUST NOT expose
    both representations as two separate recurring items. Unified read rule:

    ```text
    if Habit.taskId == null:
        Habit is an independent legacy recurring item.

    if Habit.taskId != null:
        Habit is the legacy representation of the corresponding Task.
        Treat the Task as the canonical logical recurring item.
        Do not expose the Habit separately.
    ```

---

#### H.1 Recurring-task occurrence writer

**New repository operation**

```dart
// HabitRepository
Future<Result<HabitCompletion>> recordRecurringTaskOccurrence({
  required String taskId,
  required DateTime date,         // the calendar day the occurrence falls on
  required int count,
  Duration? duration,
  String? note,
  int? moodRating,
  int? energyRating,
});
```

- Writes a `HabitCompletion` with:
  - `habitId: null`
  - `itemId: taskId`
  - `itemType: 'task'`
  - `completedAt: date.atStartOfDay() + AppClock.now().timeOfDay` (time of tap)
  - `count, duration, note, moodRating, energyRating` from caller
- Returns the created row.
- Idempotency: if a row already exists for this `(taskId, date)` (same-day
  dedupe), returns the existing row and does NOT double-count. Mirrors
  `completeHabit`'s same-day guard.

**Why `date` not `DateTime`**

Occurrences are *calendar-day* entities, matching the day-consecutive streak
semantics. The UI taps "today" or "yesterday"; the time-of-day is metadata
stored on the row but NOT used for streak logic (day-consecutive uses
`startOfDay` comparison everywhere). Passing `date` makes the API honest about
what the streak counts.

**Backdate / future-date**

Allowed — the user may record an occurrence for any date the recurring task was
due. The write path uses the passed `date` for `completedAt` and for the
same-day dedupe check. This mirrors the existing habit backdate behavior.

**Uncomplete / remove occurrence**

```dart
// HabitRepository
Future<Result<void>> deleteRecurringTaskOccurrence({
  required String taskId,
  required DateTime date,
});
```

- Deletes the row for `(taskId, date)`. Symmetric with `deleteCompletion`.
- Does NOT mutate the Task entity (no `completedAt` clear on Task — recurring
  tasks are never "done" in the entity sense). This is the critical divergence
  from Habit: `Habit.copyWithUncompletion()` mutates the entity counters;
  recurring-task uncompletion only deletes the row, and the *counters are
  derived on read*. A recurring task's streak and totals are always
  log-derived, never stored.

**Interaction with `TaskStatus`**

- Recording an occurrence does **NOT** set `Task.status = done`. A recurring
  task's status stays `todo`/`doing`; its completion is the row, not the entity.
- `TaskStatus.done` is reserved for finite tasks (Once/Unscheduled) that are
  truly finished. This is the design invariant: recurring tasks express
  completion *only* through rows, never through status.

**Idempotency contract**

```
recordRecurringTaskOccurrence(taskId, date) -> row exists? return existing : create new
deleteRecurringTaskOccurrence(taskId, date) -> row exists? delete : no-op
```

Same-day double taps return the same row, no counter increment, matching
`completeHabit`.

**Recurring-task streak & total on read**

- `currentStreak` = day-consecutive run of occurrence rows ending at the most
  recent completed date.
- `totalCompletions` = distinct completed dates (one per date, regardless of
  `count`).
- `longestStreak` = longest such run in the log (diagnostic, may be lower than
  a Habit's stored value after un-completions).

This exactly mirrors Stage G's `HabitLogProjection` derivation, guaranteeing
parity by construction.

**Why this preserves "what the user sees"**

- Habit: `currentStreak` = 5, `totalCompletions` = 5 (stored on entity).
- Recurring Task with 5 occurrence rows on 5 consecutive days: log-derived
  `currentStreak` = 5, `totalCompletions` = 5.
- Same numbers, same meaning. Migration copies the stored values once; after
  that the Task's log is the source of truth.

---

#### H.2 Migration strategy: parity gate → copy → dual-read → switch → retire

**Strategy name: "parity-gate → copy-then-switch with dual-read bridge"**

**Step 0 — Parity gate (mandatory, per-habit).** Before any copy:

```dart
// New migration service method
Future<MigrationReport> runParityGate() async {
  final report = MigrationReport();
  for (final habit in allHabits) {
    final verdict = HabitLogProjection.from(allCompletions, habit.id)
        .compareTo(habit);
    if (verdict.verdict == ParityVerdict.agrees) {
      report.eligible.add(habit.id);
    } else {
      report.quarantined.add(QuarantinedHabit(
        habitId: habit.id,
        verdict: verdict.verdict,
        reason: verdict.verdict.name,
      ));
    }
  }
  return report;
}
```

- Runs the Stage G `HabitLogProjection.compareTo` for every Habit.
- `agrees` → `eligible` for copy.
- Any divergent verdict → `quarantined` with reason.
- **No silent repair.** Divergent Habits are NOT migrated; they remain on the
  legacy path until manually resolved.
- The report is the migration acceptance artifact: "every migrated Habit must
  pass parity" means the migration code only processes `eligible` IDs.

**Step 1 — Copy (one-time, additive).** For each `eligible` Habit:
- Create a `Task` with:
  - `id: 'task_' + uuid` (new namespace — Habit keeps its `habit_` id)
  - `title, description, projectId, goalId, category` copied.
  - `schedule: Recurring(rule from habit, dueAt: habit.dueAt,
    snoozedUntil: habit.snoozedUntil)`
  - `status: TaskStatus.todo` (recurring tasks never use `done`)
  - `createdAt: habit.createdAt`, `updatedAt: AppClock.now()`
  - `sortOrder: habit.sortOrder`
  - `completedAt: null`, `archivedAt: null`
- For each `HabitCompletion` with `habitId == habit.id`:
  - Create a `HabitCompletion` with `itemId: newTaskId`,
    `itemType: 'task'`, same `completedAt`, `count`, `duration`, `note`,
    `moodRating`, `energyRating`. `habitId` left `null` (or can carry original
    for audit — not used by readers).
- Update `Habit` with a new nullable `taskId` link pointing to the new Task.
  `Habit` is NOT deleted, archived, or modified otherwise. The `taskId` field
  is the migration marker.

**Step 2 — Dual-read bridge (coexistence window).** All existing read paths
(`RecurringWork`, `HabitController`, `ProgressService`, `TodaySummary`,
`Analytics`, `HabitLogProjection`) already read Habits and Tasks separately.
The `RecurringWork` projection already unifies them. Nothing changes for
consumers during this window — they continue reading from `Habit` and
`RecurringWork`.

**Step 3 — Single-write migration (incremental).** Update each write path to
write to the Task side, one at a time:
- **Habit completion** (`HabitController.completeHabit`): if
  `habit.taskId != null`, ALSO call `recordRecurringTaskOccurrence` with the
  same `date` and payload. The original Habit write still happens (for rollback
  safety). After all consumers are moved, the Habit write is removed.
- **Habit un-completion** (`HabitController.uncompleteHabit`): if
  `habit.taskId != null`, ALSO call `deleteRecurringTaskOccurrence`. Both
  write.
- **Recurring task occurrence**: new `TaskController.recordOccurrence` (or
  similar) writes the row directly. UI for recurring tasks calls this.
- **Analytics / Today / Progress**: these are read-only; they already consume
  `RecurringWork` or the repositories. No write changes.

**Step 4 — Reconciliation (recovery, not transaction).** Because dual-writes
are non-atomic, a recovery operation must exist:

```dart
// HabitRepository
Future<Result<void>> reconcileHabitToTask(String habitId) async {
  // 1. Load the authoritative Habit completion history (all rows with ownerId == habitId)
  // 2. Load the corresponding Task's current occurrence rows (itemId == taskId, itemType == 'task')
  // 3. For each Habit completion row:
  //    - If no Task row exists for that date, create it via recordRecurringTaskOccurrence
  //    - If a Task row exists, ensure its count/duration/note match (source of truth: Habit row)
  // 4. For each Task row with no corresponding Habit row: delete it (orphaned by partial failure)
  // 5. Return success
}
```

- This is **recovery/reconciliation, NOT transactionality**. It is invoked
  manually (or via a background job) when divergence is detected.
- It rebuilds the Task mirror from the Habit authority.
- Idempotent: running it repeatedly converges to the same state.
- Required test coverage (see H.6):
  * successful dual-write
  * Habit write succeeds / Task mirror fails
  * reconciliation restores Task occurrence history
  * repeated reconciliation is idempotent

**Step 5 — Switch (per-habit).** When a Habit's `taskId` is set and the user
completes it via the *new* Task UI, the Habit write is the legacy path. The
switch point is when the Habit screen is replaced by the Task screen for that
item — that's a UI migration, not a data migration. The data is already
mirrored.

**Step 6 — Retire.** After all write paths write Task-side and all screens read
Task-side, the Habit entity, controller, repository, and screen can be deleted.
The schema version is bumped (v5) but the `habits` key in storage is left
intact for rollback; it is simply no longer read.

**Why this strategy**
- Additive: every step adds data, never deletes.
- Reversible: at any point before Retire, dropping the new code restores the
  old behavior exactly (Habits still own the authoritative write).
- No giant rename: `habit_` ids stay on Habits; Tasks get `task_` ids.
- No silent metric change: streak/totals are identical by construction.
- `longestStreak` discrepancy is documented: the Task's longest streak is
  log-derived and may be lower; the Habit's stored value is preserved for
  rollback.
- Parity gate ensures only healthy Habits migrate; divergent ones are visible
  and quarantined.
- Reconciliation provides deterministic recovery from partial dual-write
  failures without transactions.

---

#### H.3 Compatibility: legacy rows, mixed history, no double-count

**Legacy rows (`habitId` only, no `itemId`/`itemType`)**

`HabitCompletion.ownerId = itemId ?? habitId` already handles this: legacy
rows map to their Habit. After migration, the new Task rows have `itemId:
taskId`, `itemType: 'task'`. A legacy row never matches a Task id because
namespaces are disjoint (`habit_` vs `task_`).

**Newer rows with `itemId` + `itemType`**

The `createCompletion` factory already sets `itemId = itemId ?? habitId` and
`itemType = itemType ?? (habitId != null ? 'habit' : null)`. Migration creates
rows with `itemId: taskId`, `itemType: 'task'`. All readers filter by
`ownerId` (which equals `habitId` for legacy, `taskId` for migrated).

**Mixed history during dual-read**

`RecurringWork` projects both sources. `HabitLogProjection` filters
`isHabitCompletion` (which is `true` for `itemType == 'habit'`). The new
recurring-task rows have `itemType == 'task'`, so `isHabitCompletion == false`.
They are **not** counted in the Habit parity report — correct, they belong to
the Task.

**Duplicate history prevention**

The migration copies each Habit completion to a Task row **once**, then the
dual-write phase keeps them in sync. A user completing via the Habit UI writes
to BOTH; completing via the new Task UI writes only the Task row. The
same-day dedupe on the Task side (`recordRecurringTaskOccurrence` returns
existing row) prevents double-count if the user somehow triggers both.

**Reading history consistently from `RecurringWork`**

`RecurringWork` already separates by `source: RecurringSource.habit |
recurringTask`. Consumers that need "all recurring work" get one list;
consumers that need "only habit history" filter `source == habit`; consumers
that need "only task history" filter `source == recurringTask`. No double
counting possible because the projection never merges them — it presents two
tagged views.

**Logical deduplication: `Habit.taskId` is the canonical bridge**

After migration, a single logical recurring item temporarily exists as both a
Habit and a Task, linked by `Habit.taskId`. `RecurringWork` and its consumers
MUST NOT expose both representations as two separate recurring items. Unified
read rule:

```text
if Habit.taskId == null:
    Habit is an independent legacy recurring item.

if Habit.taskId != null:
    Habit is the legacy representation of the corresponding Task.
    Treat the Task as the canonical logical recurring item.
    Do not expose the Habit separately.
```

Implementation in `RecurringWork.fromHabit` / `recurringWorkFrom`:
- A Habit with `taskId != null` is **excluded** from the `RecurringWork` list.
- Its Task counterpart (with matching `taskId`) is the sole representation.
- This ensures "one logical item = one `RecurringWork` entry" during the
  entire bridge period and after the switch.
- The parity report (`HabitLogProjection`) still runs against the Habit's
  stored counters for audit, but the user-facing recurring-work list shows only
  the Task.

---

#### H.4 Write-path migration checklist

| Write path | Before | After (during dual-write) | Final |
|------------|--------|---------------------------|-------|
| `HabitController.completeHabit` | `Habit.copyWithCompletion` + repo `createCompletion(habitId)` | Also `recordRecurringTaskOccurrence(taskId, date)` if `habit.taskId != null` | Removed (Habit screen retired) |
| `HabitController.uncompleteHabit` | `Habit.copyWithUncompletion` + repo `deleteCompletion` | Also `deleteRecurringTaskOccurrence(taskId, date)` if `habit.taskId != null` | Removed |
| `TaskController.setStatus(done)` (recurring) | Sets `status=done`, `completedAt` | Calls `recordRecurringTaskOccurrence(taskId, date=now())`; keeps `status=todo` | Same as dual-write |
| `TaskController.setStatus(todo)` (recurring) | Sets `status=todo`, clears `completedAt` | Calls `deleteRecurringTaskOccurrence(taskId, date=now())` | Same |
| `ProgressService.projectProgress` | Reads `habitCompletionCount` from `isHabitCompletion` rows | Unchanged (reads both via `ownerId` filter) | Unchanged |
| `TodaySummary.weekCompletionCount` | Counts distinct `habitId@day` from `isHabitCompletion` | Unchanged | Unchanged |
| `Analytics.getHabitCompletionsByCategory` | `getCompletionsForHabit` per habit | Unchanged (reads log) | Unchanged |
| `HabitRepository.getCurrentStreak/Longest/Rate` | Returns stored `Habit` fields | Unchanged | Removed with Habit |
| `HabitLogProjection` (parity) | Re-derives from log | Unchanged (audit tool) | Removed |

**Key new write path:**

```dart
// TaskController (new method)
Future<Result<HabitCompletion>> recordOccurrence(
  String taskId, {
  required DateTime date,
  int count = 1,
  Duration? duration,
  String? note,
  int? moodRating,
  int? energyRating,
}) {
  // Validates task exists and is Recurring
  // Calls habitRepository.recordRecurringTaskOccurrence(...)
}
```

UI for recurring tasks calls this instead of `setStatus(done)`.

---

#### H.5 Schema migration (v5)

```dart
// database.dart, in ensureSchemaVersion():
if (version < 5) {
  // v4 -> v5: add nullable `taskId` to habit records; seed `recurring_task_occurrences`
  // collection (stored under same `habit_completions` key, distinguished by
  // `itemType: 'task'`). No existing key is rewritten.
  version = 5;
}
```

- `Habit` entity gets nullable `String? taskId`.
- `HabitCompletion` rows already have `itemId`/`itemType`; no schema change needed
  for the log — the same storage key holds both.
- Migration step is additive: write `taskId` on existing Habit records when the
  copy runs (step 1 above). No data is moved or deleted.

---

#### H.6 Acceptance criteria (Stage H)

1. A recurring task can be "completed" on a date, and `RecurringWork` shows it
   with `occurrenceRecorded == true` and the correct `lastCompletedAt`.
2. A recurring task completed on 5 consecutive days reports `currentStreak == 5`
   and `totalCompletions == 5` via the log-derived path — **exactly matching**
   the Habit stored-counter semantics.
3. Un-completing a recurring-task occurrence deletes the row and the streak
   re-derives correctly (no stored counters to maintain).
4. Migrating an existing Habit with history produces a Task whose log-derived
   `currentStreak` and `totalCompletions` equal the Habit's stored values.
5. The parity report (`divergentStreakParityProvider`) is empty for all
   migrated items.
6. **Parity gate:** Migration only processes Habits with verdict `agrees`. The
   migration report lists eligible vs quarantined Habits with reasons. No
   divergent Habit is silently migrated.
7. **Non-atomic dual-write recovery:** `reconcileHabitToTask(habitId)` rebuilds
   Task occurrence history from Habit authority. Tests cover:
   * successful dual-write
   * Habit write succeeds / Task mirror fails
   * reconciliation restores Task occurrence history
   * repeated reconciliation is idempotent
8. **Logical deduplication:** `RecurringWork` shows exactly one entry per
   logical recurring item. A Habit with `taskId != null` is excluded; its Task
   counterpart is the sole representation.
9. No screen, entity, or repository is modified outside the migration path; the
   suite stays green at 521+ throughout; goldens unchanged.
10. Rollback: reverting the Stage H commits restores the exact Stage G state
    (Habits still own the write, Tasks are unused, parity report agrees).

---

#### H.7 What Stage H does not do

- Does not delete the `habits` storage key or the `Habit` entity (Retire step
  is separate).
- Does not migrate `longestStreak` into a log-derived value — it stays on the
  Habit for rollback; the Task's longest is log-derived and may be lower.
- Does not change the meaning of `TaskStatus.done` for recurring tasks — they
  remain `todo`/`doing` and express completion only through rows.
- Does not introduce scheduled-consecutive streaks.
- Does not touch analytics date-range logic (that is a separate stage).

---

### Stage J — Migrate Today/Habits completion flow to Task-based recurring occurrences

The next user-facing convergence step: make the Today screen and Habits screen
consume the Stage H Task occurrence write model for migrated habits.

**Context**: Stage I made the Tasks screen use `recordOccurrence`/`deleteOccurrence`
for recurring tasks. But Today screen and Habits screen still call
`HabitController.completeHabit`/`uncompleteHabit`, which writes to the legacy
`HabitCompletion` log (itemType='habit'). Stage H already added dual-write
to mirror these to Task occurrence rows (itemType='task'), but:

1. **Duplicate writes**: Every completion creates TWO rows (itemType='habit' AND 'task')
2. **Read models ignore Task occurrences**: `TodaySummary` filters by `isHabitCompletion`
   which EXCLUDES task occurrences (itemType='task')
4. **RecurringWork doesn't show task occurrences**: `RecurringWork.fromTask()`
   returns `lastCompletedAt: null` and `occurrenceRecorded: false`
5. **Duplicate history**: Migrated habits have duplicate completion rows in the log

**Goal**: Make Today screen and Habits screen use Task-based completion for
migrated habits (those with `taskId != null`), eliminating dual-write and
making Task the single source of truth for migrated recurring work.

---

#### J.1 Current write flow (problem)

```
TodayScreen / HabitsScreen tap
    → HabitController.completeHabit(habitId)
        → HabitRepository.createCompletion(itemType='habit')
        → IF habit.taskId != null:
            → HabitRepository.recordRecurringTaskOccurrence(taskId, ...)
                → creates HabitCompletion(itemType='task')
```

Result: TWO completion rows per action (one 'habit', one 'task').

#### J.2 Desired write flow (target)

```
TodayScreen / HabitsScreen tap
    → IF habit.taskId != null (migrated):
        → TaskController.recordOccurrence(taskId, date: today)
    → ELSE (legacy habit):
        → HabitController.completeHabit(habitId)
```

Single write path per item. No dual-write.

#### J.3 Read model updates required

| Consumer | Current | Target |
|----------|---------|--------|
| `TodaySummary.weekDayStates` | Filters `isHabitCompletion` | Read Task occurrences for migrated habits |
| `TodaySummary.weekCompletionCount` | Filters `isHabitCompletion` | Count Task occurrences for migrated habits |
| `HabitsScreen` / `HabitCard` | Reads `Habit.isCompletedToday` / `todaysCompletions` | Check Task occurrences for migrated habits |
| `RecurringWork.fromTask()` | Returns `lastCompletedAt: null` | Return latest Task occurrence date |
| `RecurringWork.occurrenceRecorded` | `false` for tasks | `true` if Task has occurrence rows |

---

#### J.4 Files to change

| File | Change |
|------|--------|
| `lib/features/today/presentation/screens/today_screen.dart` | Route completion to TaskController for migrated habits |
| `lib/features/habits/presentation/screens/habits_screen.dart` | Route completion to TaskController for migrated habits |
| `lib/features/habits/presentation/widgets/habit_card.dart` | Accept `onComplete`/`onUncomplete` that route by migration status |
| `lib/features/today/domain/today_summary.dart` | Read Task occurrences for migrated habits |
| `lib/features/recurring/domain/recurring_work.dart` | Return task occurrences in `fromTask()` |
| `lib/features/habits/presentation/controllers/habit_controller.dart` | Remove dual-write; only write Habit for non-migrated |
| `lib/features/recurring/presentation/providers/recurring_providers.dart` | Add provider for task occurrences by date |
| `lib/features/tasks/presentation/controllers/task_controller.dart` | No change (methods exist) |

---

#### J.5 Migration completeness validation

Migration is complete for a Habit when ALL of these hold:

```text
✓ Habit.taskId != null
✓ Task exists with matching projectId/goalId/schedule
✓ All HabitCompletion rows copied to Task (itemType='task')
✓ Habit.currentStreak == Task log-derived currentStreak
✓ Habit.totalCompletions == Task log-derived totalCompletions
✓ Parity verdict = agrees
```

**Parity gate enforcement**: Today/Habits screens must NOT write Task occurrences
for habits that fail the parity gate. Those habits stay on the legacy Habit path
until resolved.

---

#### J.5 Dual-write removal from HabitController

Once Stage J is complete, `HabitController.completeHabit`/`uncompleteHabit` should
NO LONGER call `recordRecurringTaskOccurrence`/`deleteRecurringTaskOccurrence`.
The dual-write was a bridge; with Stage J complete, all migrated habits route
through TaskController directly.

```dart
// HabitController.completeHabit - AFTER Stage J
if (habit.taskId != null) {
    // Migrated habits are handled by TaskController in the UI layer
    // Do NOT dual-write. Return error or route to TaskController.
    return Either.left(ValidationFailure(
        'Migrated habit must be completed via TaskController'));
}
// ... existing Habit-only write path
```

---

#### J.6 Provider updates

New provider for Task occurrence checking (for Today/Habits UI):

```dart
/// Whether a migrated recurring task is completed today.
final taskOccurrenceTodayProvider =
    Provider.family<bool, String>((ref, taskId) async {
  final completions = await ref.watch(habitRepositoryProvider)
      .getCompletionsForHabit(taskId); // itemId=taskId, itemType='task'
  final today = AppClock.now().startOfDay;
  return completions.any((c) => c.itemId == taskId && 
      c.itemType == 'task' && 
      c.completedAt.startOfDay == today);
});
```

---

#### J.7 RecurringWork updates

```dart
// In RecurringWork.fromTask:
static RecurringWork? fromTask(Task task) {
  if (task.schedule is! Recurring) return null;

  // Find latest occurrence for this task
  final completions = await _habitRepository.getCompletionsForHabit(task.id);
  final taskCompletions = completions
      .where((c) => c.itemId == task.id && c.itemType == 'task')
      .toList();
  
  DateTime? lastCompleted;
  if (taskCompletions.isNotEmpty) {
    taskCompletions.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    lastCompleted = taskCompletions.first.completedAt;
  }

  return RecurringWork(
    ...
    lastCompletedAt: lastCompleted,  // NOT null!
  );
}

// occurrenceRecorded:
bool get occurrenceRecorded => 
    source == RecurringSource.habit || 
    (source == RecurringSource.recurringTask && lastCompletedAt != null);
```

---

#### J.7 TodaySummary updates

```dart
// weekDayStates: for migrated habits, check Task occurrences
bool _wasDue(Habit habit, DateTime day) => habit.isDueOnDate(day);

// For migrated habits, check Task occurrences instead of Habit completions
bool _isHabitCompletedTodayMigrated(Habit habit, List<HabitCompletion> allCompletions) {
  if (habit.taskId == null) return false;
  final today = AppClock.now().startOfDay;
  return allCompletions.any((c) => 
      c.itemId == habit.taskId && 
      c.itemType == 'task' &&
      c.completedAt.startOfDay == today);
}
```

---

#### J.8 HabitsScreen / HabitCard updates

`HabitCard` receives `onComplete`/`onUncomplete` callbacks from the screen.
The screen must route based on migration status:

```dart
// In HabitsScreen._buildHabitList:
final habit = filteredHabits[index];
final isMigrated = habit.taskId != null;

return HabitCard(
  habit: habit,
  isCompleted: isMigrated 
      ? _isTaskCompletedToday(habit.taskId!) 
      : isCompleted,
  onComplete: isMigrated 
      ? () => ref.read(taskControllerProvider.notifier).recordOccurrence(habit.taskId!)
      : () => _completeHabit(habit.id),
  onUncomplete: isMigrated
      ? () => ref.read(taskControllerProvider.notifier).deleteOccurrence(habit.taskId!)
      : () => _uncompleteHabit(habit.id),
  ...
);
```

---

#### J.9 TodayScreen updates

```dart
// In TodayScreen._HabitRow.onTap:
onTap: () {
  final controller = ref.read(habitControllerProvider.notifier);
  final taskController = ref.read(taskControllerProvider.notifier);
  if (habit.taskId != null) {
    if (done) {
      taskController.deleteOccurrence(habit.taskId!, date: AppClock.now());
    } else {
      taskController.recordOccurrence(habit.taskId!, date: AppClock.now());
    }
  } else {
    if (done) {
      controller.uncompleteHabit(habit.id);
    } else {
      controller.completeHabit(habit.id);
    }
  }
}
```

---

#### J.9 Tests to add

| Test | Purpose |
|------|---------|
| `TodayScreen` completes migrated habit via TaskController | End-to-end write path |
| `TodayScreen` completes legacy habit via HabitController | Backward compatibility |
| `HabitsScreen` completes migrated habit via TaskController | End-to-end write path |
| `TodaySummary` shows task occurrences for migrated habits | Read model |
| `RecurringWork.fromTask()` returns lastCompletedAt | Read model |
| `RecurringWork.occurrenceRecorded` true for tasks with history | Read model |
| Dual-write removed from HabitController | Cleanup |
| Parity gate blocks Task writes for divergent habits | Safety |

---

#### J.10 Acceptance criteria

1. TodayScreen completes migrated habit → Task occurrence row created (single write)
2. TodayScreen uncompletes migrated habit → Task occurrence row deleted
3. HabitsScreen completes migrated habit → Task occurrence row created
4. HabitsScreen uncompletes migrated habit → Task occurrence row deleted
5. Legacy habits (no taskId) still use HabitController path
6. No duplicate completion rows (no dual-write)
7. `RecurringWork` shows `lastCompletedAt` and `occurrenceRecorded: true` for tasks with history
8. TodaySummary shows Task completions for migrated habits
9. All 551+ tests pass; no golden changes
10. `flutter analyze` clean; `dart format` clean

---

#### J.11 What Stage J does NOT do

- Does not retire Habit entity or HabitController
- Does not retire Habits screen (still needed for legacy habits and habit-specific features)
- Does not add Focus → Task attachment UI
- Does not change Analytics or progress metrics
- Does not introduce `paused`/`onHold` or scheduled-consecutive streaks
- Does not change schema (no migration needed)

---

### Not yet planned

Deliberately deferred, listed so their absence reads as a decision:

- **`paused` / `onHold` status.** See §1.1.
- **Focus session → task attachment in the UI.** `FocusSession.taskId` exists and
  is persisted; nothing sets it from a screen yet.
- **Analytics on the new hierarchy.** Analytics still reads habits only; project
  and goal progress have no analytics surface. Would also give
  `habitCompletionCount` the date range F2 left open.
- **Scheduled-consecutive streaks.** A different metric from the day-consecutive
  one Stage G proves parity against. See the parity definition above.
- **Habit entity retirement.** After all screens use Task-based completion, the
  Habit entity, controller, repository, and screen can be retired.
- **Analytics date-range for habitCompletionCount.** The F2 limitation requires
  a date range to be meaningful; this is analytics work.

---

### Stage I — Recurring task completion in the Tasks screen

The smallest coherent step that makes the Stage H write model user-visible.

**Scope**: Update the Tasks screen to use the recurring-task occurrence writer
(`recordOccurrence`/`deleteOccurrence`) instead of `setStatus(done)` for
recurring tasks. This makes the Stage H write model user-visible without
touching any other screen or changing the data model.

**Why this is the next step**. Stage H built the write model but no screen uses
it. The Tasks screen is the only surface where recurring tasks appear alongside
finite tasks, and it currently misuses `setStatus(done)` for recurring items.
Fixing this is a single-screen change with clear boundaries and no data-model
risk.

**Non-negotiable constraints from Stage H**

1. Recurring tasks express completion *only* through occurrence rows (log-derived
   streaks/totals). They never use `TaskStatus.done`.
2. `recordOccurrence` / `deleteOccurrence` are the sole write paths for recurring
   task completion.
3. `TaskStatus.done` is reserved for finite tasks (Once/Unscheduled).
4. Recurring tasks stay in `todo`/`doing`; their `completedAt` is always `null`.

**Files**

- `lib/features/tasks/presentation/screens/tasks_screen.dart` — primary change
- `lib/features/tasks/presentation/controllers/task_controller.dart` — no change
  (methods already exist)
- `test/features/tasks/presentation/tasks_screen_test.dart` — new tests

**UI behaviour changes**

- Tapping a recurring task in the list calls `recordOccurrence(taskId, date:
  today)` instead of `setStatus(done)`.
- The row shows the occurrence as "completed today" without changing the
  task's `status` or `completedAt`. Visual feedback matches the existing "done"
  style but the underlying state remains `todo`.
- A second tap on the same day calls `deleteOccurrence` (idempotent per Stage H).
- The row's icon/text colour reflects "completed today" without implying
  the task is finished.
- Finite tasks (Once/Unscheduled) continue to use `setStatus` exactly as before.

**No changes to**

- HabitController / Habit screen (dual-write remains; Habit remains authoritative
  for migrated habits)
- Task entity (status stays `todo` for recurring; `completedAt` stays `null`)
- Recurring task's `status` / `completedAt` in storage
- Schema (no migration needed)
- Any other screen

**Tests to add**

- Tapping a recurring task creates an occurrence row with correct `itemId`/`itemType`/`completedAt`
- Second tap same day deletes the row (idempotent)
- Tapping a finite task still toggles `done`/`todo` via `setStatus`
- Recurring task's `status` remains `todo` and `completedAt` remains `null`
- Visual "completed today" indicator appears on the row
- `RecurringWork` reflects the occurrence immediately
- `streakParityReportProvider` reflects the occurrence for the corresponding Habit (if migrated)

**Acceptance**

- All 551 existing tests pass + new tests
- No golden changes
- `flutter analyze` clean
- A user can mark a recurring task "done for today" and see it reflected in
  `RecurringWork` and the parity report, while the task itself stays `todo`

**What this stage deliberately does not do**

- Does not migrate the Habits screen or Today screen
- Does not retire the Habit entity or HabitController
- Does not add Focus → Task attachment UI
- Does not change Analytics or progress metrics
- Does not introduce `paused`/`onHold` or scheduled-consecutive streaks

## Delivery status

| Stage | Scope | Status |
| --- | --- | --- |
| A | `TaskSchedule` / `RecurrenceRule` | **Shipped** |
| B | Schema versioning | **Shipped** (`currentSchemaVersion = 5`) |
| C | `Goal` / `Project` entities + repositories | **Shipped** |
| D | Nullable `projectId` / `goalId` links | **Shipped** |
| E | Integration spine | **Shipped** |
| F1 | Tasks surface | **Shipped** |
| F2 | Project / goal detail | **Shipped** |
| G | Habit → Task convergence, read-only half | **Shipped** |
| H | Habit → Task convergence, write half | **Shipped** |
| I | Recurring task completion in Tasks screen | **Shipped** |
| J | Migrate Today/Habits completion to Task-based occurrences | **Designed** |

Every shipped stage left the suite green, and the suite grew from the 251-test
baseline to 551 as each stage added its own coverage.

**Deliberately left out of F2: the habit completion count.** `habitCount` on the
project detail screen is accurate. `habitCompletionCount` is not shown anywhere,
deliberately.

`projectProgressProvider` passes an empty completion list to
`ProgressService.projectProgress`, so `ProjectProgress.habitCompletionCount` is
structurally `0` rather than measured. It is left that way because a completion
count means nothing without a stated date range, and borrowing the one day the
habit controller happens to be holding would report a lifetime number as though
it were today's — worse than showing nothing, because it would look measured.

Two consequences, both load-bearing:

- **No screen may render `habitCompletionCount`.** It is a `0` that means "not
  asked", not "none happened". Nothing in `lib/` reads the field;
  `project_detail_screen_test.dart` asserts that no completion figure appears
  next to an accurate habit count, and that a project with no habits shows no
  habit line at all rather than `0 habits`.
- **The service itself is still correct.** `ProgressService.projectProgress`
  computes the real total from the completions it is given, and
  `progress_service_test.dart` asserts it. The limitation is entirely in what
  this stage chooses to pass it.

Resolving it needs a date range, which is analytics work and out of scope here.

**Provider declaration invariant.** Exactly one declaration per provider name,
anywhere in `lib/`. `test/app/provider_uniqueness_test.dart` enforces it by
scanning the source, and separately proves behaviourally that a habit written
through `habitRepositoryProvider` is observed by `AnalyticsRepositoryImpl` — the
check that fails if the two ever hold separate caches again.