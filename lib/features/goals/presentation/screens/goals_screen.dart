import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/text_styles.dart';
import '../../../../app/widgets/app_empty_state.dart';
import '../../../../app/widgets/glass_card.dart';
import '../../../../app/widgets/glow_button.dart';
import '../../../../app/widgets/pill_chip.dart';
import '../../../../app/widgets/pressable.dart';
import '../../../../app/widgets/progress_ring.dart';
import '../../../../core/constants/category_type.dart';
import '../../../../core/constants/item_status.dart';
import '../../../goals/domain/entities/goal.dart';
import '../../../goals/presentation/providers/goal_providers.dart';
import '../../../progress/domain/progress_metrics.dart';
import '../../../progress/presentation/providers/progress_providers.dart';
import '../../../projects/domain/entities/project.dart';

/// The "why" layer: every goal, the projects serving it, and how far along it is.
///
/// Goals move through the same lifecycle as projects. This screen owns the
/// create/edit actions for goals.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final scheme = Theme.of(context).colorScheme;
    final accent = AppColors.accent(
        scheme, AppColors.accentDeep, AppColors.accentDeepDark);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          const _Header(),
          if (goals.isEmpty) const _GoalsEmptyState(),
          for (final goal in goals) ...[
            SliverToBoxAdapter(child: _GoalCard(goal: goal, accent: accent)),
          ],
          const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacingTokens.xl)),
        ],
      ),
      floatingActionButton: GlowButton(
        label: 'New Goal',
        icon: LucideIcons.plus,
        accent: accent,
        height: 52,
        onPressed: () => _showGoalFormSheet(context, ref),
      ),
    );
  }

  Future<void> _showGoalFormSheet(BuildContext context, WidgetRef ref) async {
    final edited = await showModalBottomSheet<GoalFormData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _GoalForm(),
    );
    if (edited == null) return;

    final controller = ref.read(goalControllerProvider.notifier);
    final result = await controller.createGoal(
      title: edited.title,
      description: edited.description,
      targetDate: edited.targetDate,
      category: edited.category,
      color: edited.color,
      icon: edited.icon,
    );

    if (result.isLeft && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.left?.userMessage ?? 'Could not create goal'),
        ),
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          AppSpacingTokens.lg,
          MediaQuery.paddingOf(context).top + AppSpacingTokens.lg,
          AppSpacingTokens.lg,
          AppSpacingTokens.xl,
        ),
        decoration: BoxDecoration(
          gradient: AppGradients.header(scheme),
          border: Border(
            bottom: BorderSide(color: AppColors.hairline(scheme)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WHY',
                style: AppTextStyles.overline
                    .copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacingTokens.xs),
            Text('Goals',
                style: AppTextStyles.displaySmall
                    .copyWith(color: scheme.onSurface)),
          ],
        ),
      ).animate().fadeIn(duration: AppAnimationTokens.slow),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  final Goal goal;
  final Color accent;

  const _GoalCard({required this.goal, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final progress = ref.watch(goalProgressProvider(goal.id));
    final projects = ref.watch(projectsForGoalProvider(goal.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacingTokens.lg, 0, AppSpacingTokens.lg, AppSpacingTokens.md),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // A goal holding only recurring work has no finite ratio, and a
                // 0% ring would read as failure rather than as "not applicable".
                if (progress.hasFiniteTasks)
                  ProgressRing(
                    value: progress.completionRatio,
                    size: 56,
                    color: accent,
                    child: Text(
                      '${(progress.completionRatio * 100).round()}%',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: scheme.onSurface),
                    ),
                  )
                else
                  Icon(LucideIcons.target, size: 32, color: accent),
                const SizedBox(width: AppSpacingTokens.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleMedium
                            .copyWith(color: scheme.onSurface),
                      ),
                      const SizedBox(height: AppSpacingTokens.xs),
                      Text(
                        _summary(progress, projects.length),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (goal.status != ItemStatus.active)
                  _GoalStatusPill(status: goal.status),
              ],
            ),
            if (projects.isNotEmpty) ...[
              const SizedBox(height: AppSpacingTokens.md),
              Wrap(
                spacing: AppSpacingTokens.sm,
                runSpacing: AppSpacingTokens.sm,
                children: [
                  for (final project in projects)
                    _ProjectChip(project: project),
                ],
              ),
            ],
            const SizedBox(height: AppSpacingTokens.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (goal.status == ItemStatus.active)
                  _LifecycleButton(
                    label: 'Complete',
                    icon: LucideIcons.circleCheck,
                    onTap: () => ref
                        .read(goalControllerProvider.notifier)
                        .setStatus(goal.id, ItemStatus.completed),
                  )
                else if (goal.status == ItemStatus.completed) ...[
                  _LifecycleButton(
                    label: 'Reopen',
                    icon: LucideIcons.rotateCcw,
                    onTap: () => ref
                        .read(goalControllerProvider.notifier)
                        .setStatus(goal.id, ItemStatus.active),
                  ),
                  const SizedBox(width: AppSpacingTokens.sm),
                  _LifecycleButton(
                    label: 'Archive',
                    icon: LucideIcons.archive,
                    onTap: () => ref
                        .read(goalControllerProvider.notifier)
                        .setStatus(goal.id, ItemStatus.archived),
                  ),
                ]
                else if (goal.status == ItemStatus.archived)
                  _LifecycleButton(
                    label: 'Unarchive',
                    icon: LucideIcons.archiveRestore,
                    onTap: () => ref
                        .read(goalControllerProvider.notifier)
                        .setStatus(goal.id, ItemStatus.active),
                  ),
                const SizedBox(width: AppSpacingTokens.sm),
                _EditButton(
                  goal: goal,
                  accent: accent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// One line saying what the goal is made of and how far it has got.
  ///
  /// The two facts are joined rather than merged: "2 of 5 done · 90 min focused"
  /// keeps the task ratio and the time apart, which is the same rule the project
  /// detail screen follows.
  static String _summary(GoalProgress progress, int projectCount) {
    final tasks = progress.hasFiniteTasks
        ? '${progress.doneTaskCount}/${progress.totalTaskCount} tasks'
        : 'No finite tasks';
    final parts = <String>[
      tasks,
      if (projectCount > 0)
        '$projectCount project${projectCount == 1 ? '' : 's'}',
      '${progress.focusMinutes} min focused',
    ];
    return parts.join(' · ');
  }
}

class _ProjectChip extends StatelessWidget {
  final Project project;

  const _ProjectChip({required this.project});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = project.status == ItemStatus.completed;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacingTokens.sm, vertical: AppSpacingTokens.xs),
      decoration: BoxDecoration(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadiusTokens.full),
      ),
      // Each chip is its own drilldown target. A single row of decorative chips
      // would leave the project unreachable except from a menu.
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadiusTokens.full),
        onTap: () => context.push('/projects/${project.id}'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              done ? LucideIcons.circleCheck : LucideIcons.folder,
              size: 12,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacingTokens.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                project.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalStatusPill extends StatelessWidget {
  final ItemStatus status;

  const _GoalStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = status == ItemStatus.completed ? 'Completed' : 'Archived';

    return Text(
      label,
      style: AppTextStyles.labelSmall.copyWith(color: scheme.onSurfaceVariant),
    );
  }
}

class _GoalsEmptyState extends StatelessWidget {
  const _GoalsEmptyState();

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacingTokens.lg),
        child: AppEmptyState(
          icon: LucideIcons.target,
          title: 'No goals yet',
          message:
              'A goal is the why behind your projects. Add one when you are '
              'ready to say what the work is for.',
          actionLabel: 'Add a goal',
        ),
      ),
    );
  }
}

class _LifecycleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _LifecycleButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacingTokens.sm, vertical: AppSpacingTokens.xs),
        decoration: BoxDecoration(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadiusTokens.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacingTokens.xs),
            Text(
              label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditButton extends ConsumerWidget {
  final Goal goal;
  final Color accent;

  const _EditButton({required this.goal, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Pressable(
      onTap: () => _showEditSheet(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacingTokens.sm, vertical: AppSpacingTokens.xs),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadiusTokens.full),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.pencil, size: 12, color: accent),
            const SizedBox(width: AppSpacingTokens.xs),
            Text(
              'Edit',
              style: AppTextStyles.labelSmall.copyWith(color: accent),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditSheet(BuildContext context, WidgetRef ref) async {
    final edited = await showModalBottomSheet<GoalFormData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GoalForm(goal: goal),
    );
    if (edited == null) return;

    final controller = ref.read(goalControllerProvider.notifier);
    final updated = goal.copyWith(
      title: edited.title,
      description: edited.description,
      targetDate: edited.targetDate,
      category: edited.category,
      color: edited.color,
      icon: edited.icon,
      updatedAt: DateTime.now(),
    );
    final result = await controller.updateGoal(updated);

    if (result.isLeft && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.left?.userMessage ?? 'Could not update goal'),
        ),
      );
    }
  }
}

/// Data class for the goal form.
class GoalFormData {
  final String title;
  final String? description;
  final DateTime? targetDate;
  final String? category;
  final String? color;
  final String? icon;

  const GoalFormData({
    required this.title,
    this.description,
    this.targetDate,
    this.category,
    this.color,
    this.icon,
  });
}

/// The goal create/edit form sheet.
class _GoalForm extends ConsumerStatefulWidget {
  final Goal? goal;

  const _GoalForm({this.goal});

  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _targetDate;
  String? _category;
  String? _color;
  String? _icon;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    if (goal != null) {
      _titleController.text = goal.title;
      _descriptionController.text = goal.description ?? '';
      _targetDate = goal.targetDate;
      _category = goal.category;
      _color = goal.color;
      _icon = goal.icon;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.goal != null;
    final accent = AppColors.accent(theme.colorScheme,
        AppColors.accentDeep, AppColors.accentDeepDark);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadiusTokens.sheetTop),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardFill(theme.colorScheme, opacity: 0.94),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadiusTokens.sheetTop),
            ),
            border: Border(
              top: BorderSide(color: AppColors.hairline(theme.colorScheme)),
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom +
                  AppSpacingTokens.lg,
              left: AppSpacingTokens.lg,
              right: AppSpacingTokens.lg,
              top: AppSpacingTokens.sm,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin:
                          const EdgeInsets.only(bottom: AppSpacingTokens.md),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.3),
                        borderRadius:
                            BorderRadius.circular(AppRadiusTokens.full),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        isEditing ? 'Edit Goal' : 'New Goal',
                        style: AppTextStyles.headlineSmall
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      GlowIconButton(
                        icon: LucideIcons.x,
                        accent: theme.colorScheme.onSurfaceVariant,
                        size: 40,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacingTokens.lg),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Goal Title',
                      hintText: 'e.g., Learn Flutter',
                      prefixIcon: Icon(LucideIcons.target),
                    ),
                    maxLength: 120,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Please enter a goal title'
                            : null,
                    textInputAction: TextInputAction.next,
                    autofocus: !isEditing,
                  ),
                  const SizedBox(height: AppSpacingTokens.md),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'Why does this matter?',
                      prefixIcon: Icon(LucideIcons.fileText),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 2,
                    maxLength: 400,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: AppSpacingTokens.md),
                  _targetDateSelector(accent),
                  const SizedBox(height: AppSpacingTokens.md),
                  _categorySelector(accent),
                  const SizedBox(height: AppSpacingTokens.md),
                  _iconSelector(accent),
                  const SizedBox(height: AppSpacingTokens.lg),
                  GlowButton(
                    label: isEditing ? 'Save Changes' : 'Add Goal',
                    icon: isEditing ? LucideIcons.save : LucideIcons.plus,
                    accent: accent,
                    width: double.infinity,
                    onPressed: _save,
                  ),
                  const SizedBox(height: AppSpacingTokens.sm),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _targetDateSelector(Color accent) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = _targetDate != null && _isSameDay(_targetDate!, today);
    final isCustom = _targetDate != null && !isToday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Date (optional)',
          style: AppTextStyles.labelLarge
              .copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacingTokens.sm),
        Wrap(
          spacing: AppSpacingTokens.sm,
          runSpacing: AppSpacingTokens.sm,
          children: [
            GlassPill(
              label: 'No date',
              icon: LucideIcons.calendarX,
              selected: _targetDate == null,
              accent: accent,
              onTap: () => setState(() => _targetDate = null),
            ),
            GlassPill(
              label: 'Today',
              icon: LucideIcons.sun,
              selected: isToday,
              accent: accent,
              onTap: () => setState(() => _targetDate = today),
            ),
            GlassPill(
              label: _targetDate == null
                  ? 'Pick a date'
                  : '${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}',
              icon: LucideIcons.calendar,
              selected: isCustom,
              accent: accent,
              onTap: _pickDate,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked == null || !mounted) return;
    setState(() => _targetDate = DateTime(picked.year, picked.month, picked.day));
  }

  Widget _categorySelector(Color accent) {
    final theme = Theme.of(context);
    const categories = CategoryType.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category (optional)',
          style: AppTextStyles.labelLarge
              .copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacingTokens.sm),
        Wrap(
          spacing: AppSpacingTokens.sm,
          runSpacing: AppSpacingTokens.sm,
          children: [
            GlassPill(
              label: 'None',
              selected: _category == null,
              accent: accent,
              onTap: () => setState(() => _category = null),
            ),
            for (final cat in categories)
              GlassPill(
                label: cat.title,
                icon: cat.icon,
                selected: _category == cat.title,
                accent: cat.colorFor(theme.brightness),
                onTap: () => setState(() => _category = cat.title),
              ),
          ],
        ),
      ],
    );
  }

  Widget _iconSelector(Color accent) {
    final theme = Theme.of(context);
    const icons = [
      ('Target', LucideIcons.target),
      ('Trophy', LucideIcons.trophy),
      ('Shield', LucideIcons.shield),
      ('Star', LucideIcons.star),
      ('Heart', LucideIcons.heart),
      ('Gem', LucideIcons.gem),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Icon (optional)',
          style: AppTextStyles.labelLarge
              .copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacingTokens.sm),
        Wrap(
          spacing: AppSpacingTokens.sm,
          runSpacing: AppSpacingTokens.sm,
          children: [
            GlassPill(
              label: 'Default',
              selected: _icon == null,
              accent: accent,
              onTap: () => setState(() => _icon = null),
            ),
            for (final (name, iconData) in icons)
              GlassPill(
                label: name,
                icon: iconData,
                selected: _icon == name,
                accent: accent,
                onTap: () => setState(() => _icon = name),
              ),
          ],
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(GoalFormData(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      targetDate: _targetDate,
      category: _category,
      color: _color,
      icon: _icon,
    ));
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
