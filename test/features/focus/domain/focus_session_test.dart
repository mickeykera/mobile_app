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
    test('a freshly created session starts its timer from zero', () {
      // Regression: `accumulatedWorkTime` and `accumulatedBreakTime` were null
      // in `FocusSession.create()`, so `elapsedWorkTime` always returned
      // Duration.zero and the first work phase's ring and elapsed display
      // stayed frozen until the user paused or completed the phase.
      final session = _session();

      expect(session.accumulatedWorkTime, isNotNull);
      expect(session.accumulatedBreakTime, isNotNull);
      expect(session.elapsedWorkTime.inMilliseconds, lessThan(2000),
          reason: 'the live clock must start from zero, not be stuck');
      expect(session.currentPhaseProgress, lessThan(0.01),
          reason: 'a brand-new work phase must show ~0% progress');
      // A live clock, so this is either 25:00 or 24:59 depending on whether a
      // second slipped past between create() and the assertion. Asserting the
      // exact '25:00' makes the test fail at random on a slow machine.
      final remaining = session.formattedRemaining;
      expect(remaining == '25:00' || remaining == '24:59', isTrue,
          reason: 'the full work duration must be left to run, was $remaining');
    });

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
