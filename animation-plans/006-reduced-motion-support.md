# Plan 006: Add Reduced Motion Support

**Commit:** `$(git rev-parse --short HEAD)`
**Severity:** MEDIUM
**Category:** Accessibility
**Files:** 
- `lib/app/app.dart:167-170` (loading screen)
- `lib/features/premium/presentation/screens/premium_screen.dart:140-150` (gem pulse)
- `lib/app/widgets/pressable.dart` (press scale)
- `lib/features/focus/presentation/widgets/focus_timer.dart` (breath, entrance)
- All `.animate()` usages across 12 screens

## Problem
Animations run forever with no `prefersReducedMotion` check — violates WCAG 2.3.3.

## Fix
Create a global `AnimationConfig` utility and wrap all animation starts with reduced-motion guard.

## Steps
1. Create `lib/app/theme/animation_config.dart`:
   ```dart
   import 'package:flutter/material.dart';

   class AnimationConfig {
     static bool shouldAnimate(BuildContext context) {
       return MediaQuery.maybeOf(context)?.disableAnimations ?? false == false;
     }

     static Duration getDuration(BuildContext context, Duration normal) {
       return shouldAnimate(context) ? normal : Duration.zero;
     }
   }
   ```
2. In `Pressable` (pressable.dart), wrap scale animation:
   ```dart
   duration: AnimationConfig.getDuration(
     context,
     Duration(milliseconds: _pressed ? AppAnimationTokens.fast.inMilliseconds : AppAnimationTokens.medium.inMilliseconds),
   ),
   ```
3. In `_LoadingScreen` (app.dart), check before starting controller:
   ```dart
   @override
   void initState() {
     super.initState();
     if (AnimationConfig.shouldAnimate(context)) {
       _controller = AnimationController(...);
       _controller.repeat();
     }
   }
   ```
4. In `GlowButton` (glow_button.dart), check before starting pulse:
   ```dart
   if (widget.pulsing && !GlowButton.debugDisablePulsing && AnimationConfig.shouldAnimate(context)) {
     _pulse.repeat(reverse: true);
   }
   ```
5. In `_BreathingHalo` and focus timer breath, check before starting.
6. For `flutter_animate` usages, wrap with `animate(enabled: AnimationConfig.shouldAnimate(context))`.

## Verification
- Enable "Remove animations" in Android/iOS accessibility settings
- Launch app → loading screen should show static logo, no pulse
- Navigate to Premium → gem should be static
- Press buttons → no press scale animation
- All transitions should be instant

## Feel-check
With reduced motion ON: app should feel snappy, not broken. Every state change happens instantly but visibly.