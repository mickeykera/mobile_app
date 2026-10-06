# Ascend — Agent Context

## Mission

Finish the Ascend productivity application without unnecessary rewrites.

Ascend is a modern productivity app built with Flutter/Dart.

The conceptual model is:

Goal = why
Project = body of work
Task = unit of work
Schedule = when
Focus = time spent
Completion = what happened
Progress = derived result

A user does not need a Goal or Project to create work.
Projectless work belongs to Inbox.

---

# Current Architecture Direction

The final architecture is:

Goal
  └── Project
        └── Task
              └── Schedule

Task can be:
- unscheduled
- one-time
- recurring

Habit is NOT intended to remain a separate parallel work-item system.

A Habit is conceptually a recurring Task.

However:

DO NOT perform a giant Habit → Task rename.

Migration must be incremental and backwards-compatible.

---

# Existing Product

Ascend already has:

- Today
- Habits / recurring work
- Focus
- Journal
- Analytics
- Premium
- calendar/date navigation
- habit completion history
- snooze
- reschedule
- streaks
- freeze-related legacy behavior
- persistent repositories using SharedPreferences/JSON
- deterministic AppClock for testability
- Lucide icons
- light/dark themes
- earth-tone visual design

Visual direction:

- minimalist
- premium
- calm
- muted earth tones
- sage
- clay
- stone
- bronze
- warm stone neutrals
- dark: #12100E
- light: #F6F4F1

Do NOT replace this visual language with generic SaaS blue/indigo styling.

---

# Important Engineering Rules

1. Preserve existing behavior unless the current stage explicitly changes it.

2. Prefer additive migrations.

3. Never silently delete user data.

4. Never discard legacy fields before their replacement exists.

5. Never perform destructive migration without verification.

6. Persistent migration must be idempotent.

7. Failed migration must remain retryable.

8. Deterministic IDs must be used whenever possible.

9. Repository caches must be considered when designing startup migrations.

10. Never run a background migration if the UI can read stale memoized repository state.

11. Pure domain logic must not read DateTime.now() directly.

12. Use AppClock for time-dependent behavior.

13. Derived calculations should have one canonical implementation.

14. Do not duplicate recurrence/streak/progress logic across screens.

15. Keep UI out of domain/repository code.

16. Do not introduce SQLite/Drift unless explicitly approved.

17. Do not redesign unrelated features.

18. Do not regenerate goldens unless a deliberate visual change is part of the current stage.

19. Do not fix unrelated pre-existing test failures while working on a migration stage.

20. Before changing architecture, inspect the actual current implementation.

---

# Persistence

Current persistence is SharedPreferences + JSON.

Repositories generally:
- load once
- memoize in memory
- rewrite the persisted collection

This is acceptable for the current architecture.

Do not migrate the database technology simply because the model is becoming richer.

Schema version currently reached version 5.

There is also a separate migration marker:

habit_task_migration v1

These are conceptually separate:
- database schema version
- domain/data migration marker

Do not bump either without justification.

---

# Stage History

## Stage A

Completed.

Implemented:

- TaskSchedule value object
- Unscheduled
- Once
- Recurring
- RecurrenceRule
- Daily
- Weekday
- Weekend
- Custom
- No
- AppClock-based pure schedule evaluation
- schema version foundation

Result:

269 tests passing
Analyzer clean
Formatter clean
Goldens unchanged

---

# Goal / Project Architecture

Goal:

- id
- title
- createdAt
- updatedAt
- sortOrder
- status

Status:

active
completed
archived

Optional:
- description
- targetDate
- category
- color
- icon
- completedAt
- archivedAt

Project:

- id
- title
- createdAt
- updatedAt
- sortOrder
- status

Status:

active
completed
archived

Optional:
- description
- goalId
- targetDate
- category
- color
- completedAt
- archivedAt

Projects may exist without Goals.

Tasks may exist without Projects.

---

# Task Architecture

Canonical future work-item model:

Task

A Task has a TaskSchedule.

TaskSchedule variants:

Unscheduled
Once(DateTime)
Recurring(RecurrenceRule, dueAt?, snoozedUntil?)

Recurring Tasks are the conceptual replacement for the separate Habit work-item model.

The Habits UI should eventually become a recurring-task filter/view rather than a separate entity system.

Do this incrementally.

---

# Progress Architecture

Eventually:

ProgressService

should become the single canonical source for derived progress.

Progress must distinguish:

1. finite task completion
2. recurring activity
3. focus/activity

Recurring completion should NOT simply inflate finite project task-completion percentages.

Project progress therefore has separate concepts such as:

- finite task completion %
- focus/activity
- recurring activity

Do not mix them into one meaningless percentage.

---

# Focus Architecture

FocusSession eventually links to:

taskId
projectId

Focus outcomes:

completed
interrupted
abandoned

A focus session should link to the most specific relevant object.

Future direction:

Focus may target either a Task or Project.

Do not migrate this unless the current stage explicitly requests it.

---

# L0 — COMPLETE

L0 migration migrated legacy Habit identity toward recurring Task identity.

Production changes included:

habit_repository_impl.dart
- Habit.taskId is now persisted.

habit_task_identity.dart
- deterministic task identity
- deterministic completion identity
- LegacyHabitCapabilities

migration.dart
- state-machine migration
- occurrence-based history copying
- verification
- parity gate
- dangling-ID recovery

migration_runner.dart
- production marker-gated runner

recurring_providers.dart
- migration runner provider

app.dart
- awaited migration during startup

recurring_work.dart
- corrected stale comment

L0 migration identity:

Task:
task_hm_<habitId>

Completion:
completion_hm_<legacyCompletionId>

These IDs are deterministic.

---

# L0 Safety Rules

Migration marker is written ONLY after full verification.

If migration fails:

- marker remains absent
- next launch retries

History is copied rather than moved.

Legacy completion rows remain canonical during the bridge.

Copied Task completion rows use:

habitId: null

Analytics and heatmap currently exclude Task rows to prevent double counting.

No legacy retirement happened in L0.

---

# L0 Legacy Capabilities

These five fields remain intentionally retained:

- targetCount
- targetDuration
- cue
- timeOfDay
- streakFreezesUsed

They MUST NOT be deleted yet.

They need an eventual canonical home during L1+.

---

# L0 Verification

Current checkpoint:

590 tests passing.

Analyzer:
zero errors.

Formatter:
clean.

Schema:
version 5.

Migration:
habit_task_migration v1.

L0 has NOT been retired.

---

# Known Pre-existing Test Failures

There are 10 failures unrelated to L0:

6:
habits_screen_smoke_test.dart

Cause:
Flutter SDK assertion involving ListTiles in the actions sheet.

4:
stale habits_* goldens

Cause:
goldens were not regenerated after an earlier theme restyle.

These are NOT migration failures.

Do not silently "fix" them during migration work.

---

# L1 Blockers

Before retiring the old Habit model, resolve:

1. Streak semantics.
2. Irrecoverable longestStreak.
3. Canonical home for:
   - targetCount
   - targetDuration
   - cue
   - timeOfDay
   - streakFreezesUsed
4. No double counting at cutover.
5. Repair path for parity-quarantined habits.
6. Duplicate Task cleanup policy.
7. Migration marker versioning if identity changes.

---

# Streak Design Requirements

The final recurring Task streak system must explicitly define:

- successful occurrence
- scheduled occurrence
- missed occurrence
- snoozed occurrence
- rescheduled occurrence
- completion after midnight
- timezone/date boundary
- archived recurring Task
- recurrence-rule changes
- streak freeze behavior
- current streak
- longest streak

Never infer these casually.

Write tests around every decision.

---

# Five Legacy Capabilities

Before deleting or migrating them, determine the canonical owner.

targetCount
- determine whether this describes an occurrence target or Task target.

targetDuration
- determine whether this belongs to Task or Completion/activity.

cue
- determine whether this is Task metadata.

timeOfDay
- determine whether this is schedule data or presentation metadata.

streakFreezesUsed
- determine whether this belongs to streak state/history rather than the Task itself.

Do not force all five into TaskSchedule.

---

# Migration Philosophy

Every migration should be:

- additive first
- deterministic
- idempotent
- retryable
- verified
- reversible where possible
- tested against real repository persistence

Never rely solely on in-memory objects for migration verification.

---

# Current Development Strategy

Work in small stages.

For every stage:

1. Inspect actual code.
2. Identify dependencies.
3. State what will change.
4. Implement only the requested scope.
5. Add focused tests.
6. Run formatter.
7. Run analyzer.
8. Run tests.
9. Compare against baseline.
10. Report files changed.
11. Report test count.
12. Stop.

Do not continue automatically into the next stage.

---

# Agent Behavior

You are operating as a coding agent in an existing production-style codebase.

Do NOT:

- rewrite the project
- replace architecture because it is personally preferred
- rename large portions of the codebase unnecessarily
- add dependencies without justification
- redesign the UI
- introduce unrelated abstractions
- remove legacy fields prematurely
- weaken tests to make them pass
- delete failing tests
- update goldens just to hide regressions
- declare a migration successful without persisted-state verification

If a required architectural decision is ambiguous:

STOP.

Explain:
- what is ambiguous
- what choices exist
- what each choice affects
- what you recommend

Then wait for approval.

---

# Token Efficiency

The user is using an external model through OpenRouter with limited/free inference.

Therefore:

- Do not repeatedly explain the entire architecture.
- Read existing documentation before asking questions.
- Search the repository before making assumptions.
- Inspect only relevant files.
- Avoid dumping entire files into responses.
- Avoid long summaries after every command.
- Keep progress reports concise.
- Prefer small focused changes.
- Do not repeat already-known context.
- Do not run unnecessary tests repeatedly.
- Run targeted tests during iteration and the full suite at the end.
- Do not spend tokens explaining obvious code.

At the end of a stage, report:

STATUS
FILES CHANGED
TESTS
ANALYZER
FORMATTER
GOLDENS
RISKS
NEXT STAGE

Then STOP.

---

# Current Task

L1.4 Parity-Gate and Migration Prerequisites — **complete as of 2026-10-06.**
See `docs/ascend-stage-l1-design.md` → "Phase 4" for the definitive write-up.

Final stance of the stage, superseding the open items below:

1. Recurring Task streak semantics — day-consecutive, ageing-free. `RecurringStreak` owns the rule (L1.2).
2. longestStreak — persisted value is the high-water mark; derived is diagnostic only (L1.2).
3. Reads — one ownership rule: `taskId == null` reads stored counters, `taskId != null` reads the Task log (L1.2).
4. Five legacy capabilities — all five have a canonical home on `Task`, written
   at creation, re-asserted in `_verify`, backfilled by the diff-based
   capability bridge (`syncTaskCapabilities`, run every launch). The **Habit
   remains the writer** of all five until Stage L2 moves the write path; the
   bridge methods are the named removal point.
5. Parity boundary hardened for cutover (L1.4):
   - the gate throws when habits **or completions** cannot be read, so an
     unreadable log cannot read as a clean pass;
   - `MigrationVerification.deterministicIdentity` pins that this run's created
     Task carries `taskIdForHabit` (adopted Tasks exempt);
   - `HabitTaskMigrationRunner.writeMarker` is a `@visibleForTesting` seam; the
     marker records completion and is written only after full verification, so
     a failed/partial write retries next launch;
   - dangling-`taskId` recovery, repeated-migration idempotency, failure/crash
     injection, parity-quarantine preservation, and data safety are pinned by
     test (`test/features/recurring/l1_4_parity_hardening_test.dart`, 21 tests).
6. Marker stays `habit_task_migration` v1; schema stays 5; no legacy field
   deleted; no history rewritten; no UI change. Full suite: 703 pass / 10 fail
   (same pre-existing set, byte-identical goldens); analyzer 25 (unchanged).

Remaining for L2+: moving the five writers to Task and deleting the bridge,
the parity-quarantine repair workflow, duplicate Task resolution, and
Habit/Task retirement.

## Constraints still in force

The L1.3 design adds additive Task fields and a launch-time bridge; the
standing constraints below are unchanged for subsequent stages.

NO schema version change without an explicit decision recorded in the design doc.

NO migration execution outside the marker-gated runner and its bridge.

NO deletion of user data or legacy fields.

Each stage must be approved independently before beginning.
