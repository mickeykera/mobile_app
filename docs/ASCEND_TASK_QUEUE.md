# Ascend Task Queue

## Completed Stages

- [x] **L1.1 Design Audit & Design Resolution** - Completed 2026-10-05
  - Resolved all 8 L1 blockers (see `docs/ascend-stage-l1-design.md` for RESOLVED/BLOCKED status)
  - No production code changes, schema changes, migration execution, UI changes, or field deletions
  - Design-only audit complete
- [x] **L1.2 Read-Path Unification** - Completed 2026-10-05
  - `RecurringStreak` is the single day-consecutive arithmetic; `HabitLogProjection` and `TaskStreakComputer` are adapters over it
  - Task streak computer no longer takes a `now`: the canonical rule is ageing-free
  - Ownership rule enforced on every recurring read: `taskId == null` reads stored counters, `taskId != null` reads the Task log, never both
  - Rewired `ProgressService`, `AnalyticsRepositoryImpl`, Today summary, Habits hero, and `taskStreaksByCategoryProvider`
  - Persisted `Habit.longestStreak` untouched; derived longest is diagnostic only
  - No schema, migration, entity, or quarantine changes
- [x] **L1.3 Capability Ownership Resolution** - Completed 2026-10-06
  - See `docs/ascend-stage-l1-design.md` → "Canonical Legacy Capability Model" for the definitive model
  - `targetCount`, `targetDuration`, `cue`, `timeOfDay` added to `Task`; `streakFreezesUsed` becomes `Task.streakFreezeUsage` (`StreakFreezeUsage` value object)
  - `_createTaskFor` writes the five; `_verify` asserts them on the Task (`taskCapabilitiesPresent`/`taskCapabilitiesLost`); legacy-side `matchesHabit` still verifies
  - New capability bridge `MigrationService.syncTaskCapabilities`, run on every launch (diff-based, never creates/links, never writes the Habit) so post-L0 installs are backfilled and post-migration edits are picked up
  - No marker bump, no schema version bump (5), no field deletions, no history rewrite, no UI change
  - +34 tests (29 ownership + 5 value object); full suite 682 pass / 10 fail — same 10 pre-existing failures, byte-identical golden set
- [x] **L1.4 Parity-Gate and Migration Prerequisites** - Completed 2026-10-06
  - Parity gate now throws when habits **or completions** cannot be read — an unreadable log must not read as a clean pass that quarantines the whole install
  - `MigrationVerification.deterministicIdentity`: a Task this run *created* must carry `taskIdForHabit`; adopted Tasks are exempt, so a retry after a lost link always rediscovers the Task
  - `HabitTaskMigrationRunner.writeMarker` extracted as a `@visibleForTesting` seam; a marker that does not land reads as unmigrated and retries next launch; marker written only after full verification
  - Dangling-`taskId` recovery exercised across launches (missing Task, malformed/partial capability data, deterministic adoption, older random-id orphan adoption) — never fabricates duplicates, never auto-deletes
  - Repeated-migration idempotency, failure/crash injection (Task creation, mid-copy completion write, marker write, capability-sync write), parity-quarantine preservation, and data safety pinned by test over the real repositories
  - No marker bump, no schema version bump (5), no field deletions, no history rewrite, no UI change
  - +21 tests (6 groups in `test/features/recurring/l1_4_parity_hardening_test.dart`); full suite 703 pass / 10 fail — same 10 pre-existing failures, byte-identical golden set; analyzer 25 (unchanged)

## Pending Stages

- [ ] L2+ Write-Path Migration and Full Retirement

## Notes

- L1.1 through L1.4 are marked complete
- L2+ is NOT marked complete
- Each stage must be approved independently before beginning
- The L1.3 capability bridge (`_syncCapabilities` / `syncTaskCapabilities`) is the named removal point: it must be deleted in the same change that moves the five writers to the Task side
