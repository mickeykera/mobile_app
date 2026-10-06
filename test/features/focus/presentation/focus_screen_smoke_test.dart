import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/features/focus/presentation/controllers/focus_controller.dart';
import 'package:ascend/features/focus/presentation/screens/focus_screen.dart';

import 'focus_controller_test.dart' show FakeFocusRepository;

/// Pumps the screen in a container we control, so the controller's
/// `_loadInitialData` completes inside the test frame instead of racing the
/// first `pumpAndSettle`.
Future<ProviderContainer> _pump(WidgetTester tester) async {
  final repo = FakeFocusRepository();
  final container = ProviderContainer(
    overrides: [
      focusControllerProvider.overrideWith((ref) => FocusController(repo)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: FocusScreen())),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('renders the setup view with mode pills and durations', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Ready to Focus?'), findsOneWidget);
    expect(find.text('Pomodoro'), findsOneWidget);
    expect(find.text('Start Session'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Break'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching mode to Stopwatch hides the duration fields', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Stopwatch'));
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsNothing);
    expect(find.text('Start Session'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('starting a session shows the gradient timer ring', (
    tester,
  ) async {
    await _pump(tester);

    // The setup column is taller than a 600px test surface, so the primary
    // action starts below the fold.
    await tester.ensureVisible(find.text('Start Session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Session'));
    // Not pumpAndSettle: the breathing ring is an infinite animation by design,
    // so there is never a settled frame to reach.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Phase pill plus the breathing ring's arc.
    expect(find.text('FOCUS'), findsOneWidget);
    expect(find.text('Stay focused'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the breathing ring scales and halts when paused',
      (tester) async {
    await _pump(tester);

    await tester.ensureVisible(find.text('Start Session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Sample the ring's outer scale at two points a breath apart.
    double sampleRing() => tester
        .widget<Transform>(find.byKey(const ValueKey('focus-breath')))
        .transform
        .getMaxScaleOnAxis();

    final first = sampleRing();
    await tester.pump(const Duration(milliseconds: 2000));
    final second = sampleRing();
    expect(first, isNot(second));

    await tester.tap(find.text('Pause'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final paused = sampleRing();
    await tester.pump(const Duration(milliseconds: 2000));
    expect(
      sampleRing(),
      paused,
      reason: 'the breath must stop while paused',
    );
  });

  testWidgets('pause and resume swap the primary control', (tester) async {
    await _pump(tester);

    await tester.ensureVisible(find.text('Start Session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Pause'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Start Break'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the session settings sheet opens on glass', (tester) async {
    await _pump(tester);

    await tester.tap(find.byTooltip('Session Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Session Settings'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
