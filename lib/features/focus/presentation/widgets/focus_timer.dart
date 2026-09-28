import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/focus_controller.dart';
import '../../domain/entities/focus_session.dart';

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
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final session = widget.session;
    final progress = ref.watch(focusProgressProvider);

    if (session == null) {
      return _scrollIfNeeded(_buildSetupView(context));
    }

    final isWork = !session.isBreak;
    final phaseColor = isWork ? colorScheme.primary : colorScheme.tertiary;
    final phaseLabel = isWork ? 'Focus' : 'Break';
    final phaseIcon =
        isWork ? Icons.center_focus_strong_rounded : Icons.coffee_outlined;

    return _scrollIfNeeded(Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPhaseIndicator(context, phaseLabel, phaseIcon, phaseColor),
        const SizedBox(height: 32),
        _buildTimerCircle(context, progress, phaseColor, session),
        const SizedBox(height: 32),
        _buildSessionInfo(context, session),
        const SizedBox(height: 32),
        _buildControls(context, session, phaseColor),
      ],
    ));
  }

  Widget _buildSetupView(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(focusControllerProvider);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.center_focus_strong_rounded,
            size: 80,
            color: colorScheme.onPrimaryContainer,
          ),
        ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
        const SizedBox(height: 32),
        Text(
          'Ready to Focus?',
          style: theme.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose a mode and duration to start your deep work session',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        _buildModeSelector(context),
        const SizedBox(height: 24),
        _buildDurationControls(context),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: widget.onStart,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start Session'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
        if (state.selectedHabitId != null || state.projectName != null) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: widget.onSettings,
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Session Settings'),
          ),
        ],
      ],
    );
  }

  Widget _buildModeSelector(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(focusControllerProvider);
    final modes = ['Pomodoro', 'Custom', 'Stopwatch'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mode',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: modes.map((mode) {
            final isSelected = state.selectedMode == mode;
            return FilterChip(
              label: Text(mode),
              selected: isSelected,
              onSelected: (_) =>
                  ref.read(focusControllerProvider.notifier).setMode(mode),
              selectedColor: theme.colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            );
          }).toList(),
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
            const SizedBox(width: 16),
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
          const SizedBox(height: 16),
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
              const SizedBox(width: 16),
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
        Text(label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value.toString(),
          decoration: InputDecoration(
            suffixText: isMinutes ? ' min' : '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
          onChanged: (v) => onChanged(int.tryParse(v) ?? value),
        ),
      ],
    );
  }

  Widget _buildPhaseIndicator(
      BuildContext context, String label, IconData icon, Color color) {
    final theme = Theme.of(context);
    final session = widget.session!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 16),
        Column(
          children: [
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              session.isBreak ? 'Recharge' : 'Deep Work',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimerCircle(BuildContext context, double progress, Color color,
      FocusSession session) {
    final theme = Theme.of(context);
    final formattedTime =
        session.isBreak ? session.formattedRemaining : session.formattedElapsed;

    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 280,
            height: 280,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 12,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formattedTime,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w300,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                session.isBreak ? 'Time to recharge' : 'Stay focused',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ).animate().fadeIn(duration: 300.ms),
        ],
      ),
    );
  }

  Widget _buildSessionInfo(BuildContext context, FocusSession session) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            Icons.check_circle_outline,
            'Completed',
            '${session.completedSessions}',
            colorScheme.primary,
          ),
          _buildStatItem(
            context,
            Icons.timer_outlined,
            'Focus Time',
            '${session.totalWorkMinutes} min',
            colorScheme.tertiary,
          ),
          _buildStatItem(
            context,
            Icons.repeat_outlined,
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
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700, color: color),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
            icon: const Icon(Icons.close_rounded),
            label: const Text('Discard'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: widget.onEnd,
            icon: const Icon(Icons.flag_rounded),
            label: const Text('End Session'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              backgroundColor: theme.colorScheme.tertiary,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isPaused)
          FilledButton.icon(
            onPressed: widget.onResume,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Resume'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              backgroundColor: phaseColor,
            ),
          ).animate().scale(duration: 200.ms, curve: Curves.elasticOut)
        else
          OutlinedButton.icon(
            onPressed: widget.onPause,
            icon: const Icon(Icons.pause_rounded),
            label: const Text('Pause'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: widget.onCompletePhase,
          icon: Icon(
              session.isBreak ? Icons.check_rounded : Icons.forward_rounded),
          label: Text(session.isBreak ? 'Start Focus' : 'Start Break'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            backgroundColor: session.isBreak
                ? theme.colorScheme.primary
                : theme.colorScheme.tertiary,
          ),
        ),
      ],
    );
  }
}
