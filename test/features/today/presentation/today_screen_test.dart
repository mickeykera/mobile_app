import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:ascend/app/widgets/week_strip.dart';
import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/habits/domain/entities/habit_completion.dart';
import 'package:ascend/features/habits/presentation/controllers/habit_controller.dart';
import 'package:ascend/features/habits/presentation/providers/habit_providers.dart';
import 'package:ascend/features/today/domain/today_summary.dart';
import 'package:ascend/features/today/presentation/screens/today_screen.dart';

import '../../habits/presentation/habit_controller_test.dart'
    show FakeHabitRepository;

Habit _habit(
  String id,
  String title, {
  String frequency = 'Daily',
  int streak = 0,
}) =>
    Habit(
      id: id,
      title: title,
      description: '',
      category: 'Mind',
      frequency: frequency,
      customWeekdays: const [],
      timeOfDay: 'Morning',
      targetCount: 1,
      targetDuration: const Duration(minutes: 20),
      cue: '',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 2),
      sortOrder: 0,
      isArchived: false,
      streakFreezesUsed: 0,
      currentStreak: streak,
      longestStreak: streak,
      totalCompletions: 0,
    );

HabitCompletion _completion(String habitId, DateTime at) => HabitCompletion(
      id: '$habitId@${at.toIso8601String()}',
      habitId: habitId,
      completedAt: at,
      count: 1,
    );

/// A stand-in router.
///
/// The real `routerProvider` builds every screen in the shell, which would pull
/// the focus timer and journal - and their tickers - into a test that only
/// cares about the Today screen's own layout.
GoRouter _stubRouter() => GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(
          path: '/today',
          builder: (context, state) => const TodayScreen(),
        ),
        GoRoute(path: '/habits', builder: (context, state) => const Scaffold()),
        GoRoute(path: '/focus', builder: (context, state) => const Scaffold()),
        GoRoute(
            path: '/analytics', builder: (context, state) => const Scaffold()),
      ],
    );

Widget _harness({
  List<Habit> habits = const [],
  List<HabitCompletion> completions = const [],
  int? streak,
}) {
  final repository = FakeHabitRepository(
    habits: habits,
    completions: completions,
  );

  return ProviderScope(
    overrides: [
      habitControllerProvider
          .overrideWith((ref) => HabitController(repository)),
      habitCompletionsInRangeProvider
          .overrideWithValue((day) async => repository.completions),
      weekCompletionCountProvider.overrideWith((ref) => weekCompletionCount(
            reference: DateTime.now(),
            completions: repository.completions,
          )),
      // The greeting is the only thing on the screen derived from the wall
      // clock, so it is pinned rather than asserted around. The streak is
      // overridden only when a test asks for it, so the no-streak case still
      // exercises the real provider.
      greetingProvider.overrideWithValue('Good morning'),
      if (streak != null) bestStreakProvider.overrideWithValue(streak),
    ],
    child: MaterialApp.router(routerConfig: _stubRouter()),
  );
}

void main() {
  testWidgets('greets, dates the day and shows the streak', (tester) async {
    await tester.pumpWidget(
        _harness(habits: [_habit('h1', 'Morning run')], streak: 12));
    await tester.pumpAndSettle();

    expect(find.text('GOOD MORNING'), findsOneWidget);
    expect(find.text('12 days in a row'), findsOneWidget);
    expect(find.text('Morning run'), findsOneWidget);
  });

  testWidgets('splits habits into outstanding and done', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_harness(
      habits: [_habit('h1', 'Morning run'), _habit('h2', 'Read 20 pages')],
      completions: [
        _completion('h2', DateTime(now.year, now.month, now.day, 8))
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('STILL TO DO'), findsOneWidget);
    expect(find.text('DONE TODAY'), findsOneWidget);
    expect(find.text('1 of 2 habits done'), findsOneWidget);
  });

  testWidgets('tapping a habit row completes it through the controller', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(habits: [_habit('h1', 'Morning run')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Morning run'));
    await tester.pumpAndSettle();

    expect(find.text('DONE TODAY'), findsOneWidget);
    expect(find.text('All done for today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty account explains itself instead of showing a zero', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // The empty state must not repeat the headline the progress card already
    // shows: "Nothing due today" appeared twice before this was split.
    expect(find.text('Start your first habit'), findsOneWidget);
    expect(find.text('No habits yet'), findsOneWidget);
    expect(find.text('Nothing due today'), findsNothing);
    expect(find.text('Add a habit'), findsOneWidget);
    // A 0/0 ring would read as total failure; the empty state is the honest
    // version of "no habits yet".
    expect(find.text('0/0'), findsNothing);
  });

  testWidgets('shows the week strip with the live total', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_harness(
      habits: [_habit('h1', 'Morning run')],
      completions: [
        _completion('h1', DateTime(now.year, now.month, now.day, 8)),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('1 done'), findsOneWidget);
    expect(find.byType(WeekStrip), findsOneWidget);
  });

  testWidgets('no streak badge when nothing is running', (tester) async {
    await tester.pumpWidget(_harness(habits: [_habit('h1', 'Morning run')]));
    await tester.pumpAndSettle();

    expect(find.text('in a row'), findsNothing);
  });

  testWidgets('the week total counts habit-days, not tap rows', (tester) async {
    // Three rows for one habit on one day is one completed habit. Counting rows
    // is what the screen did before weekCompletionCount was wired up.
    final now = DateTime.now();
    await tester.pumpWidget(_harness(
      habits: [_habit('h1', 'Morning run')],
      completions: [
        _completion('h1', DateTime(now.year, now.month, now.day, 8)),
        _completion('h1', DateTime(now.year, now.month, now.day, 9)),
        _completion('h1', DateTime(now.year, now.month, now.day, 10)),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('1 done'), findsOneWidget);
    expect(find.text('3 done'), findsNothing);
  });

  testWidgets('focus card reports no sessions and links to the timer', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(habits: [_habit('h1', 'Morning run')]));
    await tester.pumpAndSettle();

    expect(find.text('No sessions yet today'), findsOneWidget);
    expect(find.byIcon(LucideIcons.batteryCharging), findsOneWidget);
  });
}
