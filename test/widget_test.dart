import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/app/app.dart';

void main() {
  testWidgets('Ascend app shows its loading screen while the database opens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: AscendApp()));

    // The launch screen pulses forever by design, so there is no settled frame
    // to wait for. Assert on the first frame instead of using `pumpAndSettle`.
    expect(find.text('Ascend'), findsOneWidget);
    expect(find.text('Initializing your data…'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);

    // Unmount before the test ends: a repeating animation holds a running
    // ticker, and `flutter_test` fails on anything still pending when the test
    // body returns. The extra pump lets the zero-delay `Future.delayed` that
    // `flutter_animate` schedules on mount actually fire and clear.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });
}
