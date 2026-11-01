# Plan 004: Fix Focus Timer Breath Halo Physicality

**Commit:** `$(git rev-parse --short HEAD)`
**Severity:** HIGH
**Category:** Physicality & Origin
**File:** `lib/features/focus/presentation/widgets/focus_timer.dart:429-455`

## Problem
Breathing halo scales entire timer circle (280dp) including progress arc — arc visually distorts while "breathing," breaking precision read.

## Current Code (lines 429-455)
```dart
return AnimatedBuilder(
  animation: _breath,
  builder: (context, child) {
    final t = Curves.easeInOut.transform(_breath.value);
    final scale = 1 + t * 0.035;
    final glow = 0.35 + t * 0.3;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [...],
      ),
      child: Transform.scale(
        key: const ValueKey('focus-breath'),
        scale: scale,
        child: child,  // child includes the CircularProgressIndicator!
      ),
    );
  },
  child: SizedBox(  // This child contains the progress ring
    width: 280,
    height: 280,
    child: Stack([...CircularProgressIndicator...]),
  ),
);
```

## Fix
Move scale/glow to outer container only (as done in `_BreathingHalo` at line 691-722); keep `CircularProgressIndicator` at fixed 1.0 scale.

## Steps
1. Restructure `_buildTimerCircle` to separate the breathing wrapper from the progress ring:
   ```dart
   Widget _buildTimerCircle(...) {
     return AnimatedBuilder(
       animation: _breath,
       builder: (context, _) {
         final t = Curves.easeInOut.transform(_breath.value);
         final scale = 1 + t * 0.035;
         final glow = 0.35 + t * 0.3;

         return Container(
           decoration: BoxDecoration(
             shape: BoxShape.circle,
             boxShadow: [
               BoxShadow(
                 color: color.withValues(alpha: glow * 0.5),
                 blurRadius: 40 + t * 26,
                 spreadRadius: t * 6,
               ),
             ],
           ),
           child: Transform.scale(
             scale: scale,
             child: _buildTimerRing(progress, color, session),  // Extracted, no scale
           ),
         );
       },
     );
   }

   Widget _buildTimerRing(double progress, Color color, FocusSession session) {
     return SizedBox(
       width: 280,
       height: 280,
       child: Stack([...]),  // CircularProgressIndicator at fixed 1.0 scale
     );
   }
   ```
2. Remove the `Transform.scale` wrapper from inside the child Stack.
3. Keep the `ValueKey('focus-breath')` on the outer `Transform.scale` for testing.

## Verification
- Start focus session → progress arc should remain perfectly circular and readable while halo breathes
- Arc stroke width should not visually wobble
- Timer text in center should not scale (it's inside the Stack, not the scaled child)

## Feel-check
Device test: start 25-min focus. Watch the ring for 30 seconds. The progress arc must stay geometrically perfect — any distortion is a fail.