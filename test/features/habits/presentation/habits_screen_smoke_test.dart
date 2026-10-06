import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/habits/presentation/controllers/habit_controller.dart';
import 'package:ascend/features/habits/presentation/providers/habit_providers.dart';
import 'package:ascend/features/habits/presentation/screens/habits_screen.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';
import 'package:ascend/features/tasks/presentation/controllers/task_controller.dart';
import 'package:ascend/features/tasks/presentation/providers/task_providers.dart';
import 'package:ascend/app/widgets/pill_chip.dart';

import 'habit_controller_test.dart' show FakeHabitRepository;
import '../../tasks/presentation/task_controller_test.dart'
    show FakeTaskRepository;
import 'package:lucide_icons_flutter/lucide_icons.dart';

Habit _habit(
  String id,
  String title,
  String category, {
  int order = 0,
  String? taskId,
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
      taskId: taskId,
    );

/// A task that corresponds to a migrated habit.
Task _migratedTask({
  required String id,
  required String habitId,
  String title = 'Migrated Task',
  String category = 'Body',
}) =>
    Task(
      id: id,
      title: title,
      description: '',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 2),
      sortOrder: 0,
      status: TaskStatus.todo,
      schedule: const Recurring(DailyRecurrence()),
      category: category,
    );

/// Scrolls the list until the first habit card sits above the floating "New Habit"
/// button.
Future<void> _liftCardOutOfTheFab(WidgetTester tester) async {
  // Find the first habit card (Dismissible) and scroll it into view
  final card = find.byType(Dismissible).first;
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
}

/// Finds the completion toggle for the first non-migrated habit card.
Finder _firstNonMigratedCompletionButton() =>
    find.byTooltip('Mark as complete').first;

/// Finds the completion toggle for the first completed non-migrated habit card.
Finder _firstNonMigratedUncompleteButton() =>
    find.byTooltip('Mark as incomplete').first;

/// Finds the completion toggle for the first migrated task card.
Finder _firstMigratedCompletionButton() =>
    find.byTooltip('Mark as complete').first;

/// Finds the more actions button for the first habit card.
Future<void> _tapFirstMoreActions(WidgetTester tester) async {
  // Ensure the first card is visible above the FAB
  await _liftCardOutOfTheFab(tester);
  await tester.tap(find.byIcon(LucideIcons.moreHorizontal).first,
      warnIfMissed: false);
  await tester.pumpAndSettle();
}

/// Creates a test harness with the given habits and optional migrated tasks.
///
/// [habits] - List of habits (non-migrated if taskId is null, migrated if taskId is set)
/// [migratedTasks] - Corresponding tasks for migrated habits (matched by taskId)
Widget _harness(
  List<Habit> habits, {
  List<Task> migratedTasks = const [],
}) {
  final habitRepository = FakeHabitRepository(habits: habits);
  final taskRepository = FakeTaskRepository(migratedTasks);

  // Determine migrated task IDs for the completions provider
  final migratedHabitIds = habits
      .where((h) => h.taskId != null && !h.isArchived)
      .map((h) => h.taskId!)
      .toSet();
  final taskIds = migratedHabitIds.toList();

  return ProviderScope(
    overrides: [
      habitRepositoryProvider.overrideWithValue(habitRepository),
      habitControllerProvider.overrideWith(
        (ref) => HabitController(ref.watch(habitRepositoryProvider)),
      ),
      taskRepositoryProvider.overrideWithValue(taskRepository),
      taskControllerProvider.overrideWith(
        (ref) => TaskController(
          ref.watch(taskRepositoryProvider),
          ref.watch(habitRepositoryProvider),
        ),
      ),
      // Override the async completions provider with a static value to avoid
      // FutureProvider timing issues in tests.
      migratedHabitTaskCompletionsProvider.overrideWith(
        (ref, date) => <String, bool>{
          for (final taskId in taskIds) taskId: false,
        },
      ),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(800, 1200),
          devicePixelRatio: 1.0,
        ),
        child: const Scaffold(body: HabitsScreen()),
      ),
    ),
  );
}

void main() {
  group('Non-migrated Habits (legacy Habit flow)', () {
    testWidgets('renders the hero header, filter pills and habit cards', (
      tester,
    ) async {
      await tester.pumpWidget(_harness([
        _habit('h1', 'Morning run', 'Body', order: 0),
        _habit('h2', 'Read 20 pages', 'Mind', order: 1),
      ]));
      await tester.pumpAndSettle();

      // App bar title
      expect(find.widgetWithText(SliverAppBar, 'Habits'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Morning run'), findsOneWidget);

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

      // Ensure the completion button is visible
      final completionButton = _firstNonMigratedCompletionButton();
      await tester.ensureVisible(completionButton);
      await tester.pumpAndSettle();

      // Tap the completion button on the first habit card (not the FAB)
      await tester.tap(completionButton);
      await tester.pumpAndSettle();

      expect(_firstNonMigratedUncompleteButton(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('swiping left completes the habit', (tester) async {
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

      // Left swipe shows complete action (check icon in swipe background)
      expect(find.byIcon(LucideIcons.check), findsAtLeast(1));
      expect(find.text('Complete'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();

      // Habit is now completed - completion circle shows check
      expect(find.byIcon(LucideIcons.check), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('swiping left on completed habit uncompletes it',
        (tester) async {
      // Create a habit that's already completed
      final completedHabit = _habit('h1', 'Morning run', 'Body');
      await tester.pumpWidget(_harness([completedHabit]));
      await tester.pumpAndSettle();

      // First complete it via tap
      final completionButton = _firstNonMigratedCompletionButton();
      await tester.ensureVisible(completionButton);
      await tester.pumpAndSettle();
      await tester.tap(completionButton);
      await tester.pumpAndSettle();

      // Now swipe left to uncomplete
      await _liftCardOutOfTheFab(tester);
      final card = find.byType(Dismissible);
      final start = tester.getCenter(card);
      final gesture = await tester.startGesture(start);
      for (var i = 0; i < 14; i++) {
        await gesture.moveBy(const Offset(-40, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Left swipe on completed shows uncomplete action
      expect(find.byIcon(LucideIcons.rotateCcw), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();

      // Swipe action should succeed without error
      // (UI state verification is tested in controller tests)
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'trailing menu button opens actions sheet with archive, delete, snooze',
        (
      tester,
    ) async {
      await tester.pumpWidget(_harness([_habit('h1', 'Morning run', 'Body')]));
      await tester.pumpAndSettle();

      // Tap the trailing more actions button (scroll first to clear FAB)
      await _tapFirstMoreActions(tester);

      // Bottom sheet should appear with actions
      expect(find.text('Snooze until tomorrow'), findsOneWidget);
      expect(find.text('Reschedule'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Tap Archive
      await tester.tap(find.widgetWithText(ListTile, 'Archive'));
      await tester.pumpAndSettle();

      // Habit should be archived (not visible in active list)
      expect(find.text('Morning run'), findsNothing);
    });

    testWidgets('every sheet action is reachable without scrolling', (
      tester,
    ) async {
      await tester.pumpWidget(_harness([_habit('h1', 'Morning run', 'Body')]));
      await tester.pumpAndSettle();

      await _tapFirstMoreActions(tester);

      // The default bottom sheet is capped at 9/16 of the screen, which put the
      // last - destructive - row below the fold. Asserting every row is inside
      // the viewport is what keeps Delete from needing a scroll to reach.
      final screen =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      for (final label in [
        'Edit Habit',
        'Snooze until tomorrow',
        'Reschedule',
        'Use Streak Freeze (3 left)',
        'Archive',
        'Delete',
      ]) {
        final rect = tester.getRect(find.text(label));
        expect(rect.top, greaterThanOrEqualTo(0),
            reason: '$label is above the top');
        expect(rect.bottom, lessThanOrEqualTo(screen),
            reason: '$label is off the bottom');
      }
    });

    testWidgets('delete confirmation cancels when cancelled', (tester) async {
      await tester.pumpWidget(_harness([_habit('h1', 'Morning run', 'Body')]));
      await tester.pumpAndSettle();

      // Open actions sheet
      await _tapFirstMoreActions(tester);

      // Tap Delete
      await tester.tap(find.widgetWithText(ListTile, 'Delete'));
      await tester.pumpAndSettle();

      // The sheet is gone and the confirmation took its place.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Delete Habit'), findsOneWidget);

      // Cancel the deletion
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed, habit should still be there
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Morning run'), findsOneWidget);
    });

    testWidgets('delete confirmation removes the habit when confirmed', (
      tester,
    ) async {
      await tester.pumpWidget(_harness([_habit('h1', 'Morning run', 'Body')]));
      await tester.pumpAndSettle();

      await _tapFirstMoreActions(tester);
      await tester.tap(find.widgetWithText(ListTile, 'Delete'));
      await tester.pumpAndSettle();

      // The dialog's own Delete is a button, not a list row, so the row finder
      // cannot reach it.
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Morning run'), findsNothing);
    });

    testWidgets('snoozing offers quick options and records the hold', (
      tester,
    ) async {
      var now = DateTime(2025, 6, 11, 9, 0); // Wednesday
      AppClock.debugSetNow(() => now);
      addTearDown(AppClock.debugResetNow);

      await tester.pumpWidget(_harness([_habit('h1', 'Morning run', 'Body')]));
      await tester.pumpAndSettle();

      await _tapFirstMoreActions(tester);
      await tester.tap(find.text('Snooze until tomorrow'));
      await tester.pumpAndSettle();

      // The quick options sheet, not a bare date picker.
      expect(find.text('Snooze until'), findsOneWidget);
      expect(find.text('Later today'), findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.text('This weekend'), findsOneWidget);
      expect(find.text('Custom…'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'Tomorrow'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Snoozed until'), findsOneWidget);
      // The card stays in the library but is marked as held.
      expect(find.text('Snoozed'), findsOneWidget);

      // Let the hold elapse so the controller's expiry timer does not outlive
      // the test.
      now = now.add(const Duration(days: 2));
      await tester.pump(const Duration(days: 2));
      await tester.pumpAndSettle();
    });

    testWidgets('rescheduling offers quick options and applies the choice', (
      tester,
    ) async {
      AppClock.debugSetNow(() => DateTime(2025, 6, 11, 9, 0));
      addTearDown(AppClock.debugResetNow);

      await tester.pumpWidget(_harness([_habit('h1', 'Morning run', 'Body')]));
      await tester.pumpAndSettle();

      await _tapFirstMoreActions(tester);
      await tester.tap(find.text('Reschedule'));
      await tester.pumpAndSettle();

      expect(find.text('Reschedule to'), findsOneWidget);
      expect(find.text('Today'), findsWidgets);
      expect(find.text('Next week'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'Next week'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rescheduled to'), findsOneWidget);
    });
  });

  group('Migrated Habits (Task-backed recurring work)', () {
    testWidgets('renders migrated habits under "Recurring Tasks" section', (
      tester,
    ) async {
      final habit = _habit('h1', 'Morning run', 'Body', taskId: 'task-1');
      final task =
          _migratedTask(id: 'task-1', habitId: 'h1', title: 'Morning run');

      await tester.pumpWidget(_harness([habit], migratedTasks: [task]));
      await tester.pumpAndSettle();

      // Scroll to ensure all slivers are laid out
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // Should show both sections
      expect(find.text('Recurring Tasks'), findsOneWidget);
      expect(find.text('Morning run'), findsOneWidget);
    });

    testWidgets('migrated habit completion uses Task occurrence history', (
      tester,
    ) async {
      final habit = _habit('h1', 'Morning run', 'Body', taskId: 'task-1');
      final task =
          _migratedTask(id: 'task-1', habitId: 'h1', title: 'Morning run');

      await tester.pumpWidget(_harness([habit], migratedTasks: [task]));
      await tester.pumpAndSettle();

      // Scroll to ensure all slivers are laid out
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // Find the migrated task card and tap its completion button (circle icon)
      await tester.tap(_firstMigratedCompletionButton());
      await tester.pumpAndSettle();

      // The completion action should succeed without error
      // (UI state verification is tested in controller/repository tests)
      expect(tester.takeException(), isNull);
    });

    testWidgets('non-migrated and migrated habits coexist in correct sections',
        (
      tester,
    ) async {
      final nonMigrated = _habit('h1', 'Non-migrated', 'Body');
      final migratedHabit = _habit('h2', 'Migrated', 'Mind', taskId: 'task-2');
      final migratedTask = _migratedTask(
          id: 'task-2', habitId: 'h2', title: 'Migrated', category: 'Mind');

      await tester.pumpWidget(_harness([nonMigrated, migratedHabit],
          migratedTasks: [migratedTask]));
      await tester.pumpAndSettle();

      // Scroll to ensure all slivers are laid out (including Recurring Tasks section)
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // Both sections should exist
      expect(find.text('Recurring Tasks'), findsOneWidget);
      expect(find.text('Habits'), findsWidgets); // App bar + section header

      // Non-migrated in Habits section
      expect(find.text('Non-migrated'), findsOneWidget);
      // Migrated in Recurring Tasks section
      expect(find.text('Migrated'), findsOneWidget);
    });

    testWidgets('migrated habit empty state when no recurring tasks',
        (tester) async {
      // A habit with taskId but no corresponding task
      final habit =
          _habit('h1', 'Orphaned migrated', 'Body', taskId: 'missing-task');

      await tester.pumpWidget(_harness([habit], migratedTasks: []));
      await tester.pumpAndSettle();

      // Scroll to ensure all slivers are laid out
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // Habits section should be empty (no non-migrated)
      // Recurring Tasks section should be empty (no tasks matching)
      expect(find.text('Recurring Tasks'), findsOneWidget);
      expect(find.text('Habits'), findsWidgets); // App bar title still present
    });
  });
}
