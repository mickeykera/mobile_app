import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/features/focus/domain/entities/focus_session.dart';

FocusSession _session() => FocusSession.create(
      mode: 'Pomodoro',
      workDurationMinutes: 25,
      breakDurationMinutes: 5,
      longBreakDurationMinutes: 15,
      sessionsBeforeLongBreak: 4,
    );

void main() {
  group('FocusSession break accounting', () {
    test('a new break starts from zero', () {
      final inProgress = _session().copyWith(
        accumulatedBreakTime: const Duration(minutes: 4),
      );

      final breakSession = inProgress.startBreak();

      expect(breakSession.isBreak, isTrue);
      // Regression: `startBreak` used to carry the previous break's
      // `accumulatedBreakTime` over, so the countdown started at -4 minutes.
      expect(
        breakSession.elapsedBreakTime.inMilliseconds,
        lessThan(2000),
        reason: 'the new break must not inherit the previous break time',
      );
      expect(
        breakSession.currentPhaseProgress,
        lessThanOrEqualTo(0.01),
        reason: 'progress must not start near completion',
      );
    });

    test('a completed break does not leak into the next one', () {
      final midBreak = _session().copyWith(
        isBreak: true,
        pausedAt: DateTime.now(),
        accumulatedBreakTime: const Duration(minutes: 2),
      );

      final workAgain = midBreak.completeSession(); // ends the break
      expect(workAgain.isBreak, isFalse);

      final nextBreak = workAgain.startBreak();
      expect(nextBreak.elapsedBreakTime.inMilliseconds, lessThan(2000));
    });

    test('remaining break time is the full break duration at the start', () {
      final breakSession = _session().startBreak();

      expect(breakSession.currentPhaseTarget, const Duration(minutes: 5));
      final remaining = breakSession.formattedRemaining;
      expect(remaining == '05:00' || remaining == '04:59', isTrue,
          reason: 'was $remaining');
    });
  });

  group('FocusSession work accounting', () {
    test('finishing a phase rebases the clock so work is not counted twice',
        () {
      // Regression: `completeSession()` reset the accumulated work time but
      // left `startedAt` untouched, so a later `endSession()` added every
      // work minute a second time.
      final startedTenMinutesAgo = _session().copyWith(
        startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        accumulatedWorkTime: Duration.zero,
      );

      final onBreak = startedTenMinutesAgo.completeSession();

      expect(onBreak.totalWorkMinutes, 25);
      expect(onBreak.isBreak, isTrue);

      final ended = onBreak.endSession();

      expect(ended.totalWorkMinutes, 25,
          reason: 'the 10 minutes already counted must not be added again');
    });

    test('pausing freezes the elapsed work time', () {
      final paused = _session().pause();

      expect(paused.isPaused, isTrue);
      expect(paused.elapsedWorkTime.inMilliseconds, lessThan(1000),
          reason: 'a freshly paused session has not accumulated work yet');
    });

    test('work progress is derived from the phase target', () {
      final halfWay = _session().copyWith(
        accumulatedWorkTime: const Duration(minutes: 12, seconds: 30),
      );

      expect(halfWay.currentPhaseProgress, closeTo(0.5, 0.01));
      expect(halfWay.formattedElapsed, '12:30');
    });

    test('progress never exceeds 1', () {
      final overrun = _session().copyWith(
        accumulatedWorkTime: const Duration(minutes: 40),
      );

      expect(overrun.currentPhaseProgress, 1.0);
      expect(overrun.formattedRemaining, '0:00');
    });
  });
}
