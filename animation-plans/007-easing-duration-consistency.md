# Plan 007: Unify Easing & Duration Tokens

**Commit:** `$(git rev-parse --short HEAD)`
**Severity:** MEDIUM
**Category:** Easing & Duration / Cohesion & Tokens
**Files:** Multiple (see findings 7-15, 27)

## Problem
Hardcoded durations and curves used instead of `AppAnimationTokens`:
- Focus timer setup: 600ms + elasticOut (line 189)
- Focus timer progress ring: 600ms + easeOutCubic (line 483)
- Focus timer resume button: 200ms + elasticOut (line 643)
- Journal empty state: 600ms + elasticOut (line 486)
- Premium gem pulse: 1800ms (line 140-150)
- ProgressRing vs DayRing: 350ms vs 250ms (progress_ring.dart)
- Stagger caps: 660ms vs 400ms (habits vs analytics)
- Route transitions: 250ms (router.dart)

## Fix
1. Add missing tokens to `AppAnimationTokens`
2. Replace all hardcoded values with tokens
3. Remove `elasticOut` from standard entrance animations

## Steps
1. In `lib/app/theme/app_theme.dart`, add to `AppAnimationTokens`:
   ```dart
   /// Very slow: intentional looping CTAs (Premium gem, loading pulse)
   static const Duration verySlow = Duration(milliseconds: 1800);

   /// Standard stagger cap (7 items)
   static const int maxStaggerItems = 7;
   ```
2. Replace hardcoded values:
   - `focus_timer.dart:189` → `.animate().scale(duration: AppAnimationTokens.slow, curve: Curves.easeOutCubic)`
   - `focus_timer.dart:483` → `duration: AppAnimationTokens.slow`
   - `focus_timer.dart:643` → `.animate().scale(duration: AppAnimationTokens.fast, curve: Curves.easeOutCubic)`
   - `journal_screen.dart:486` → `.animate().scale(duration: AppAnimationTokens.slow, curve: Curves.easeOutCubic)`
   - `premium_screen.dart:140` → `duration: AppAnimationTokens.verySlow`
   - `progress_ring.dart:196` → `duration: AppAnimationTokens.slow` (for DayRing)
   - `habits_screen.dart` stagger → `index.clamp(0, AppAnimationTokens.maxStaggerItems)`
   - `analytics_screen.dart` stagger → `index.clamp(0, AppAnimationTokens.maxStaggerItems)`
   - `router.dart:301,329` → `duration: AppAnimationTokens.slow`

3. Remove `Curves.elasticOut` from non-celebratory entrances (keep only for `_CompletionToggle` pop).

## Verification
- Search for hardcoded `.ms` or `Duration(milliseconds:` in lib/ → should only find token definitions
- All entrance animations use `easeOutCubic` or `easeOutBack`
- `elasticOut` only in `_CompletionToggle._popScale`

## Feel-check
All screen entrances feel consistent — same speed, same curve. No "some screens are sluggish, others snappy."