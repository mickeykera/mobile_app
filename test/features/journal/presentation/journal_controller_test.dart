import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/core/constants/app_constants.dart';
import 'package:ascend/core/errors/failures.dart';
import 'package:ascend/features/journal/domain/entities/journal_entry.dart';
import 'package:ascend/features/journal/domain/repositories/journal_repository.dart';
import 'package:ascend/features/journal/presentation/controllers/journal_controller.dart';

class FakeJournalRepository implements JournalRepository {
  FakeJournalRepository({List<JournalEntry>? entries})
      : entries = List.of(entries ?? const <JournalEntry>[]);

  final List<JournalEntry> entries;

  /// Set to simulate a persistence failure on the next write.
  Failure? nextWriteFailure;

  Failure? _consumeFailure() {
    final failure = nextWriteFailure;
    nextWriteFailure = null;
    return failure;
  }

  @override
  Future<Result<JournalEntry?>> getEntryForDate(
      DateTime date, String type) async {
    for (final entry in entries) {
      if (entry.type == type && _sameDay(entry.date, date)) {
        return Either.right(entry);
      }
    }
    return Either.right(null);
  }

  @override
  Future<Result<List<JournalEntry>>> getEntries({
    DateTime? startDate,
    DateTime? endDate,
    String? type,
    List<String>? tags,
    int? limit,
  }) async =>
      Either.right(entries);

  @override
  Future<Result<JournalEntry>> createEntry(JournalEntry entry) async {
    final failure = _consumeFailure();
    if (failure != null) return Either.left(failure);
    entries.insert(0, entry);
    return Either.right(entry);
  }

  @override
  Future<Result<JournalEntry>> updateEntry(JournalEntry entry) async {
    final failure = _consumeFailure();
    if (failure != null) return Either.left(failure);
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) entries[index] = entry;
    return Either.right(entry);
  }

  @override
  Future<Result<void>> deleteEntry(String id) async {
    entries.removeWhere((e) => e.id == id);
    return Either.right(null);
  }

  @override
  Future<Result<Map<DateTime, int>>> getEntryHeatmap({int weeks = 12}) async =>
      Either.right(const {});

  @override
  Future<Result<Map<String, int>>> getMoodDistribution({
    DateTime? startDate,
    DateTime? endDate,
  }) async =>
      Either.right(const {});

  @override
  Future<Result<Map<String, int>>> getEnergyDistribution({
    DateTime? startDate,
    DateTime? endDate,
  }) async =>
      Either.right(const {});

  @override
  Future<Result<List<String>>> getAllTags() async => Either.right(const []);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

void main() {
  ProviderContainer makeContainer(FakeJournalRepository repository) {
    final container = ProviderContainer(
      overrides: [
        journalControllerProvider
            .overrideWith((ref) => JournalController(repository)),
      ],
    );
    addTearDown(container.dispose);
    // Create the controller eagerly: providers are lazy, so without this the
    // initial load would only start on the first read - after the
    // `pumpEventQueue()` the test already awaited.
    container.read(journalControllerProvider);
    return container;
  }

  group('JournalController load', () {
    test("loads today's entries and stops loading", () async {
      final morning = JournalEntry.createMorning(
        date: DateTime.now(),
        responses: {AppConstants.morningPrompts.first: 'Write the report'},
      );
      final container =
          makeContainer(FakeJournalRepository(entries: [morning]));
      await pumpEventQueue();

      final state = container.read(journalControllerProvider);
      expect(state.morningEntry?.id, morning.id);
      expect(state.isLoading, isFalse);
      expect(state.recentEntries, hasLength(1));
    });
  });

  group('JournalController.saveEntry', () {
    test('saving does not flash the loading spinner', () async {
      final container = makeContainer(FakeJournalRepository());
      await pumpEventQueue();

      final result = await container
          .read(journalControllerProvider.notifier)
          .saveEntry(responses: {
        AppConstants.morningPrompts.first: 'Ship the feature',
      });

      expect(result.isRight, isTrue);
      final state = container.read(journalControllerProvider);
      expect(state.morningEntry, isNotNull);
      expect(state.isSaving, isFalse);
      // Regression: the old implementation reloaded everything after a save,
      // flipping `isLoading` and blanking the screen over the user's text.
      expect(state.isLoading, isFalse);
      expect(state.recentEntries, hasLength(1));
    });

    test('a failed save reports the failure instead of throwing', () async {
      final repository = FakeJournalRepository();
      final container = makeContainer(repository);
      await pumpEventQueue();

      repository.nextWriteFailure = const CacheFailure('disk full');
      final result = await container
          .read(journalControllerProvider.notifier)
          .saveEntry(responses: {
        AppConstants.morningPrompts.first: 'Not persisted',
      });

      // Regression: `fold` cast the failure to `JournalEntry`, which threw a
      // TypeError before the failure could ever reach the UI.
      expect(result.isLeft, isTrue);
      expect(result.left, isA<CacheFailure>());

      final state = container.read(journalControllerProvider);
      expect(state.error, isNotNull);
      expect(state.isSaving, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.morningEntry, isNull);
      expect(state.recentEntries, isEmpty);
    });

    test('a second save updates in place without duplicating', () async {
      final container = makeContainer(FakeJournalRepository());
      await pumpEventQueue();
      final controller = container.read(journalControllerProvider.notifier);

      await controller
          .saveEntry(responses: {AppConstants.morningPrompts.first: 'first'});
      final firstId =
          container.read(journalControllerProvider).morningEntry!.id;

      final result = await controller
          .saveEntry(responses: {AppConstants.morningPrompts.first: 'second'});

      expect(result.isRight, isTrue);
      final state = container.read(journalControllerProvider);
      expect(state.morningEntry?.id, firstId);
      expect(state.morningEntry?.responses[AppConstants.morningPrompts.first],
          'second');
      expect(state.recentEntries, hasLength(1));
      expect(state.isLoading, isFalse);
    });
  });

  group('JournalController.deleteCurrentEntry', () {
    test('clears the entry without a spinner', () async {
      final container = makeContainer(FakeJournalRepository());
      await pumpEventQueue();
      final controller = container.read(journalControllerProvider.notifier);

      await controller
          .saveEntry(responses: {AppConstants.morningPrompts.first: 'x'});
      expect(controller.state.morningEntry, isNotNull);

      final result = await controller.deleteCurrentEntry();

      expect(result.isRight, isTrue);
      final state = container.read(journalControllerProvider);
      expect(state.morningEntry, isNull);
      expect(state.recentEntries, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('deleting with nothing to delete returns a failure', () async {
      final container = makeContainer(FakeJournalRepository());
      await pumpEventQueue();

      final result = await container
          .read(journalControllerProvider.notifier)
          .deleteCurrentEntry();

      expect(result.isLeft, isTrue);
      expect(result.left, isA<NotFoundFailure>());
    });
  });

  group('JournalController prompts', () {
    test('come from AppConstants so the sheet can not drift', () {
      final container = makeContainer(FakeJournalRepository());
      final controller = container.read(journalControllerProvider.notifier);

      expect(
          controller.getPromptsForType('Morning'), AppConstants.morningPrompts);
      expect(
          controller.getPromptsForType('Evening'), AppConstants.eveningPrompts);
      expect(controller.getPromptsForType('Morning'),
          hasLength(AppConstants.maxReflectionPrompts));
    });
  });
}
