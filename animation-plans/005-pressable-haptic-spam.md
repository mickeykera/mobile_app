# Plan 005: Fix Pressable Haptic Spam on Scroll Drag

**Commit:** `$(git rev-parse --short HEAD)`
**Severity:** HIGH
**Category:** Accessibility
**File:** `lib/app/widgets/pressable.dart:91-94`

## Problem
`Pressable` fires haptic on `onTapDown` for ALL presses including scroll drags in `GlassPillRow`; one-handed scroll triggers haptic spam.

## Current Code (lines 89-98)
```dart
Widget result = GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTapDown: enabled
      ? (_) {
          _setPressed(true);
          if (widget.haptics) HapticFeedback.lightImpact();
        }
      : null,
  ...
);
```

## Fix
Only fire haptic on genuine tap (not drag). Use `onTapDown` + `onTapUp`/`onTapCancel` to detect tap vs drag, or check `GestureDetector`'s built-in drag detection.

## Steps
1. Add a `_dragStarted` flag to track if gesture became a drag:
   ```dart
   bool _dragStarted = false;
   ```
2. In `onTapDown`, don't fire haptic yet. In `onPanDown`, set `_dragStarted = true`.
3. In `onTapUp`, only fire haptic if `!_dragStarted`:
   ```dart
   onTapUp: enabled
       ? (_) {
           _setPressed(false);
           if (widget.haptics && !_dragStarted) {
             HapticFeedback.lightImpact();
           }
           _dragStarted = false;
         }
       : null,
   ```
4. In `onTapCancel`, reset flag:
   ```dart
   onTapCancel: enabled
       ? () {
           _setPressed(false);
           _dragStarted = false;
         }
       : null,
   ```
5. Add `onPanDown` callback:
   ```dart
   onPanDown: enabled
       ? (_) => _dragStarted = true
       : null,
   ```

## Verification
- In Habits screen, scroll the pill row (Morning/Afternoon/Evening) → zero haptics
- Tap a pill → one light haptic
- Long press a habit card → haptic only on press-down, not during drag
- Run existing Pressable tests (if any)

## Feel-check
One-handed scroll through habit list with pill row at top → no haptic vibration. Tap a pill → crisp single tap feedback.