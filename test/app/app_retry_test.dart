import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/app/app.dart';
import 'package:ascend/core/database/database.dart';

/// A database whose `initialize` fails a set number of times, then succeeds.
class _FlakyDatabase implements DatabaseService {
  int failuresRemaining;

  int attempts = 0;

  _FlakyDatabase(this.failuresRemaining);

  @override
  Future<void> initialize() async {
    attempts++;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('storage unavailable');
    }
  }

  /// Nothing else is reached: the test asserts on the transition between the
  /// error screen and the loading screen, which happens before the router gets
  /// a chance to ask for real data.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('Retry starts a new database attempt instead of rebuilding',
      (tester) async {
    final database = _FlakyDatabase(1);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseServiceProvider.overrideWithValue(database)],
        child: const AscendApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text("Couldn't open your data"), findsOneWidget);
    expect(find.textContaining('storage unavailable'), findsOneWidget);
    expect(database.attempts, 1);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    // The point of the test: `attempts` went up. A `setState` inside the error
    // screen rebuilds only that screen, leaving the `FutureBuilder` holding the
    // future it already failed on, so the retry silently did nothing and the
    // error text was still on screen.
    expect(database.attempts, 2);
    expect(find.text("Couldn't open your data"), findsNothing);
    expect(find.textContaining('storage unavailable'), findsNothing);
  });

  testWidgets('Retry keeps trying while the database stays broken',
      (tester) async {
    final database = _FlakyDatabase(3);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseServiceProvider.overrideWithValue(database)],
        child: const AscendApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(database.attempts, 1);

    // Each tap must be a fresh attempt, not a cached failure.
    for (var expected = 2; expected <= 3; expected++) {
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(database.attempts, expected);
      expect(find.text("Couldn't open your data"), findsOneWidget);
    }
  });
}
