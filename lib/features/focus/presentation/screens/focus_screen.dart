import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/focus_controller.dart';
import '../widgets/focus_timer.dart';
import '../../domain/entities/focus_session.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/text_styles.dart';
import '../../../../app/widgets/glass_card.dart';
import '../../../../app/widgets/glow_button.dart';
import '../../../../app/widgets/pressable.dart';
import '../../../../app/widgets/pill_chip.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen>
    with WidgetsBindingObserver {
  /// Bottom clearance for the floating nav bar, which draws over this screen.
  static const double _navBarClearance = 96;

  /// The pending one-second tick, held so it can be cancelled.
  ///
  /// This used to be a `Future.doWhile` chain with no handle on it, which left
  /// one timer in flight after every visit to the tab: leaving and coming back
  /// started a second ticker, so the countdown advanced at double speed and the
  /// controller ticked twice per second for the rest of the session.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
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
    _ticker = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      ref.read(focusControllerProvider.notifier).tick();
      _startTicker();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(focusControllerProvider);
    final activeSession = controller.activeSession;

    return Scaffold(
      body: Stack(
        children: [
          // One soft bloom behind the whole screen. The timer ring provides its
          // own light; this only keeps the page from reading as flat black.
          const Positioned(
            top: -160,
            right: -80,
            child: SizedBox(
              width: 420,
              height: 420,
              child: AuroraBackdrop(
                accentA: AppColors.neonCyan,
                accentB: AppColors.radiantViolet,
                opacity: 0.14,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacingTokens.gutter,
                AppSpacingTokens.gutter,
                AppSpacingTokens.gutter,
                // The nav bar floats over the page, so the focus controls need
                // this much clearance to stay tappable above it.
                _navBarClearance,
              ),
              child: Column(
                children: [
                  _buildHeader(context),
                  const SizedBox(height: AppSpacingTokens.md),
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
                    const SizedBox(height: AppSpacingTokens.md),
                    _buildRecentSessions(context),
                  ],
                ],
              ),
            ),
          ),
        ],
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
              ShaderMask(
                // Gradient headline, so the title is lit rather than flat white.
                shaderCallback: AppGradients.action(colorScheme.primary).createShader,
                child: Text(
                  'Deep Work',
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _getGreeting(),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (state.activeSession == null)
          GlowIconButton(
            icon: Icons.tune_rounded,
            accent: colorScheme.primary,
            tooltip: 'Session Settings',
            onPressed: _showSettings,
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
            const Text('How focused were you?', style: AppTextStyles.titleSmall),
            const SizedBox(height: AppSpacingTokens.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (index) {
                final rating = index + 1;
                final color = AppColors.ratingScaleColor(
                  Theme.of(context).colorScheme,
                  rating,
                );

                // Each step has its own colour, so the row reads as a scale you
                // move along rather than five interchangeable buttons.
                return _RatingDot(
                  rating: rating,
                  color: color,
                  selected: focusRating == rating,
                  onTap: () => setState(() => focusRating = rating),
                );
              }),
            ),
            const SizedBox(height: AppSpacingTokens.lg),
            TextField(
              controller: notesController,
              style: AppTextStyles.bodyMedium,
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
    final recentSessions = ref.watch(focusControllerProvider).recentSessions;

    if (recentSessions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Sessions', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacingTokens.sm + 2),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: recentSessions.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacingTokens.sm),
            itemBuilder: (context, index) => _SessionCard(
              session: recentSessions[index],
            )
                .animate()
                .fadeIn(duration: AppAnimationTokens.slow)
                .slideX(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
          ),
        ),
      ],
    );
  }
}

class _SessionSettingsSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Scrollable, and only as tall as it needs to be. The sheet holds two rows of
    // duration fields plus two text fields; on a short screen, or with the text
    // scale turned up, that is more than the viewport, and a non-scrolling
    // column just overflows.
    return ConstrainedBox(
      // Outside the scroll view, not inside it. A `maxHeight` on an inner
      // ConstrainedBox clamps the Column's own constraints, so the column still
      // overflows; the cap has to bound the scroll viewport instead.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: SingleChildScrollView(child: _buildSheetBody(context, ref)),
    );
  }

  Widget _buildSheetBody(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadiusTokens.sheetTop),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardFill(theme.colorScheme, opacity: 0.9),
            border: Border(
              top: BorderSide(color: AppColors.hairline(theme.colorScheme)),
            ),
          ),
          padding: const EdgeInsets.all(AppSpacingTokens.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacingTokens.lg),
              const Text('Session Settings', style: AppTextStyles.titleLarge),
              const SizedBox(height: AppSpacingTokens.lg),
              _buildModeSelector(context, ref),
              const SizedBox(height: AppSpacingTokens.lg),
              _buildDurationControls(context, ref),
              const SizedBox(height: AppSpacingTokens.lg),
              _buildHabitLink(context, ref),
              const SizedBox(height: AppSpacingTokens.lg),
              _buildProjectName(context, ref),
              const SizedBox(height: AppSpacingTokens.xl),
              GlowButton(
                label: 'Done',
                accent: theme.colorScheme.primary,
                width: double.infinity,
                height: 52,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: AppSpacingTokens.sm),
            ],
          ),
        ),
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
        const Text('Mode', style: AppTextStyles.titleSmall),
        const SizedBox(height: AppSpacingTokens.sm),
        Wrap(
          spacing: AppSpacingTokens.sm,
          runSpacing: AppSpacingTokens.sm,
          children: modes.map((mode) {
            return GlassPill(
              label: mode,
              selected: state.selectedMode == mode,
              accent: theme.colorScheme.primary,
              onTap: () =>
                  ref.read(focusControllerProvider.notifier).setMode(mode),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDurationControls(BuildContext context, WidgetRef ref) {
    final state = ref.watch(focusControllerProvider);

    if (state.selectedMode == 'Stopwatch') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Durations', style: AppTextStyles.titleSmall),
        const SizedBox(height: AppSpacingTokens.md),
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
    final state = ref.watch(focusControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Link to Habit (optional)', style: AppTextStyles.titleSmall),
        const SizedBox(height: AppSpacingTokens.sm),
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
    final state = ref.watch(focusControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Project Name (optional)', style: AppTextStyles.titleSmall),
        const SizedBox(height: AppSpacingTokens.sm),
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
}

class _SessionCard extends StatelessWidget {
  final FocusSession session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isWork = session.mode != 'Stopwatch';

    final accent = isWork ? colorScheme.primary : colorScheme.tertiary;

    return SizedBox(
      width: 200,
      child: GlassCard(
        tint: accent,
        tintOpacity: 0.09,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadiusTokens.sm),
                  ),
                  child: Icon(
                    isWork
                        ? Icons.center_focus_strong_rounded
                        : Icons.timer_outlined,
                    size: 16,
                    color: accent,
                  ),
                ),
                const Spacer(),
                Text(
                  session.mode,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacingTokens.sm + 2),
            Text(
              '${session.totalWorkMinutes} min',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${session.completedSessions} sessions • ${session.formattedElapsed}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (session.projectName != null) ...[
              const SizedBox(height: 2),
              Text(
                session.projectName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelMedium.copyWith(color: accent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One step of the 1-5 focus-rating scale.
///
/// Unselected steps show their own scale colour as a tinted well rather than a
/// flat grey, so the whole row reads as a gradient the user is choosing a point
/// on. The selected step lights up and grows.
class _RatingDot extends StatelessWidget {
  final int rating;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _RatingDot({
    required this.rating,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: 'Focus rating $rating',
      child: Pressable(
        onTap: onTap,
        pressScale: 0.9,
        semanticButton: false,
        child: AnimatedContainer(
          duration: AppAnimationTokens.medium,
          curve: Curves.easeOutCubic,
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 1 : 0.14),
            borderRadius: BorderRadius.circular(AppRadiusTokens.input),
            border: Border.all(
              color: color.withValues(alpha: selected ? 1 : 0.35),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 14,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: AppAnimationTokens.medium,
              style: AppTextStyles.metricMedium.copyWith(
                color: selected ? AppColors.onColorFor(color, scheme) : color,
                fontWeight: FontWeight.w700,
              ),
              child: Text('$rating'),
            ),
          ),
        ),
      ),
    );
  }
}
