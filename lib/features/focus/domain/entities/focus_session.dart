import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';

part 'focus_session.freezed.dart';

@freezed
abstract class FocusSession with _$FocusSession {
  const factory FocusSession({
    required String id,
    required String mode,
    required int workDurationMinutes,
    required int breakDurationMinutes,
    required int longBreakDurationMinutes,
    required int sessionsBeforeLongBreak,
    required int completedSessions,
    required int totalWorkMinutes,
    required int totalBreakMinutes,
    required DateTime startedAt,
    DateTime? endedAt,
    DateTime? pausedAt,
    Duration? accumulatedWorkTime,
    Duration? accumulatedBreakTime,
    String? habitId,
    String? projectName,
    String? taskId,
    String? projectId,
    String? outcome,
    int? focusRating,
    String? reflectionNotes,
    required bool isActive,
    required bool isPaused,
    required bool isBreak,
  }) = _FocusSession;

  const FocusSession._();

  factory FocusSession.create({
    required String mode,
    int workDurationMinutes = 25,
    int breakDurationMinutes = 5,
    int longBreakDurationMinutes = 15,
    int sessionsBeforeLongBreak = 4,
    String? habitId,
    String? projectName,
    String? taskId,
    String? projectId,
    String? outcome,
  }) {
    final now = AppClock.now();
    return FocusSession(
      id: IdGenerator.generateSessionId(),
      mode: mode,
      workDurationMinutes: workDurationMinutes,
      breakDurationMinutes: breakDurationMinutes,
      longBreakDurationMinutes: longBreakDurationMinutes,
      sessionsBeforeLongBreak: sessionsBeforeLongBreak,
      completedSessions: 0,
      totalWorkMinutes: 0,
      totalBreakMinutes: 0,
      startedAt: now,
      isActive: true,
      isPaused: false,
      isBreak: false,
      // Initialise to zero so the live clock (elapsedWorkTime / elapsedBreakTime)
      // works from the very first frame. Previously these were null, which
      // forced the getters to return Duration.zero and froze the timer ring
      // and elapsed display for the entire first work phase.
      accumulatedWorkTime: Duration.zero,
      accumulatedBreakTime: Duration.zero,
      habitId: habitId,
      projectName: projectName,
      taskId: taskId,
      projectId: projectId,
      outcome: outcome,
    );
  }

  Duration get currentWorkDuration => Duration(minutes: workDurationMinutes);
  Duration get currentBreakDuration =>
      (completedSessions + 1) % sessionsBeforeLongBreak == 0
          ? Duration(minutes: longBreakDurationMinutes)
          : Duration(minutes: breakDurationMinutes);

  Duration get elapsedWorkTime {
    if (accumulatedWorkTime == null) return Duration.zero;
    if (isPaused || !isActive || isBreak) return accumulatedWorkTime!;
    return accumulatedWorkTime! + AppClock.now().difference(startedAt);
  }

  Duration get elapsedBreakTime {
    if (accumulatedBreakTime == null) return Duration.zero;
    if (isPaused || !isActive || !isBreak) return accumulatedBreakTime!;
    return accumulatedBreakTime! +
        AppClock.now().difference(pausedAt ?? startedAt);
  }

  Duration get currentPhaseElapsed {
    if (isBreak) return elapsedBreakTime;
    return elapsedWorkTime;
  }

  Duration get currentPhaseTarget {
    if (isBreak) return currentBreakDuration;
    return currentWorkDuration;
  }

  double get currentPhaseProgress {
    final target = currentPhaseTarget;
    if (target.inSeconds == 0) return 0.0;
    return (currentPhaseElapsed.inSeconds / target.inSeconds).clamp(0.0, 1.0);
  }

  String get formattedElapsed {
    final elapsed = isBreak ? elapsedBreakTime : elapsedWorkTime;
    return elapsed.formatTimer();
  }

  String get formattedRemaining {
    final target = currentPhaseTarget;
    final elapsed = currentPhaseElapsed;
    final remaining = target - elapsed;
    if (remaining.isNegative) return '0:00';
    return remaining.formatTimer();
  }

  FocusSession startWork() {
    return copyWith(
      isActive: true,
      isPaused: false,
      isBreak: false,
      startedAt: AppClock.now(),
      accumulatedWorkTime: Duration.zero,
      accumulatedBreakTime: Duration.zero,
    );
  }

  FocusSession startBreak() {
    return copyWith(
      isBreak: true,
      isPaused: false,
      pausedAt: AppClock.now(),
      accumulatedWorkTime: elapsedWorkTime,
      // Reset the break counter: `elapsedBreakTime` adds `AppClock.now() -
      // pausedAt` on top of `accumulatedBreakTime`, so keeping the previous
      // break's value here would make the second break start already overdue.
      accumulatedBreakTime: Duration.zero,
    );
  }

  FocusSession pause() {
    if (isPaused) return this;
    return copyWith(
      isPaused: true,
      pausedAt: AppClock.now(),
      accumulatedWorkTime: isBreak ? accumulatedWorkTime : elapsedWorkTime,
      accumulatedBreakTime: isBreak ? elapsedBreakTime : accumulatedBreakTime,
    );
  }

  FocusSession resume() {
    if (!isPaused) return this;
    return copyWith(
      isPaused: false,
      startedAt: AppClock.now(),
      pausedAt: null,
    );
  }

  FocusSession completeSession() {
    if (isBreak) {
      return copyWith(
        totalBreakMinutes: totalBreakMinutes + currentBreakDuration.inMinutes,
        isBreak: false,
        isPaused: false,
        accumulatedBreakTime: Duration.zero,
        accumulatedWorkTime: Duration.zero,
        startedAt: AppClock.now(),
      );
    } else {
      final newCompletedSessions = completedSessions + 1;

      return copyWith(
        completedSessions: newCompletedSessions,
        totalWorkMinutes: totalWorkMinutes + workDurationMinutes,
        isBreak: true,
        isPaused: false,
        accumulatedWorkTime: Duration.zero,
        accumulatedBreakTime: Duration.zero,
        pausedAt: AppClock.now(),
        // Rebase the clock: the finished work minutes are already folded into
        // `totalWorkMinutes`, so leaving `startedAt` in the past would let
        // `endSession()` add the very same minutes a second time.
        startedAt: AppClock.now(),
      );
    }
  }

  FocusSession endSession({int? focusRating, String? reflectionNotes}) {
    return copyWith(
      isActive: false,
      isPaused: false,
      endedAt: AppClock.now(),
      focusRating: focusRating,
      reflectionNotes: reflectionNotes,
      totalWorkMinutes: totalWorkMinutes + elapsedWorkTime.inMinutes,
      totalBreakMinutes: totalBreakMinutes + elapsedBreakTime.inMinutes,
    );
  }
}

extension DurationExtensions on Duration {
  String formatTimer() {
    final hours = inHours;
    final minutes = inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
