import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/focus_controller.dart';
import '../../domain/entities/focus_session.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/text_styles.dart';
import '../../../../app/widgets/glass_card.dart';
import '../../../../app/widgets/glow_button.dart';
import '../../../../app/widgets/pill_chip.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class FocusTimer extends ConsumerStatefulWidget {
  final FocusSession? session;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCompletePhase;
  final VoidCallback? onEnd;
  final VoidCallback? onDiscard;
  final VoidCallback? onSettings;

  const FocusTimer({
    super.key,
    this.session,
    this.onStart,
    this.onPause,
    this.onResume,
    this.onCompletePhase,
    this.onEnd,
    this.onDiscard,
    this.onSettings,
  });

  @override
  ConsumerState<FocusTimer> createState() => _FocusTimerState();
}

class _FocusTimerState extends ConsumerState<FocusTimer>
    with SingleTickerProviderStateMixin {
  /// Drives the slow breath around the timer ring.
  ///
  /// Runs only while a phase is actually counting down. A paused session is a
  /// moment of stillness, and a ring that keeps pulsing through it tells the
  /// user time is still moving when it is not.
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      // ~4s each way. Faster than this reads as a heartbeat; slower stops
      // registering as motion at all.
      duration: const Duration(milliseconds: 4000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBreath();
  }

  @override
  void didUpdateWidget(FocusTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncBreath();
  }

  void _syncBreath() {
    final session = widget.session;
    final shouldBreathe =
        session != null && session.isActive && !session.isPaused;

    if (shouldBreathe) {
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
    } else {
      // Settle back to neutral rather than freezing wherever the breath stopped,
      // so pausing mid-inhale does not leave a half-grown halo.
      _breath.stop();
      _breath.animateTo(0, duration: AppAnimationTokens.slow);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  /// Lets a phase view scroll when it does not fit the space it is given
  /// (short screens, large text scale) while still being centred when it
  /// does fit.
  Widget _scrollIfNeeded(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final session = widget.session;
    final progress = ref.watch(focusProgressProvider);

    if (session == null) {
      return _scrollIfNeeded(_buildSetupView(context));
    }

    final isWork = !session.isBreak;
    // The running ring is sky blue rather than `colorScheme.primary`. Primary
    // is the colour of a *button*; the ring is the light the app is pouring
    // into the session, and it has to be the brighter, more luminous blue to
    // read that way. The light scheme keeps the deeper blue, where #0EA5E9
    // would sit at 2.6:1 on pearl and fail the 3:1 floor for a graphical
    // object. Breaks stay amber so the two phases never look alike.
    final phaseColor = isWork
        ? AppColors.accent(
            colorScheme, AppColors.accentPrimaryDeep, AppColors.accentLiveDark)
        : colorScheme.tertiary;
    final phaseLabel = isWork ? 'Focus' : 'Break';
    final phaseIcon = isWork ? LucideIcons.crosshair : LucideIcons.coffee;

    return _scrollIfNeeded(Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPhaseIndicator(context, phaseLabel, phaseIcon, phaseColor),
        const SizedBox(height: AppSpacingTokens.xl),
        _buildTimerCircle(context, progress, phaseColor, session),
        const SizedBox(height: AppSpacingTokens.xl),
        _buildSessionInfo(context, session),
        const SizedBox(height: AppSpacingTokens.xl),
        _buildControls(context, session, phaseColor),
      ],
    ));
  }

  Widget _buildSetupView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(focusControllerProvider);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // A breathing halo rather than a solid disc: this is the resting state,
        // and it should invite rather than demand attention.
        _BreathingHalo(
          controller: _breath,
          child: SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.22),
                        AppColors.accentDeep.withValues(alpha: 0.12),
                      ],
                    ),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Icon(
                  LucideIcons.crosshair,
                  size: 66,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: AppSpacingTokens.xl),
        const Text(
          'Ready to Focus?',
          textAlign: TextAlign.center,
          style: AppTextStyles.headlineSmall,
        ),
        const SizedBox(height: AppSpacingTokens.sm),
        Text(
          'Choose a mode and duration to start your deep work session',
          style: AppTextStyles.bodyMedium.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacingTokens.lg),
        _buildModeSelector(context),
        const SizedBox(height: AppSpacingTokens.lg),
        _buildDurationControls(context),
        const SizedBox(height: AppSpacingTokens.xl),
        GlowButton(
          label: 'Start Session',
          icon: LucideIcons.play,
          accent: colorScheme.primary,
          onPressed: widget.onStart,
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
        if (state.selectedHabitId != null || state.projectName != null) ...[
          const SizedBox(height: AppSpacingTokens.sm),
          TextButton.icon(
            onPressed: widget.onSettings,
            icon: const Icon(LucideIcons.settings, size: 18),
            label: const Text('Session Settings'),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModeSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(focusControllerProvider);
    const modes = ['Pomodoro', 'Custom', 'Stopwatch'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mode', style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacingTokens.sm),
        // Centred rather than a full-width row: the setup column is centred, and
        // a left-aligned pill row under a centred heading read as misaligned.
        Center(
          child: GlassPillRow(
            pills: [
              for (final mode in modes)
                GlassPill(
                  label: mode,
                  selected: state.selectedMode == mode,
                  icon: switch (mode) {
                    'Pomodoro' => LucideIcons.timer,
                    'Custom' => LucideIcons.slidersHorizontal,
                    _ => LucideIcons.hourglass,
                  },
                  accent: colorScheme.primary,
                  onTap: () =>
                      ref.read(focusControllerProvider.notifier).setMode(mode),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDurationControls(BuildContext context) {
    final state = ref.watch(focusControllerProvider);

    if (state.selectedMode == 'Stopwatch') {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _buildDurationField(
                    context,
                    'Work',
                    state.workDuration,
                    (v) => ref
                        .read(focusControllerProvider.notifier)
                        .setWorkDuration(v))),
            const SizedBox(width: AppSpacingTokens.md),
            Expanded(
                child: _buildDurationField(
                    context,
                    'Break',
                    state.breakDuration,
                    (v) => ref
                        .read(focusControllerProvider.notifier)
                        .setBreakDuration(v))),
          ],
        ),
        if (state.selectedMode == 'Pomodoro') ...[
          const SizedBox(height: AppSpacingTokens.md),
          Row(
            children: [
              Expanded(
                  child: _buildDurationField(
                      context,
                      'Long Break',
                      state.longBreakDuration,
                      (v) => ref
                          .read(focusControllerProvider.notifier)
                          .setLongBreakDuration(v))),
              const SizedBox(width: AppSpacingTokens.md),
              Expanded(
                  child: _buildDurationField(
                      context,
                      'Sessions',
                      state.sessionsBeforeLongBreak,
                      (v) => ref
                          .read(focusControllerProvider.notifier)
                          .setSessionsBeforeLongBreak(v),
                      isMinutes: false)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDurationField(BuildContext context, String label, int value,
      ValueChanged<int> onChanged,
      {bool isMinutes = true}) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacingTokens.xs + 2),
        TextFormField(
          initialValue: value.toString(),
          decoration: InputDecoration(
            suffixText: isMinutes ? 'min' : '',
            // No visible border: the field sits in a darker inset well so it
            // reads as a slot the value drops into, not a form control stamped
            // on top of the page.
            filled: true,
            fillColor: AppColors.insetFill(theme.colorScheme, opacity: 0.6),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacingTokens.md,
              vertical: AppSpacingTokens.sm + 4,
            ),
          ),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
          onChanged: (v) => onChanged(int.tryParse(v) ?? value),
        ),
      ],
    );
  }

  Widget _buildPhaseIndicator(
      BuildContext context, String label, IconData icon, Color color) {
    final theme = Theme.of(context);
    final session = widget.session!;

    // A pill rather than a bare icon + two lines: the phase is the single most
    // important piece of state on the screen, and enclosing it in glass gives it
    // a boundary you can find without reading the text.
    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacingTokens.lg,
        vertical: AppSpacingTokens.sm + 2,
      ),
      radius: AppRadiusTokens.full,
      tint: color,
      tintOpacity: 0.14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color, blurRadius: 10, spreadRadius: -2),
              ],
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacingTokens.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTextStyles.overline.copyWith(color: color),
              ),
              Text(
                session.isBreak ? 'Recharge' : 'Deep Work',
                style: AppTextStyles.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: AppAnimationTokens.medium)
        .slideY(begin: -0.1, end: 0);
  }

  Widget _buildTimerCircle(BuildContext context, double progress, Color color,
      FocusSession session) {
    final theme = Theme.of(context);
    final formattedTime =
        session.isBreak ? session.formattedRemaining : session.formattedElapsed;

    // The halo breathes outside the ring so the progress arc itself stays a
    // precise instrument - scaling the ring would make the arc harder to read at
    // a glance, which is the one job it has.
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_breath.value);
        final scale = 1 + t * 0.035;
        final glow = 0.35 + t * 0.3;

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: glow * 0.5),
                blurRadius: 40 + t * 26,
                spreadRadius: t * 6,
              ),
            ],
          ),
          // Named so tests can sample the breath. There are several `Transform`s
          // in this subtree (the entrance scale, the icon swaps) and the
          // breathing one is the only one whose scale is neither 1 nor constant.
          child: Transform.scale(
            key: const ValueKey('focus-breath'),
            scale: scale,
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: 280,
        height: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // A wide, faint outer ring behind the arc: reads as the halo of the
            // light source rather than as a second progress indicator, because
            // it never changes value.
            SizedBox(
              width: 268,
              height: 268,
              child: CircularProgressIndicator(
                value: 1,
                strokeWidth: 1,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  color.withValues(alpha: 0.18),
                ),
              ),
            ),
            SizedBox(
              width: 268,
              height: 268,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => CircularProgressIndicator(
                  value: value,
                  strokeWidth: 12,
                  strokeCap: StrokeCap.round,
                  backgroundColor: color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    // A gradient that rotates around the ring would be prettier,
                    // but a SweepGradient on a progress indicator jumps at the
                    // wrap point and reads as a glitch. A two-stop gradient along
                    // the arc stays smooth.
                    Color.lerp(color, AppColors.accentDeep, 0.45) ?? color,
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: AppAnimationTokens.fast,
                  child: Text(
                    formattedTime,
                    key: ValueKey(formattedTime),
                    style: AppTextStyles.displaySmall.copyWith(
                      fontWeight: FontWeight.w300,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacingTokens.sm),
                Text(
                  session.isBreak ? 'Time to recharge' : 'Stay focused',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionInfo(BuildContext context, FocusSession session) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacingTokens.md,
        vertical: AppSpacingTokens.lg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            LucideIcons.circleCheck,
            'Completed',
            '${session.completedSessions}',
            colorScheme.primary,
          ),
          _buildStatItem(
            context,
            LucideIcons.timer,
            'Focus Time',
            '${session.totalWorkMinutes} min',
            colorScheme.tertiary,
          ),
          _buildStatItem(
            context,
            LucideIcons.repeat,
            'Cycle',
            '${session.completedSessions % session.sessionsBeforeLongBreak + 1}/${session.sessionsBeforeLongBreak}',
            colorScheme.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, IconData icon, String label,
      String value, Color color) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: AppSpacingTokens.xs + 2),
        Text(
          value,
          style: AppTextStyles.metricMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.labelSmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildControls(
      BuildContext context, FocusSession session, Color phaseColor) {
    final theme = Theme.of(context);
    final isPaused = session.isPaused;
    final isActive = session.isActive;

    if (!isActive) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: widget.onDiscard,
            icon: const Icon(LucideIcons.x, size: 18),
            label: const Text('Discard'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(
                color: theme.colorScheme.error.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: AppSpacingTokens.md),
          OutlinedButton.icon(
            onPressed: widget.onEnd,
            icon: const Icon(LucideIcons.flag, size: 18),
            label: const Text('End Session'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.tertiary,
              side: BorderSide(
                color: theme.colorScheme.tertiary.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isPaused)
              GlowButton(
                label: 'Resume',
                icon: LucideIcons.play,
                accent: phaseColor,
                onPressed: widget.onResume,
                height: 52,
              ).animate().scale(duration: 200.ms, curve: Curves.elasticOut)
            else
              OutlinedButton.icon(
                onPressed: widget.onPause,
                icon: const Icon(LucideIcons.pause, size: 20),
                label: const Text('Pause'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacingTokens.xl,
                    vertical: AppSpacingTokens.lg,
                  ),
                  foregroundColor: phaseColor,
                  side: BorderSide(color: phaseColor.withValues(alpha: 0.5)),
                  shape: const StadiumBorder(),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacingTokens.md),
        // Skipping to the next phase is the primary action during a session, so
        // it gets the full-width glowing pill and the pause control stays
        // secondary. Sized in a constrained box so a very long localised label
        // cannot make the glow shadow spill across the whole screen.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: SizedBox(
            width: double.infinity,
            child: GlowButton(
              label: session.isBreak ? 'Start Focus' : 'Start Break',
              icon: session.isBreak ? LucideIcons.check : LucideIcons.forward,
              accent: session.isBreak
                  ? theme.colorScheme.primary
                  : theme.colorScheme.tertiary,
              onPressed: widget.onCompletePhase,
              height: 54,
            ),
          ),
        ),
      ],
    );
  }
}

/// A soft glow that swells and fades around [child] on [controller].
///
/// The scale and the shadow are driven from the same value so the two can never
/// drift out of phase, which is what makes a separate "pulse in, glow out"
/// implementation look seasick.
class _BreathingHalo extends StatelessWidget {
  final AnimationController controller;
  final Widget child;

  const _BreathingHalo({required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(controller.value);
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.18 + t * 0.18),
                blurRadius: 30 + t * 24,
                spreadRadius: t * 4,
              ),
            ],
          ),
          child: Transform.scale(scale: 1 + t * 0.04, child: child),
        );
      },
      child: child,
    );
  }
}
