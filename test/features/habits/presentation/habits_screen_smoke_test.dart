import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/habits/presentation/controllers/habit_controller.dart';
import 'package:ascend/features/habits/presentation/providers/habit_providers.dart';
import 'package:ascend/features/habits/presentation/screens/habits_screen.dart';
import 'package:ascend/app/widgets/pill_chip.dart';

import 'habit_controller_test.dart' show FakeHabitRepository;

Habit _habit(
  String id,
  String title,
  String category, {
  int order = 0,
}) =>
    Habit(
      id: id,
      title: title,
      description: '',
      category: category,
      frequency: 'Daily',
      customWeekdays: const [],
      timeOfDay: 'Morning',
      targetCount: 1,
      targetDuration: const Duration(minutes: 20),
      cue: '',
      currentStreak: 3,
      longestStreak: 9,
      totalCompletions: 12,
      streakFreezesUsed: 0,
      lastCompletedAt: DateTime.now().subtract(const Duration(days: 1)),
      sortOrder: order,
      isArchived: false,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 2),
    );

Widget _harness(List<Habit> habits) {
  return ProviderScope(
    overrides: [
      habitControllerProvider.overrideWith(
        (ref) => HabitController(FakeHabitRepository(habits: habits)),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: HabitsScreen())),
  );
}

/// Scrolls the list until the habit card sits above the floating "New Habit"
/// button.
///
/// The pill FAB is deliberately wide, so in a 600px-tall test viewport it
/// overlaps the bottom of a short list and would swallow the drag gesture. On a
/// real phone the same overlap exists but only over the row's trailing edge,
/// past the completion circle, so it is not worth changing the layout for.
Future<void> _liftCardOutOfTheFab(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the hero header, filter pills and habit cards', (
    tester,
  ) async {
    await tester.pumpWidget(_harness([
      _habit('h1', 'Morning run', 'Body', order: 0),
      _habit('h2', 'Read 20 pages', 'Mind', order: 1),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Habits'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Morning run'), findsOneWidget);

    // The second card is below the fold in the default 800px viewport, so this
    // also asserts the list scrolls rather than overflowing.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Read 20 pages'), findsOneWidget);
  });

  testWidgets('filter pill switches the visible list', (tester) async {
    await tester.pumpWidget(_harness([
      _habit('h1', 'Morning run', 'Body', order: 0),
      _habit('h2', 'Read 20 pages', 'Mind', order: 1),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(GlassPill, 'Mind'));
    await tester.pumpAndSettle();

    expect(find.text('Read 20 pages'), findsOneWidget);
    expect(find.text('Morning run'), findsNothing);
  });

  testWidgets('tapping the completion circle completes the habit', (
    tester,
  ) async {
    await tester.pumpWidget(_harness([_habit('h1', 'Morning run', 'Body')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_rounded), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging right reveals the archive background and archives', (
    tester,
  ) async {
    await tester.pumpWidget(_harness([_habit('h1', 'Morning run', 'Body')]));
    await tester.pumpAndSettle();
    await _liftCardOutOfTheFab(tester);

    final card = find.byType(Dismissible);
    final start = tester.getCenter(card);
    final gesture = await tester.startGesture(start);
    // 14 moves, not 8: the first ~40px is eaten by touch slop, and the commit
    // threshold is 0.4 of a 760px-wide card.
    for (var i = 0; i < 14; i++) {
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }

    // The background icon ramps in with the drag rather than snapping in at the
    // commit threshold.
    expect(find.byIcon(Icons.archive_rounded), findsOneWidget);
    expect(find.byIcon(Icons.delete_rounded), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Morning run'), findsNothing);
    expect(find.byType(Dismissible), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging left confirms before deleting', (tester) async {
    await tester.pumpWidget(_harness([_habit('h1', 'Morning run', 'Body')]));
    await tester.pumpAndSettle();
    await _liftCardOutOfTheFab(tester);

    final card = find.byType(Dismissible);
    final start = tester.getCenter(card);
    final gesture = await tester.startGesture(start);
    for (var i = 0; i < 14; i++) {
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.byIcon(Icons.delete_rounded), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    // Held at the threshold until the confirmation is answered.
    expect(find.widgetWithText(AlertDialog, 'Delete Habit'), findsOneWidget);
    expect(find.text('Morning run'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Morning run'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling the delete confirmation springs the card back', (
    tester,
  ) async {
    await tester.pumpWidget(_harness([_habit('h1', 'Morning run', 'Body')]));
    await tester.pumpAndSettle();
    await _liftCardOutOfTheFab(tester);

    await tester.timedDrag(
      find.byType(Dismissible),
      const Offset(-600, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Morning run'), findsOneWidget);
    expect(find.byType(Dismissible), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
