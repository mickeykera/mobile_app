# Ascend

A self-improvement app for intentional daily habit formation, structured
reflection, deep-work focus sessions, and quantifiable progress metrics.

Built with Flutter for Android and iOS.

## Features

| Feature | Description |
| --- | --- |
| **Habits** | Daily habits with category tags (Mind, Body, Craft, Discipline), streak tracking, and personal bests. |
| **Focus** | Pomodoro / custom / stopwatch deep-work sessions with configurable durations, intervals, and session counts. |
| **Journal** | Morning and evening reflection entries with mood tracking. |
| **Analytics** | Habit completion heatmap, completions-by-category charts, focus time, entry counts, and mood trends. |
| **Premium** | Upgrade surface for unlimited habits, advanced analytics, and custom focus sessions. |

## Tech

- **Flutter / Dart** with a feature-first structure (`lib/features/<feature>/{domain,data,presentation}`)
- **Riverpod** for state management and dependency injection
- **go_router** for navigation
- **Freezed + json_serializable** for immutable models and codegen
- **fl_chart** for data visualisation
- **shared_preferences** for local persistence
- **flutter_animate** for transitions

### Theming

The palette is defined once in `lib/app/theme/app_colors.dart` and retuned from
a single teal/mint seed via `ColorScheme.fromSeed`, so changing the seed
retones the whole app. Surfaces are warm neutrals rather than cool greys, which
keeps the cool teal reading as calm instead of clinical.

Both light and dark schemes are covered by a WCAG AA contrast test
(`test/app/theme/app_theme_test.dart`). The dark scheme is hand-picked rather
than derived, so that test guards against readability regressions that would
otherwise be invisible until someone opened the app at night.

## Getting started

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # codegen
flutter run
```

## Tests

```bash
flutter analyze
flutter test
```

## Project layout

```
lib/
  app/            theme, routing, app shell
  features/       habits, focus, journal, analytics, premium
    <feature>/
      domain/       entities, repositories (interfaces)
      data/         models, repository implementations
      presentation/ screens and widgets
test/             mirrors lib/ structure
```

