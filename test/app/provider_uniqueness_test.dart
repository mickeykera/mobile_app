import 'dart:io';

import 'package:ascend/core/database/database.dart';
import 'package:ascend/features/analytics/data/repositories/analytics_repository_impl.dart';
import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/habits/presentation/providers/habit_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every instant in this file is pinned, because the repositories write
/// timestamps into storage and a wall-clock read would make the golden-free
/// assertions depend on the day the suite happens to run.
final _pinnedNow = DateTime(2025, 6, 11, 9, 30);

/// Guards an invariant that no compiler and no analyzer will catch for you:
/// a Riverpod provider name must resolve to exactly one declaration.
///
/// Both bugs this file exists to prevent were invisible to the whole suite.
/// `taskRepositoryProvider` was declared in `task_repository_impl.dart` as well
/// as in `task_providers.dart`; the data-layer copy was referenced by nothing,
/// but it was still *importable*, so a test that wrote
/// `taskRepositoryProvider.overrideWithValue(...)` after importing the data-layer
/// file would override the wrong provider, the real `TaskRepositoryImpl` would
/// be wired into `TaskController`, and the test would quietly assert against an
/// empty list. It fails silently and it fails *green*.
///
/// `habitRepositoryProvider` was worse: both declarations were live.
/// `HabitController` and `AnalyticsRepositoryImpl` each held a different
/// `HabitRepositoryImpl`, so each kept its own in-memory cache over the same
/// `SharedPreferences` and the two drifted apart on the first write. Nothing in
/// the suite overrode that provider, so the bug was reachable only in production.

/// A top-level provider declaration.
///
/// Anchored to column 0 on purpose: these are module-level `final`s, and an
/// indented match would sweep up local variables that happen to share the name.
/// The initialiser is allowed to span lines, so no trailing anchor is required.
final _declaration = RegExp(
  r'^final\s+([A-Za-z_][A-Za-z0-9_]*[Pp]rovider)\b',
  multiLine: true,
);

/// Where each provider name is declared, as `path:line`.
Map<String, List<String>> _declarationsByName() {
  final byName = <String, List<String>>{};

  for (final file
      in Directory('lib').listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;

    final source = file.readAsStringSync();
    for (final match in _declaration.allMatches(source)) {
      final line = source.substring(0, match.start).split('\n').length;
      byName
          .putIfAbsent(match.group(1)!, () => <String>[])
          .add('${file.path}:$line');
    }
  }

  return byName;
}

void main() {
  final byName = _declarationsByName();

  late DatabaseService database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = DatabaseService();
    await database.initialize();
  });

  tearDown(() => database.close());

  test('lib/ actually contains providers to check', () {
    // A scanner that silently matches nothing would make every other test in
    // this file pass for the wrong reason.
    expect(byName.length, greaterThan(20),
        reason: 'the provider scan found almost nothing; the regex is broken');
    expect(byName, contains('taskRepositoryProvider'));
    expect(byName, contains('habitRepositoryProvider'));
  });

  test('every provider name in lib/ is declared exactly once', () {
    final duplicates = {
      for (final entry in byName.entries)
        if (entry.value.length > 1) entry.key: entry.value,
    };

    expect(
      duplicates,
      isEmpty,
      reason: 'A provider declared twice is two providers sharing a name. Any '
          'consumer that imports the other copy silently gets a separate '
          'instance, so overrides miss and caches drift. Keep one declaration, '
          'in the layer that owns it.',
    );
  });

  test('each repository provider has exactly one declaration', () {
    // Spelled out by name rather than derived, because these are the ones with
    // persisted data behind them: a second instance is not a duplicate symbol,
    // it is a second cache that can disagree with the first.
    const repositoryProviders = [
      'taskRepositoryProvider',
      'habitRepositoryProvider',
      'projectRepositoryProvider',
      'goalRepositoryProvider',
      'focusRepositoryProvider',
      'journalRepositoryProvider',
      'analyticsRepositoryProvider',
    ];

    for (final name in repositoryProviders) {
      expect(byName[name], hasLength(1),
          reason: '$name must be declared exactly once, found ${byName[name]}');
    }
  });

  test('a write through the habit provider is visible to Analytics', () async {
    // The behavioural half of the guard, and the one that actually pins the bug.
    //
    // Every repository in this app memoises its load in a `Future` memo, so a
    // second instance of `HabitRepositoryImpl` over the same storage reads the
    // habits once and never looks again. When `HabitController` and
    // `AnalyticsRepositoryImpl` held separate instances, a habit created in the
    // app was written to one cache while Analytics kept reporting the list it
    // had read at start-up - and no test noticed, because nothing overrode that
    // provider to make the split observable.
    //
    // So: read through Analytics *first*, to let its cache settle, then write
    // through the provider the controller uses, then read Analytics again. Under
    // the old split the second read cannot see the new habit.
    final container = ProviderContainer(
      overrides: [databaseServiceProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    final analytics = container.read(analyticsRepositoryProvider);
    final habits = container.read(habitRepositoryProvider);
    final range = (
      start: DateTime(2025, 6, 1),
      end: DateTime(2025, 6, 30),
    );

    // First read, before the write: this is what pins Analytics' cache.
    final before = await analytics.getAnalyticsData(
      startDate: range.start,
      endDate: range.end,
    );
    expect(before.isRight, isTrue, reason: '${before.left}');
    expect(
        before.right!.categoryCompletions.containsKey('Verification'), isFalse);

    final created = await habits.createHabit(
      Habit(
        id: 'h-shared',
        title: 'Proof of sharing',
        description: '',
        category: 'Verification',
        frequency: 'Daily',
        customWeekdays: const <int>[],
        timeOfDay: 'Morning',
        targetCount: 1,
        targetDuration: const Duration(minutes: 20),
        cue: '',
        createdAt: _pinnedNow,
        updatedAt: _pinnedNow,
        sortOrder: 0,
        isArchived: false,
        streakFreezesUsed: 0,
        currentStreak: 0,
        longestStreak: 0,
        // Counted straight off the entity by `habitCompletionsByCategory`, so
        // this needs no completion row to become visible in the read model.
        totalCompletions: 7,
      ),
    );
    expect(created.isRight, isTrue, reason: '${created.left}');

    final after = await container
        .read(analyticsRepositoryProvider)
        .getAnalyticsData(startDate: range.start, endDate: range.end);

    expect(after.isRight, isTrue, reason: '${after.left}');
    expect(
      after.right!.categoryCompletions['Verification'],
      7,
      reason: 'Analytics did not observe a habit written through '
          'habitRepositoryProvider, so it is holding a second cache',
    );
  });
}
