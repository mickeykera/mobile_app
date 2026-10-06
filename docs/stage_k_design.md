# Stage K Design: Habit → Task Convergence (Final)

## Goal
Remove dual-write, make Task the authoritative source for migrated habits, unify all read paths, and retire `HabitController` for migrated items.

---

## Current State (Post-Stage J)
- **Migration marker**: `Habit.taskId != null` (set by `MigrationService.copyEligibleToTasks`)
- **Parity gate**: `MigrationService.runParityGate()` → `MigrationReport` (eligible/quarantined)
- **Dual-write**: `HabitController.completeHabit`/`uncompleteHabit` write to BOTH habit completion log AND task occurrence log when `taskId` present
- **Completion log**: Single `HabitCompletion` table with `itemId`/`itemType` (`habit` | `task`)
- **Read paths**:
  - `TodayScreen` → `RecurringWork` (both sources) + `taskOccurrenceTodayProvider`
  - `HabitsScreen` → `HabitController` (ALL habits, including migrated)
  - `Analytics`/`ProgressService` → `HabitCompletion` filtered by `isHabitCompletion`
  - `Streak parity` → compares Habit stored streaks vs `HabitLogProjection` from habit completions

---

## Stage K Changes

### 1. Read-Path Unification
**Principle**: For any habit with `taskId != null`, the Task is the source of truth.

| Surface | Before | After |
|---------|--------|-------|
| `TodayScreen` | `RecurringWork.fromHabit` + `fromTaskWithHistory` | Same (already unified via `RecurringWork`) |
| `HabitsScreen` | All habits via `HabitController` | **Split**: Non-migrated → `HabitController`; Migrated → `TaskController` + Task occurrences |
| `Analytics` (completions by category) | `ProgressService.habitCompletionsByCategoryFromLog` (filters `isHabitCompletion`) | Include `itemType='task'` rows for migrated habits |
| `Progress` (streaks, heatmap, completion %) | `Habit.currentStreak` / habit completions | For migrated: derive from Task occurrence log |
| `Streak parity gate` | Compares habit stored streaks vs habit completion log | **Retire** for migrated habits (Task has no stored streaks) |

### 2. Write-Path Migration
**Remove dual-write** from `HabitController`:
- `completeHabit(habitId)`: If `habit.taskId != null` → call `TaskController.completeTask(taskId)` ONLY; else write habit completion
- `uncompleteHabit(habitId)`: If `habit.taskId != null` → call `TaskController.uncompleteTask(taskId)` ONLY; else delete habit completion
- Habit stored streaks (`currentStreak`, `longestStreak`, `totalCompletions`) become **read-only legacy** for migrated habits

**Add to `TaskController`**:
- `completeTask(taskId, {count, duration, note, mood, energy})` → writes `HabitCompletion(itemType='task')`
- `uncompleteTask(taskId, date)` → deletes `HabitCompletion(itemType='task')` for that day

### 3. HabitController Deprecation
- `HabitController` manages **only non-migrated habits** (`taskId == null`)
- Migrated habits (`taskId != null`) are **hidden** from `HabitsScreen` habit list
- `HabitsScreen` shows two sections: "Habits" (non-migrated) + "Recurring Tasks" (migrated, from `TaskController`)
- `HabitController` methods `completeHabit`/`uncompleteHabit` assert `taskId == null` (debug) or delegate (release)

### 4. Streak Derivation for Migrated Habits
Tasks don't store streaks. Compute on demand from occurrence log:
- `currentStreak` = consecutive days (per schedule) with occurrence up to today
- `longestStreak` = max consecutive days in history
- `totalCompletions` = sum of `count` across all occurrence rows
- Add `TaskStreakComputer` (pure function, testable) mirroring `HabitLogProjection`

### 5. Reconciliation Cleanup
- `HabitRepository.reconcileHabitToTask` kept for disaster recovery (dual-write era)
- Document as **legacy**; remove after migration window closes

### 6. Database
- No schema change (v5 supports all fields)
- Habit `taskId` remains as permanent link for audit/rollback
- Habit streak fields become frozen for migrated habits

---

## Implementation Phases

### Phase 1: Read-Path Unification (Safe, additive)
1. Extend `ProgressService` with `taskCompletionsByCategoryFromLog`, `taskStreaksByCategory`, `taskCompletionHeatmap`
2. Update `AnalyticsRepositoryImpl` to merge habit + task completions for migrated items
3. Update `RecurringWork.fromTaskWithHistory` to be the standard (already exists)
4. Add `TaskStreakComputer` (port `HabitLogProjection` logic)

### Phase 2: Write-Path Migration
1. Add `TaskController.completeTask` / `uncompleteTask`
2. Modify `HabitController.completeHabit`/`uncompleteHabit` to delegate when `taskId != null`
3. Add debug asserts to catch accidental dual-write

### Phase 3: HabitsScreen Split
1. Create `recurringTasksProvider` (from `TaskController` + schedule filter)
2. Update `HabitsScreen` to render two sections
3. Hide migrated habits from habit list

### Phase 4: Parity Gate Retirement
1. `MigrationService.runParityGate` skips habits with `taskId != null`
2. Document that parity gate is pre-migration only

### Phase 5: Tests
- Update all analytics/progress tests to expect merged habit+task data
- Add `TaskStreakComputer` tests
- Add `HabitsScreen` integration tests for split view
- Verify no dual-write in `HabitController` tests

---

## Acceptance Criteria
- [ ] No dual-write: completing a migrated habit writes exactly ONE `HabitCompletion` row (`itemType='task'`)
- [ ] `HabitsScreen` shows migrated items under "Recurring Tasks" with correct completion state
- [ ] `TodayScreen` shows migrated items via `RecurringWork` (unchanged)
- [ ] Analytics (completions by category, streaks, heatmap) include migrated habits via Task log
- [ ] `HabitController` never receives `completeHabit` for `taskId != null` habits
- [ ] All existing tests pass + new tests for Task streaks and split screen
- [ ] `flutter analyze` clean