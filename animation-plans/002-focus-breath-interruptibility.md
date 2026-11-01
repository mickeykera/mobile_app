# Plan 002: Fix Focus Timer Breath Controller Interruptibility

**Commit:** `$(git rev-parse --short HEAD)`
**Severity:** HIGH
**Category:** Interruptibility
**File:** `lib/features/focus/presentation/widgets/focus_timer.dart:48-85`

## Problem
`_breath` controller uses `repeat(reverse: true)` but `_syncBreath()` calls `stop()` then `animateTo(0)` — if pause happens mid-inhale, the `animateTo` fights the repeat loop.

## Current Code (lines 53-85)
```dart
late final AnimationController _breath;

@override
void initState() {
  super.initState();
  _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4000),
  );
}

void _syncBreath() {
  final session = widget.session;
  final shouldBreathe =
      session != null && session.isActive && !session.isPaused;

  if (shouldBreathe) {
    if (!_breath.isAnimating) _breath.repeat(reverse: true);
  } else {
    _breath.stop();
    _breath.animateTo(0, duration: AppAnimationTokens.slow);
  }
}
```

## Fix
Replace `repeat(reverse: true)` with manual forward/reverse cycle. Use `stop(canceled: true)` to cleanly cancel before animating to 0.

## Steps
1. Add a `_breathCycle()` method that manually drives forward then reverse:
   ```dart
   void _breathCycle() {
     if (!_breath.isAnimating) {
       _breath.forward().then((_) {
         if (mounted && _breath.isAnimating) {
           _breath.reverse().then((_) => _breathCycle());
         }
       });
     }
   }
   ```
2. In `_syncBreath`, replace `repeat(reverse: true)` with `_breathCycle()`:
   ```dart
   if (shouldBreathe) {
     if (!_breath.isAnimating) _breathCycle();
   } else {
     _breath.stop(canceled: true);
     _breath.animateTo(0, duration: AppAnimationTokens.slow);
   }
   ```
3. In `dispose`, stop cleanly:
   ```dart
   _breath.stop(canceled: true);
   _breath.dispose();
   ```

## Verification
- Start session → pause mid-inhale → verify halo settles to neutral (scale 1.0) without oscillation
- Resume after pause → verify breath resumes smoothly from neutral
- Rapid pause/resume 5x → no jank, no overlapping animations

## Feel-check
Device test: start focus, wait for inhale peak, hit pause. Halo should exhale smoothly to rest in 350ms, not snap or oscillate.