# Plan 003: Fix Habits Screen Stagger Performance Spike

**Commit:** `$(git rev-parse --short HEAD)`
**Severity:** HIGH
**Category:** Performance
**File:** `lib/features/habits/presentation/screens/habits_screen.dart:579-583`

## Problem
Stagger delay `55 * index.clamp(0, 12)` caps at 660ms but list can have 20+ habits. Items 13+ all fire at same 660ms delay causing frame spike.

## Current Code
```dart
// Habit list item animation
.animate().fadeIn(
  delay: Duration(milliseconds: 55 * index.clamp(0, 12)),
  duration: AppAnimationTokens.medium,
)
```

## Fix
Cap stagger at 7 items (385ms max) and/or switch to scroll-driven entrance.

## Steps
1. Change clamp from 12 to 7:
   ```dart
   delay: Duration(milliseconds: AppAnimationTokens.stagger.inMilliseconds * index.clamp(0, 7)),
   ```
2. (Optional, better) Replace mount-time stagger with scroll-driven entrance using `flutter_animate`'s `onScroll`:
   ```dart
   .animate(
     onPlay: (controller) => controller.forward(),
     onScroll: (scrollable, controller) => controller.forward(),
   ).fadeIn(duration: AppAnimationTokens.medium)
   ```
   This requires wrapping list in `Scrollable` and using `AnimateList` or similar.

## Verification
- Profile with `flutter run --profile` and open DevTools Performance tab
- Scroll to bottom of 20+ habit list → no frame spike at item 13+
- Total mount animation time < 500ms for first 8 items

## Feel-check
First 8 habits cascade smoothly. Remaining habits appear instantly as they enter viewport (if using scroll-driven) or all at once at 385ms (if using capped mount-time).