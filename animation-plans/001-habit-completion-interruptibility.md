# Plan 001: Fix Habit Completion Toggle Interruptibility

**Commit:** `$(git rev-parse --short HEAD)`
**Severity:** HIGH
**Category:** Interruptibility
**File:** `lib/features/habits/presentation/widgets/habit_card.dart:539-584`

## Problem
`_CompletionToggle._pop` controller restarts from 0 on every completion toggle without checking if already animating. Rapid taps queue overlapping pops leaving circle oversized.

## Current Code (lines 572-585)
```dart
@override
void didUpdateWidget(_CompletionToggle oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (widget.isCompleted == oldWidget.isCompleted) return;

  if (widget.isCompleted) {
    HapticFeedback.mediumImpact();
    _pop.forward(from: 0);  // BUG: no guard if already animating
  } else {
    _pop.animateTo(1, duration: AppAnimationTokens.medium);
  }
}
```

## Fix
Add guard to prevent overlapping animations. When completing, only forward if not already animating. When uncompleting, stop any running animation cleanly.

## Steps
1. In `didUpdateWidget`, before `_pop.forward(from: 0)`, add:
   ```dart
   if (_pop.isAnimating) return;
   ```
2. In the `else` branch (uncomplete), use `stop(canceled: true)` before `animateTo` to cancel any in-flight pop:
   ```dart
   _pop.stop(canceled: true);
   _pop.animateTo(1, duration: AppAnimationTokens.medium);
   ```
3. In `dispose`, ensure controller is stopped cleanly:
   ```dart
   _pop.stop(canceled: true);
   _pop.dispose();
   ```

## Verification
- Tap complete rapidly 5x → circle should pop once, not queue 5 pops
- Tap complete, immediately tap uncomplete → circle should settle to 1.0 scale without overshoot
- Run `flutter test test/features/habits/presentation/habits_screen_smoke_test.dart` (if exists)

## Feel-check
Slow-motion recording: complete → uncomplete → complete in <300ms. Circle should never exceed 1.12 scale.