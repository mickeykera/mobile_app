import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/habits/presentation/widgets/habit_form.dart';

/// The form builds a `Habit` and pops it, so it needs no repository of its own.
/// It is pumped inside a `Scaffold` because the real sheet is a modal bottom
/// sheet and the form relies on `MediaQuery.viewInsets` for keyboard clearance.
/// Pumps the form with the semantics tree enabled.
///
/// The handle must be disposed before the test body returns, not in a teardown:
/// `tester` verifies at the end of the body that no `SemanticsHandle` is still
/// active, and teardowns run after that check.
Future<void> _pumpForm(
  WidgetTester tester,
  SemanticsHandle handle, {
  Habit? habit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: HabitForm(habit: habit)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the create form with glass chips and a CTA', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpForm(tester, semantics);

    expect(find.text('Habit Title'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Frequency'), findsOneWidget);
    expect(find.text('Time of Day'), findsOneWidget);
    expect(find.text('Create Habit'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('title and description counters are declared, not just validated',
      (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpForm(tester, semantics);

    // `TextFormField` does not expose `maxLength`; the underlying `TextField`
    // it builds does, so that is what has to be inspected.
    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();

    final title = fields.firstWhere(
      (f) => f.decoration?.labelText == 'Habit Title',
    );
    // The title had a 100-character validator but never declared `maxLength`,
    // so nothing enforced it and nothing told the user about it.
    expect(title.maxLength, 100);

    final description = fields.firstWhere(
      (f) => f.decoration?.labelText?.contains('Description') ?? false,
    );
    expect(description.maxLength, 500);
    semantics.dispose();
  });

  testWidgets('a category chip reports as selected to assistive tech', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpForm(tester, semantics);

    // 'Mind' is the default category. It must be discoverable as the current
    // choice, not just painted differently.
    expect(find.bySemanticsLabel('Mind'), findsOneWidget);

    final pill = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.text('Mind'),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(pill.properties.selected, isTrue);

    await tester.tap(find.text('Body'));
    await tester.pumpAndSettle();

    expect(find.text('Mind'), findsOneWidget);
    final body = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.text('Body'),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(body.properties.selected, isTrue);
    semantics.dispose();
  });

  testWidgets('custom frequency reveals the weekday picker', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpForm(tester, semantics);

    expect(find.text('Select Days'), findsNothing);

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    expect(find.text('Select Days'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('switching away from Custom clears the chosen weekdays', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpForm(tester, semantics);

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wed'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Daily'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    // 'Wed' must not still be lit from the previous visit.
    final pill = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.text('Wed'),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(pill.properties.selected, isFalse);
    semantics.dispose();
  });

  testWidgets('saving without a title surfaces the validation error', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpForm(tester, semantics);

    // The CTA sits below the fold on a default test viewport, so scroll it into
    // view or the tap lands on whatever is actually at those pixels.
    await tester.ensureVisible(find.text('Create Habit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Habit'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a habit title'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('an existing habit is prefilled for editing', (tester) async {
    final habit = Habit.create(
      title: 'Morning meditation',
      category: 'Mind',
      description: 'Ten quiet minutes',
      frequency: 'Custom',
      customWeekdays: const [1, 3, 5],
      timeOfDay: 'Morning',
      targetCount: 1,
      targetDuration: const Duration(minutes: 10),
      cue: 'After brushing teeth',
      sortOrder: 0,
    );

    final semantics = tester.ensureSemantics();
    await _pumpForm(tester, semantics, habit: habit);

    expect(find.text('Edit Habit'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Morning meditation'), findsOneWidget);
    expect(find.text('Ten quiet minutes'), findsOneWidget);
    expect(find.text('After brushing teeth'), findsOneWidget);
    // Custom frequency with three days is already selected.
    expect(find.text('Select Days'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
