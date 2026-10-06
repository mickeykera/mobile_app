import 'dart:convert';

import 'package:ascend/app/router.dart';
import 'package:ascend/app/theme/app_theme.dart';
import 'package:ascend/app/widgets/glow_button.dart';
import 'package:ascend/core/database/database.dart';
import 'package:ascend/core/extensions/date_extensions.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/premium/presentation/screens/premium_screen.dart';
import 'package:ascend/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme that disables all animations for golden tests.
ThemeData _themeNoAnimations(ThemeData base) => base.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(builders: {}),
    );

/// The instant every render below is captured at.
///
/// The app draws the weekday, the hour-of-day greeting and which day counts as
/// today, so an unpinned run makes these goldens fail on a different day or at a
/// different hour with no code change to blame. A Wednesday morning also puts
/// the seeded completions and the week strip in the arrangement that exercises
/// the most rows.
final _pinnedNow = DateTime(2025, 6, 11, 9, 30);

const _sizePhone = Size(411 * 3, 915 * 3);
const _sizeTablet = Size(834 * 3, 1112 * 3);

const _routes = <String, String>{
  '/today': 'today',
  '/habits': 'habits',
  '/tasks': 'tasks',
  '/focus': 'focus',
  '/journal': 'journal',
  '/analytics': 'analytics',
  '/premium': 'premium',
  // Drilldowns sit outside the shell, so they get their own goldens rather than
  // being folded into a tab's. `/goals` also proves the entry point added to the
  // Tasks header is reachable.
  '/goals': 'goals',
  '/projects/p1': 'project_detail',
};

Map<String, Object> _fullStorage() {
  final now = _pinnedNow;
  Map<String, Object> habit(String id, String title, String category) => {
        'id': id,
        'title': title,
        'description': '',
        'category': category,
        'frequency': 'Daily',
        'customWeekdays': <int>[],
        'timeOfDay': 'Morning',
        'targetCount': 1,
        'targetDurationMinutes': 20,
        'cue': '',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'sortOrder': 0,
        'isArchived': false,
        'streakFreezesUsed': 0,
        'lastCompletedAt': now.toIso8601String(),
        'currentStreak': 12,
        'longestStreak': 30,
        'totalCompletions': 40,
      };

  Map<String, Object?> goal(String id, String title, {String? description}) => {
        'id': id,
        'title': title,
        'description': description,
        'targetDate': null,
        'category': null,
        'color': null,
        'icon': null,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'sortOrder': 0,
        'status': 'active',
        'completedAt': null,
        'archivedAt': null,
      };

  Map<String, Object?> project(String id, String title, String? goalId) => {
        'id': id,
        'title': title,
        'description': null,
        'goalId': goalId,
        'targetDate': null,
        'category': null,
        'color': null,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'sortOrder': 0,
        'status': 'active',
        'completedAt': null,
        'archivedAt': null,
      };

  Map<String, Object?> task(
    String id,
    String title,
    String status, {
    String? projectId,
    DateTime? dueDate,
  }) =>
      {
        'id': id,
        'title': title,
        'description': null,
        'projectId': projectId,
        'goalId': null,
        'category': null,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'sortOrder': 0,
        'status': status,
        'schedule': dueDate == null
            ? {'kind': 'unscheduled'}
            : {'kind': 'once', 'dueDate': dueDate.toIso8601String()},
        'completedAt': status == 'done' ? now.toIso8601String() : null,
        'archivedAt': null,
      };

  return <String, Object>{
    'habits': jsonEncode([
      habit('h1', 'Morning run', 'Body'),
      habit('h2', 'Read 20 pages', 'Mind'),
      habit('h3', 'Ship the parser', 'Craft'),
      habit('h4', 'No screens after 10', 'Discipline'),
    ]),
    'habit_completions': jsonEncode([
      {
        'id': 'c1',
        'habitId': 'h2',
        'completedAt':
            DateTime(now.year, now.month, now.day, 8).toIso8601String(),
        'count': 1,
      },
      {
        'id': 'c2',
        'habitId': 'h3',
        'completedAt':
            DateTime(now.year, now.month, now.day, 9).toIso8601String(),
        'count': 1,
      },
    ]),
    'focus_sessions': jsonEncode([
      {
        'id': 'f1',
        'mode': 'pomodoro',
        'workDurationMinutes': 25,
        'breakDurationMinutes': 5,
        'longBreakDurationMinutes': 15,
        'sessionsBeforeLongBreak': 4,
        'completedSessions': 1,
        'totalWorkMinutes': 25,
        'totalBreakMinutes': 5,
        'startedAt': now.subtract(const Duration(hours: 2)).toIso8601String(),
        'endedAt': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'pausedAt': null,
        'accumulatedWorkTime': null,
        'accumulatedBreakTime': null,
        'habitId': 'h1',
        'projectName': null,
        'focusRating': null,
        'reflectionNotes': null,
        'isActive': false,
        'isPaused': false,
        'isBreak': false,
      }
    ]),
    'journal_entries': jsonEncode([
      {
        'id': 'j1',
        'type': 'daily',
        'date': DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        'responses': <String, String>{},
        'moodRating': 4,
        'energyRating': 3,
        'tags': <String>[],
        'gratitudeNote': 'A good day.',
        'createdAt': now.subtract(const Duration(days: 1)).toIso8601String(),
        'updatedAt': now.subtract(const Duration(days: 1)).toIso8601String(),
      }
    ]),
    // Tasks are seeded across all three statuses and both kinds of section, so
    // the Tasks golden draws real rows - a dated one, an in-progress one, a
    // ticked one and an inbox one - rather than the empty state, which would
    // measure none of the row layout the screen actually ships.
    // Goals give the hierarchy a top, so the Goals golden draws the real
    // goal -> project shape and p1 has a parent to belong to.
    'goals': jsonEncode([
      goal('g1', 'Make the parser solid'),
      goal('g2', 'Play music again', description: 'One practice a day'),
    ]),
    'projects': jsonEncode([
      project('p1', 'Ship the parser', 'g1'),
      project('p2', 'Learn the violin', 'g2'),
    ]),
    'tasks': jsonEncode([
      task('t1', 'Draft the migration plan', 'todo',
          dueDate: DateTime(now.year, now.month, now.day)),
      task('t2', 'Email the team', 'todo'),
      task('t3', 'Book the venue', 'doing', projectId: 'p1'),
      task('t4', 'Write the test fixtures', 'done', projectId: 'p1'),
      task('t5', 'Buy sheet music', 'todo', projectId: 'p2'),
    ]),
  };
}

ProviderContainer _boot(WidgetTester tester) {
  final database = DatabaseService();
  database.close();
  SharedPreferences.setMockInitialValues(_fullStorage());
  database.initialize();

  // Compute task occurrence status for seeded tasks synchronously
  final taskOccurrences = <String, bool>{};
  final allCompletions = database.getJsonList('habit_completions') ?? [];
  final today = DateTime(2025, 6, 11).startOfDay;
  for (final completion in allCompletions) {
    if (completion['itemType'] == 'task') {
      final taskId = completion['itemId'] as String?;
      final completedAt = DateTime.parse(completion['completedAt'] as String);
      if (taskId != null && completedAt.startOfDay == today) {
        taskOccurrences[taskId] = true;
      }
    }
  }

  final container = ProviderContainer(
    overrides: [
      databaseServiceProvider.overrideWithValue(database),
      taskOccurrenceTodayProvider
          .overrideWith((ref, taskId) => taskOccurrences[taskId] ?? false),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpRoute(
  WidgetTester tester,
  String route,
  Brightness brightness,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  // Disable infinite animations for golden tests.
  GlowButton.debugDisablePulsing = true;
  testDisablePremiumAnimations();

  final container = _boot(tester);
  final router = container.read(routerProvider);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: router,
      theme: _themeNoAnimations(AppTheme.lightTheme),
      darkTheme: _themeNoAnimations(AppTheme.darkTheme),
      themeMode:
          brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    ),
  ));
  await tester.pumpAndSettle();

  router.go(route);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  setUpAll(() => AppClock.debugSetNow(() => _pinnedNow));
  tearDownAll(AppClock.debugResetNow);

  for (final brightness in Brightness.values) {
    final label = brightness == Brightness.dark ? 'dark' : 'light';
    for (final sizeEntry
        in {'phone': _sizePhone, 'tablet': _sizeTablet}.entries) {
      final sizeLabel = sizeEntry.key;
      final size = sizeEntry.value;

      group('$sizeLabel $label', () {
        for (final routeEntry in _routes.entries) {
          testWidgets('${routeEntry.value}_${sizeLabel}_$label',
              (tester) async {
            await _pumpRoute(tester, routeEntry.key, brightness, size);

            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                  'goldens/${routeEntry.value}_${sizeLabel}_$label.png'),
            );
          });
        }
      });
    }
  }
}
