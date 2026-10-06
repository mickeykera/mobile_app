import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/app_clock.dart';
import '../../domain/entities/focus_session.dart';
import '../../data/repositories/focus_repository_impl.dart';
import '../../domain/repositories/focus_repository.dart';
import '../../../../core/errors/failures.dart';

part 'focus_controller.freezed.dart';

@freezed
abstract class FocusState with _$FocusState {
  const factory FocusState({
    FocusSession? activeSession,
    @Default([]) List<FocusSession> recentSessions,
    @Default(false) bool isLoading,
    String? error,
    @Default('Pomodoro') String selectedMode,
    @Default(25) int workDuration,
    @Default(5) int breakDuration,
    @Default(15) int longBreakDuration,
    @Default(4) int sessionsBeforeLongBreak,
    String? selectedHabitId,
    String? projectName,

    /// Bumped on every timer tick so the state - and everything derived from
    /// it - actually changes. See [FocusController.tick].
    @Default(0) int tickCount,
  }) = _FocusState;
}

class FocusController extends StateNotifier<FocusState> {
  final FocusRepository _repository;
  DateTime? _lastTick;

  FocusController(this._repository) : super(const FocusState()) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    state = state.copyWith(isLoading: true, error: null);

    final activeResult = await _repository.getActiveSession();
    final recentResult = await _repository.getSessions(limit: 10);
    // The provider can be disposed while the load is in flight; writing state
    // afterwards throws `Bad state`.
    if (!mounted) return;

    if (activeResult.isLeft) {
      state = state.copyWith(
          isLoading: false, error: activeResult.left!.userMessage);
    } else {
      // `right` is null when no session is running - that is the normal case
      // on a cold start, so it must not be force-unwrapped.
      final active = activeResult.right;
      if (recentResult.isLeft) {
        state = state.copyWith(
          isLoading: false,
          activeSession: active,
          error: recentResult.left!.userMessage,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          activeSession: active,
          recentSessions: recentResult.right!,
        );
      }
    }
  }

  Future<void> refresh() async {
    await _loadInitialData();
  }

  void setMode(String mode) {
    state = state.copyWith(selectedMode: mode);
  }

  void setWorkDuration(int minutes) {
    state = state.copyWith(workDuration: minutes.clamp(1, 120));
  }

  void setBreakDuration(int minutes) {
    state = state.copyWith(breakDuration: minutes.clamp(1, 60));
  }

  void setLongBreakDuration(int minutes) {
    state = state.copyWith(longBreakDuration: minutes.clamp(1, 60));
  }

  void setSessionsBeforeLongBreak(int count) {
    state = state.copyWith(sessionsBeforeLongBreak: count.clamp(1, 10));
  }

  void setSelectedHabit(String? habitId) {
    state = state.copyWith(selectedHabitId: habitId);
  }

  void setProjectName(String? name) {
    state = state.copyWith(projectName: name);
  }

  Future<Result<FocusSession>> startSession() async {
    final session = FocusSession.create(
      mode: state.selectedMode,
      workDurationMinutes: state.workDuration,
      breakDurationMinutes: state.breakDuration,
      longBreakDurationMinutes: state.longBreakDuration,
      sessionsBeforeLongBreak: state.sessionsBeforeLongBreak,
      habitId: state.selectedHabitId,
      projectName: state.projectName,
    );

    final result = await _repository.createSession(session);

    if (result.isLeft) {
      state = state.copyWith(error: result.left!.userMessage);
    } else {
      state = state.copyWith(
        activeSession: result.right!,
        recentSessions: [result.right!, ...state.recentSessions],
      );
    }

    return result;
  }

  Future<Result<void>> pauseSession() async {
    final session = state.activeSession;
    if (session == null) {
      return Either.left(const ValidationFailure('No active session'));
    }

    final paused = session.pause();
    final result = await _repository.updateSession(paused);

    if (result.isLeft) {
      state = state.copyWith(error: result.left!.userMessage);
    } else {
      state = state.copyWith(activeSession: paused);
    }

    return result;
  }

  Future<Result<void>> resumeSession() async {
    final session = state.activeSession;
    if (session == null) {
      return Either.left(const ValidationFailure('No active session'));
    }

    final resumed = session.resume();
    final result = await _repository.updateSession(resumed);

    if (result.isLeft) {
      state = state.copyWith(error: result.left!.userMessage);
    } else {
      state = state.copyWith(activeSession: resumed);
    }

    return result;
  }

  Future<Result<void>> completePhase() async {
    final session = state.activeSession;
    if (session == null) {
      return Either.left(const ValidationFailure('No active session'));
    }

    final completed = session.completeSession();
    final result = await _repository.updateSession(completed);

    if (result.isLeft) {
      state = state.copyWith(error: result.left!.userMessage);
    } else {
      state = state.copyWith(activeSession: completed);
    }

    return result;
  }

  Future<Result<FocusSession>> endSession(
      {int? focusRating, String? reflectionNotes}) async {
    final session = state.activeSession;
    if (session == null) {
      return Either.left(const ValidationFailure('No active session'));
    }

    final ended = session.endSession(
        focusRating: focusRating, reflectionNotes: reflectionNotes);
    final result = await _repository.updateSession(ended);

    if (result.isLeft) {
      state = state.copyWith(error: result.left!.userMessage);
    } else {
      state = state.copyWith(
        activeSession: null,
        recentSessions: [ended, ...state.recentSessions],
      );
    }

    return result;
  }

  Future<Result<void>> discardSession() async {
    final session = state.activeSession;
    if (session == null) {
      return Either.left(const ValidationFailure('No active session'));
    }

    final result = await _repository.deleteSession(session.id);

    if (result.isLeft) {
      state = state.copyWith(error: result.left!.userMessage);
    } else {
      state = state.copyWith(activeSession: null);
    }

    return result;
  }

  void tick() {
    final session = state.activeSession;
    if (session == null || session.isPaused || !session.isActive) return;

    final now = AppClock.now();
    if (_lastTick != null && now.difference(_lastTick!).inSeconds < 1) return;
    _lastTick = now;

    // The session exposes live getters (`elapsedWorkTime`,
    // `formattedElapsed`, `currentPhaseProgress`) computed from
    // `AppClock.now()`, so nothing inside it changes on a tick and assigning
    // the same state is a no-op: Riverpod drops the notification when the new
    // state equals the old one. `tickCount` gives every tick a distinct state
    // so the timer and the derived progress providers actually update.
    state = state.copyWith(tickCount: state.tickCount + 1);
  }

  bool get isInWorkPhase => state.activeSession?.isBreak == false;
  bool get isInBreakPhase => state.activeSession?.isBreak == true;
  double get progress => state.activeSession?.currentPhaseProgress ?? 0.0;
  String get formattedElapsed =>
      state.activeSession?.formattedElapsed ?? '0:00';
  String get formattedRemaining =>
      state.activeSession?.formattedRemaining ?? '0:00';
}

final focusControllerProvider =
    StateNotifierProvider<FocusController, FocusState>((ref) {
  final repository = ref.watch(focusRepositoryProvider);
  return FocusController(repository);
});

final activeSessionProvider = Provider<FocusSession?>((ref) {
  return ref.watch(focusControllerProvider).activeSession;
});

final focusProgressProvider = Provider<double>((ref) {
  // Read the state, not the notifier: a provider that watches `.notifier`
  // never recomputes, so the ring would sit at the value computed on first
  // build. `tickCount` is what makes this fire on every timer tick.
  final session = ref.watch(focusControllerProvider).activeSession;
  if (session == null) return 0.0;
  return session.currentPhaseProgress;
});
