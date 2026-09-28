import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/core/errors/failures.dart';
import 'package:ascend/features/focus/domain/entities/focus_session.dart';
import 'package:ascend/features/focus/domain/repositories/focus_repository.dart';
import 'package:ascend/features/focus/presentation/controllers/focus_controller.dart';

class FakeFocusRepository implements FocusRepository {
  FakeFocusRepository({FocusSession? active, List<FocusSession>? recent})
      : _active = active,
        recent = List.of(recent ?? const <FocusSession>[]);

  FocusSession? _active;
  final List<FocusSession> recent;

  @override
  Future<Result<FocusSession?>> getActiveSession() async =>
      Either.right(_active);

  @override
  Future<Result<FocusSession>> createSession(FocusSession session) async {
    _active = session;
    recent.insert(0, session);
    return Either.right(session);
  }

  @override
  Future<Result<FocusSession>> updateSession(FocusSession session) async {
    _active = session;
    final index = recent.indexWhere((s) => s.id == session.id);
    if (index >= 0) recent[index] = session;
    return Either.right(session);
  }

  @override
  Future<Result<void>> deleteSession(String id) async {
    _active = null;
    recent.removeWhere((s) => s.id == id);
    return Either.right(null);
  }

  @override
  Future<Result<List<FocusSession>>> getSessions({
    DateTime? startDate,
    DateTime? endDate,
    String? habitId,
    int? limit,
  }) async =>
      Either.right(recent);

  @override
  Future<Result<int>> getTotalFocusMinutes(
          {DateTime? startDate, DateTime? endDate}) async =>
      Either.right(0);

  @override
  Future<Result<Map<DateTime, int>>> getFocusHeatmap({int weeks = 12}) async =>
      Either.right(const {});

  @override
  Future<Result<Map<String, int>>> getFocusByCategory(
          {DateTime? startDate, DateTime? endDate}) async =>
      Either.right(const {});
}

/// A session that is running, 12.5 minutes into a 25 minute work phase.
FocusSession _halfElapsedSession() => FocusSession.create(
      mode: 'Pomodoro',
      workDurationMinutes: 25,
      breakDurationMinutes: 5,
    ).copyWith(
      accumulatedWorkTime: const Duration(minutes: 12, seconds: 30),
    );
void main() {
  group('FocusController initial load', () {
    test('restores an active session from the repository', () async {
      final active = _halfElapsedSession();
      final repository = FakeFocusRepository(active: active);
      final container = ProviderContainer(
        overrides: [
          focusControllerProvider
              .overrideWith((ref) => FocusController(repository)),
        ],
      );
      addTearDown(container.dispose);
      container.read(focusControllerProvider);
      await pumpEventQueue();

      expect(
          container.read(focusControllerProvider).activeSession?.id, active.id);
      expect(container.read(activeSessionProvider)?.id, active.id);
    });
  });

  group('FocusController.tick()', () {
    test('notifies listeners so the timer can redraw', () async {
      final repository = FakeFocusRepository(active: _halfElapsedSession());
      final container = ProviderContainer(
        overrides: [
          focusControllerProvider
              .overrideWith((ref) => FocusController(repository)),
        ],
      );
      addTearDown(container.dispose);
      container.read(focusControllerProvider);
      await pumpEventQueue();

      var notifications = 0;
      container.listen(focusControllerProvider, (_, __) => notifications++);

      container.read(focusControllerProvider.notifier).tick();

      // Regression: `tick()` used to reassign a state that compared equal to
      // the previous one, which Riverpod silently drops - the countdown never
      // moved on screen.
      expect(notifications, greaterThan(0),
          reason: 'a tick must produce a new state');
      expect(container.read(focusControllerProvider).tickCount, 1);
    });

    test('is a no-op while the session is paused', () async {
      final repository = FakeFocusRepository(active: _halfElapsedSession());
      final container = ProviderContainer(
        overrides: [
          focusControllerProvider
              .overrideWith((ref) => FocusController(repository)),
        ],
      );
      addTearDown(container.dispose);
      container.read(focusControllerProvider);
      await pumpEventQueue();

      final controller = container.read(focusControllerProvider.notifier);
      await controller.pauseSession();

      var notifications = 0;
      container.listen(focusControllerProvider, (_, __) => notifications++);

      controller.tick();

      expect(notifications, 0);
    });

    test('is a no-op without an active session', () async {
      final container = ProviderContainer(
        overrides: [
          focusControllerProvider
              .overrideWith((ref) => FocusController(FakeFocusRepository())),
        ],
      );
      addTearDown(container.dispose);
      container.read(focusControllerProvider);
      await pumpEventQueue();

      var notifications = 0;
      container.listen(focusControllerProvider, (_, __) => notifications++);

      container.read(focusControllerProvider.notifier).tick();

      expect(notifications, 0);
    });
  });
  group('focusProgressProvider', () {
    test('tracks the phase of the running session', () async {
      final repository = FakeFocusRepository(active: _halfElapsedSession());
      final container = ProviderContainer(
        overrides: [
          focusControllerProvider
              .overrideWith((ref) => FocusController(repository)),
        ],
      );
      addTearDown(container.dispose);
      container.read(focusControllerProvider);
      await pumpEventQueue();

      // Regression: this provider used to watch `...provider.notifier`, which
      // never re-notifies, so the ring stayed at its first computed value.
      expect(container.read(focusProgressProvider), closeTo(0.5, 0.05));

      await container.read(focusControllerProvider.notifier).completePhase();

      expect(container.read(focusProgressProvider), lessThan(0.01),
          reason: 'the break just started, so its progress must be ~0');
      expect(container.read(focusControllerProvider).activeSession?.isBreak,
          isTrue);
    });

    test('is 0 when there is no active session', () async {
      final container = ProviderContainer(
        overrides: [
          focusControllerProvider
              .overrideWith((ref) => FocusController(FakeFocusRepository())),
        ],
      );
      addTearDown(container.dispose);
      container.read(focusControllerProvider);
      await pumpEventQueue();

      expect(container.read(focusProgressProvider), 0.0);
    });
  });

  group('FocusController session lifecycle', () {
    test('start, end and discard update the state', () async {
      final repository = FakeFocusRepository();
      final container = ProviderContainer(
        overrides: [
          focusControllerProvider
              .overrideWith((ref) => FocusController(repository)),
        ],
      );
      addTearDown(container.dispose);
      container.read(focusControllerProvider);
      await pumpEventQueue();

      final controller = container.read(focusControllerProvider.notifier);

      final started = await controller.startSession();
      expect(started.isRight, isTrue);
      expect(controller.state.activeSession, isNotNull);

      final ended = await controller.endSession(focusRating: 5);
      expect(ended.isRight, isTrue);
      expect(controller.state.activeSession, isNull);
      expect(controller.state.recentSessions, isNotEmpty);
      expect(controller.state.recentSessions.first.focusRating, 5);

      await controller.startSession();
      final discarded = await controller.discardSession();
      expect(discarded.isRight, isTrue);
      expect(controller.state.activeSession, isNull);
    });

    test('a missing session returns a failure instead of throwing', () async {
      final repository = FakeFocusRepository();
      final container = ProviderContainer(
        overrides: [
          focusControllerProvider
              .overrideWith((ref) => FocusController(repository)),
        ],
      );
      addTearDown(container.dispose);
      container.read(focusControllerProvider);
      await pumpEventQueue();

      final controller = container.read(focusControllerProvider.notifier);
      final result = await controller.pauseSession();

      expect(result.isLeft, isTrue);
      expect(result.left, isA<ValidationFailure>());
      expect(controller.state.error, isNull);
      expect(controller.state.activeSession, isNull);
    });
  });
}
