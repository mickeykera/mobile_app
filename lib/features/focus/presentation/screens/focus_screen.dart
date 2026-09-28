import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/focus_controller.dart';
import '../widgets/focus_timer.dart';
import '../../domain/entities/focus_session.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTicker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(focusControllerProvider.notifier).tick();
    }
  }

  void _startTicker() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        ref.read(focusControllerProvider.notifier).tick();
      }
      return mounted;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(focusControllerProvider);
    final activeSession = controller.activeSession;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              Expanded(
                child: FocusTimer(
                  session: activeSession,
                  onStart: _startSession,
                  onPause: _pauseSession,
                  onResume: _resumeSession,
                  onCompletePhase: _completePhase,
                  onEnd: _showEndSessionDialog,
                  onDiscard: _discardSession,
                  onSettings: _showSettings,
                ),
              ),
              if (activeSession != null && !activeSession.isActive) ...[
                const SizedBox(height: 24),
                _buildRecentSessions(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(focusControllerProvider);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deep Work',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                _getGreeting(),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (state.activeSession == null)
          IconButton(
            onPressed: _showSettings,
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Session Settings',
          ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning — ready to focus?';
    if (hour < 17) return 'Good afternoon — let\'s dive in';
    return 'Good evening — time for deep work';
  }

  Future<void> _startSession() async {
    final result =
        await ref.read(focusControllerProvider.notifier).startSession();
    if (!result.isRight && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.left?.userMessage ?? 'Unknown error')),
      );
    }
  }

  Future<void> _pauseSession() async {
    await ref.read(focusControllerProvider.notifier).pauseSession();
  }

  Future<void> _resumeSession() async {
    await ref.read(focusControllerProvider.notifier).resumeSession();
  }

  Future<void> _completePhase() async {
    await ref.read(focusControllerProvider.notifier).completePhase();
  }

  Future<void> _showEndSessionDialog() async {
    final session = ref.read(focusControllerProvider).activeSession;
    if (session == null) return;

    int? focusRating;
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How focused were you?',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                final rating = index + 1;
                final isSelected = focusRating == rating;
                return GestureDetector(
                  onTap: () {
                    setState(() => focusRating = rating);
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                    child: Center(
                      child: Text(
                        '$rating',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Reflection Notes (optional)',
                hintText: 'What did you accomplish? Any insights?',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _endSession(
                  focusRating,
                  notesController.text.isNotEmpty
                      ? notesController.text
                      : null);
            },
            child: const Text('Save & End'),
          ),
        ],
      ),
    );
  }

  Future<void> _endSession(int? focusRating, String? notes) async {
    final result = await ref.read(focusControllerProvider.notifier).endSession(
          focusRating: focusRating,
          reflectionNotes: notes,
        );
    if (!result.isRight && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.left?.userMessage ?? 'Unknown error')),
      );
    }
  }

  Future<void> _discardSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Session?'),
        content: const Text(
            'This will delete the current session without saving. Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(focusControllerProvider.notifier).discardSession();
    }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SessionSettingsSheet(),
    );
  }

  Widget _buildRecentSessions(BuildContext context) {
    final theme = Theme.of(context);
    final recentSessions = ref.watch(focusControllerProvider).recentSessions;

    if (recentSessions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Sessions',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recentSessions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final session = recentSessions[index];
              return _SessionCard(session: session);
            },
          ),
        ),
      ],
    );
  }
}

class _SessionSettingsSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Session Settings',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          _buildModeSelector(context, ref),
          const SizedBox(height: 24),
          _buildDurationControls(context, ref),
          const SizedBox(height: 24),
          _buildHabitLink(context, ref),
          const SizedBox(height: 24),
          _buildProjectName(context, ref),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Done'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildModeSelector(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(focusControllerProvider);
    final modes = ['Pomodoro', 'Custom', 'Stopwatch'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mode',
            style: theme.textTheme.titleMedium
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

  Widget _buildDurationControls(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(focusControllerProvider);

    if (state.selectedMode == 'Stopwatch') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Durations',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _DurationField(
                    label: 'Work',
                    value: state.workDuration,
                    onChanged: (v) => ref
                        .read(focusControllerProvider.notifier)
                        .setWorkDuration(v))),
            const SizedBox(width: 16),
            Expanded(
                child: _DurationField(
                    label: 'Break',
                    value: state.breakDuration,
                    onChanged: (v) => ref
                        .read(focusControllerProvider.notifier)
                        .setBreakDuration(v))),
          ],
        ),
        if (state.selectedMode == 'Pomodoro') ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _DurationField(
                      label: 'Long Break',
                      value: state.longBreakDuration,
                      onChanged: (v) => ref
                          .read(focusControllerProvider.notifier)
                          .setLongBreakDuration(v))),
              const SizedBox(width: 16),
              Expanded(
                  child: _DurationField(
                      label: 'Sessions',
                      value: state.sessionsBeforeLongBreak,
                      onChanged: (v) => ref
                          .read(focusControllerProvider.notifier)
                          .setSessionsBeforeLongBreak(v),
                      isMinutes: false)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildHabitLink(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(focusControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Link to Habit (optional)',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: state.selectedHabitId,
          decoration: const InputDecoration(
            labelText: 'Habit ID',
            hintText: 'Enter habit ID to link this session',
            prefixIcon: Icon(Icons.link_outlined),
          ),
          onChanged: (v) => ref
              .read(focusControllerProvider.notifier)
              .setSelectedHabit(v.isEmpty ? null : v),
        ),
      ],
    );
  }

  Widget _buildProjectName(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(focusControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Project Name (optional)',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: state.projectName,
          decoration: const InputDecoration(
            labelText: 'Project',
            hintText: 'e.g., Flutter App, Writing, Learning',
            prefixIcon: Icon(Icons.folder_outlined),
          ),
          onChanged: (v) => ref
              .read(focusControllerProvider.notifier)
              .setProjectName(v.isEmpty ? null : v),
        ),
      ],
    );
  }
}

class _DurationField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final bool isMinutes;

  const _DurationField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.isMinutes = true,
  });

  @override
  Widget build(BuildContext context) {
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
}

class _SessionCard extends StatelessWidget {
  final FocusSession session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isWork = session.mode != 'Stopwatch';

    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isWork ? colorScheme.primary : colorScheme.tertiary)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isWork
                      ? Icons.center_focus_strong_rounded
                      : Icons.timer_outlined,
                  size: 16,
                  color: isWork ? colorScheme.primary : colorScheme.tertiary,
                ),
              ),
              const Spacer(),
              Text(
                session.mode,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${session.totalWorkMinutes} min',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            '${session.completedSessions} sessions • ${session.formattedElapsed}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          if (session.projectName != null) ...[
            const SizedBox(height: 4),
            Text(
              session.projectName!,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: colorScheme.primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
