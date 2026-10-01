import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/core/constants/app_constants.dart';
import 'package:ascend/features/journal/domain/entities/journal_entry.dart';
import 'package:ascend/features/journal/presentation/controllers/journal_controller.dart';
import 'package:ascend/features/journal/presentation/screens/journal_screen.dart';

import 'journal_controller_test.dart' show FakeJournalRepository;

/// An entry for *today*, so the controller's `_loadInitialData` finds it and the
/// screen renders the prompt cards instead of the empty state.
///
/// `responses` is non-empty on purpose: `hasContent` is false for a bare entry,
/// and the screen then shows the empty view with no editable cards at all.
JournalEntry _todayMorning({Map<String, String>? responses}) {
  return JournalEntry.createMorning(
    date: DateTime.now(),
    responses: responses ?? {AppConstants.morningPrompts.first: 'Ship the redesign'},
  );
}

JournalEntry _todayEvening() {
  return JournalEntry.createEvening(
    date: DateTime.now(),
    responses: const {
      'What went well today?': 'Shipped the redesign',
    },
  );
}

/// Pumps the screen in a container we control, so the controller's initial load
/// settles inside the test frame instead of racing the first `pumpAndSettle`.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  FakeJournalRepository? repository,
}) async {
  final repo = repository ?? FakeJournalRepository();
  final container = ProviderContainer(
    overrides: [
      journalControllerProvider.overrideWith((ref) => JournalController(repo)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: JournalScreen())),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('renders the header and the morning/evening toggle', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Reflection'), findsOneWidget);
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Evening'), findsOneWidget);
    expect(find.text('New Entry'), findsOneWidget);
    // Nothing written yet, so the hero says so rather than showing a bare gap.
    expect(find.text('No check-in yet today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an entry with content renders a card per prompt plus ratings', (
    tester,
  ) async {
    await _pump(
      tester,
      repository: FakeJournalRepository(entries: [_todayMorning()]),
    );

    expect(find.text('How are you feeling?'), findsOneWidget);
    expect(find.text('Gratitude'), findsOneWidget);
    expect(find.text(AppConstants.morningPrompts.first), findsOneWidget);
    // The stored answer survives the rebuild triggered by loading the entry.
    expect(find.text('Ship the redesign'), findsOneWidget);
    // Mood and energy scales.
    expect(find.text('Mood'), findsOneWidget);
    expect(find.text('Energy'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching to Evening swaps the prompts and persists the type', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      repository: FakeJournalRepository(
        entries: [_todayMorning(), _todayEvening()],
      ),
    );

    await tester.tap(find.text('Evening'));
    await tester.pumpAndSettle();

    // The body cross-fades to the other half of the day: its prompts, and its
    // answers, replace the morning ones.
    expect(find.text(AppConstants.eveningPrompts.first), findsOneWidget);
    expect(find.text(AppConstants.morningPrompts.first), findsNothing);
    expect(find.text('Shipped the redesign'), findsOneWidget);
    expect(find.text('Ship the redesign'), findsNothing);
    expect(
      container.read(journalControllerProvider).selectedType,
      AppConstants.reflectionEvening,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a mood step saves the rating and lights the hero pill', (
    tester,
  ) async {
    final repo = FakeJournalRepository(entries: [_todayMorning()]);
    await _pump(tester, repository: repo);

    await tester.tap(find.bySemanticsLabel('4 out of 5').first);
    await tester.pumpAndSettle();

    expect(repo.entries, hasLength(1));
    expect(repo.entries.first.moodRating, 4);
    // The hero now carries a rating pill, so the "nothing yet" line is gone.
    expect(find.text('Mood 4/5'), findsOneWidget);
    expect(find.text('No check-in yet today'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing in a prompt field does not disturb the caret', (
    tester,
  ) async {
    await _pump(
      tester,
      repository: FakeJournalRepository(entries: [_todayMorning()]),
    );

    // The bug this guards: the field built a fresh TextEditingController on
    // every keystroke, because each one saves and rebuilds the screen.
    final field = find.widgetWithText(TextField, 'Ship the redesign');
    expect(field, findsOneWidget);
    final controller = tester.widget<TextField>(field).controller;

    await tester.enterText(field, 'Ship the redesign, then review');
    await tester.pumpAndSettle();

    expect(
      controller,
      same(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Ship the redesign, then review'),
            )
            .controller,
      ),
      reason: 'the same controller must survive the save-triggered rebuild',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the entry sheet opens, saves and closes', (tester) async {
    final repo = FakeJournalRepository();
    await _pump(tester, repository: repo);

    await tester.tap(find.text('New Entry'));
    await tester.pumpAndSettle();

    // 'Morning Intention' is the empty view's title *and* the sheet's header,
    // so the sheet-specific marker is the save button.
    expect(find.text('Morning Intention'), findsWidgets);
    expect(find.text('Save Entry'), findsOneWidget);
    expect(find.text(AppConstants.morningPrompts.first), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Your reflection…').first,
      'Three priorities',
    );
    await tester.pumpAndSettle();

    // The sheet is taller than the viewport; scroll the save button into view
    // before tapping, or the tap lands on whatever is actually at those pixels.
    await tester.ensureVisible(find.text('Save Entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Entry'));
    await tester.pumpAndSettle();

    // Closed, and the entry it wrote is now the screen's content.
    expect(find.text('Save Entry'), findsNothing);
    expect(find.text('Three priorities'), findsOneWidget);
    expect(repo.entries, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
