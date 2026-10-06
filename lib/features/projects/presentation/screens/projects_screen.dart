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
import '../../../projects/domain/entities/project.dart';
import '../../../projects/presentation/providers/project_providers.dart';
import '../../../progress/domain/progress_metrics.dart';
import '../../../progress/presentation/providers/progress_providers.dart';

/// The projects list: every project, its goal, and how far along it is.
///
/// Read-only with respect to tasks. Projects move through the same lifecycle as
/// goals, and this screen owns the create/edit actions for projects.
class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final goals = ref.watch(goalsProvider);
    final scheme = Theme.of(context).colorScheme;
    final accent = AppColors.accent(
        scheme, AppColors.accentLiveDeep, AppColors.accentLive);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          const _Header(),
          if (projects.isEmpty) const _ProjectsEmptyState(),
          for (final project in projects) ...[
            SliverToBoxAdapter(
                child: _ProjectCard(project: project, accent: accent, goals: goals)),
          ],
          const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacingTokens.xl)),
        ],
      ),
      floatingActionButton: GlowButton(
        label: 'New Project',
        icon: LucideIcons.plus,
        accent: accent,
        height: 52,
        onPressed: () => _showProjectFormSheet(context, ref),
      ),
    );
  }

  Future<void> _showProjectFormSheet(
      BuildContext context, WidgetRef ref) async {
    final edited = await showModalBottomSheet<ProjectFormData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ProjectForm(),
    );
    if (edited == null) return;

    final controller = ref.read(projectControllerProvider.notifier);
    final result = await controller.createProject(
      title: edited.title,
      description: edited.description,
      goalId: edited.goalId,
      targetDate: edited.targetDate,
      category: edited.category,
      color: edited.color,
    );

    if (result.isLeft && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.left?.userMessage ?? 'Could not create project'),
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
            Text('WHAT',
                style: AppTextStyles.overline
                    .copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacingTokens.xs),
            Text('Projects',
                style: AppTextStyles.displaySmall
                    .copyWith(color: scheme.onSurface)),
          ],
        ),
      ).animate().fadeIn(duration: AppAnimationTokens.slow),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  final Project project;
  final Color accent;
  final List<Goal> goals;

  const _ProjectCard({
    required this.project,
    required this.accent,
    required this.goals,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final progress = ref.watch(projectProgressProvider(project.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacingTokens.lg, 0, AppSpacingTokens.lg, AppSpacingTokens.md),
      child: GlassCard(
        onTap: () => context.push('/projects/${project.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
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
                  Icon(LucideIcons.folder, size: 32, color: accent),
                const SizedBox(width: AppSpacingTokens.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleMedium
                            .copyWith(color: scheme.onSurface),
                      ),
                      const SizedBox(height: AppSpacingTokens.xs),
                      Text(
                        _summary(progress),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (project.status != ItemStatus.active)
                  _ProjectStatusPill(status: project.status),
                Icon(LucideIcons.chevronRight,
                    size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
            if (project.goalId != null) ...[
              const SizedBox(height: AppSpacingTokens.sm),
              _GoalLink(
                goalId: project.goalId!,
                goals: goals,
              ),
            ],
            const SizedBox(height: AppSpacingTokens.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (project.status == ItemStatus.active)
                  _LifecycleButton(
                    label: 'Complete',
                    icon: LucideIcons.circleCheck,
                    onTap: () => ref
                        .read(projectControllerProvider.notifier)
                        .setStatus(project.id, ItemStatus.completed),
                  )
                else if (project.status == ItemStatus.completed) ...[
                  _LifecycleButton(
                    label: 'Reopen',
                    icon: LucideIcons.rotateCcw,
                    onTap: () => ref
                        .read(projectControllerProvider.notifier)
                        .setStatus(project.id, ItemStatus.active),
                  ),
                  const SizedBox(width: AppSpacingTokens.sm),
                  _LifecycleButton(
                    label: 'Archive',
                    icon: LucideIcons.archive,
                    onTap: () => ref
                        .read(projectControllerProvider.notifier)
                        .setStatus(project.id, ItemStatus.archived),
                  ),
                ]
                else if (project.status == ItemStatus.archived)
                  _LifecycleButton(
                    label: 'Unarchive',
                    icon: LucideIcons.archiveRestore,
                    onTap: () => ref
                        .read(projectControllerProvider.notifier)
                        .setStatus(project.id, ItemStatus.active),
                  ),
                const SizedBox(width: AppSpacingTokens.sm),
                _EditButton(
                  project: project,
                  accent: accent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _summary(ProjectProgress progress) {
    final tasks = progress.hasFiniteTasks
        ? '${progress.doneTaskCount}/${progress.totalTaskCount} tasks'
        : 'No finite tasks';
    final parts = <String>[
      tasks,
      '${progress.focusMinutes} min focused',
    ];
    return parts.join(' · ');
  }
}

class _GoalLink extends StatelessWidget {
  final String goalId;
  final List<Goal> goals;

  const _GoalLink({required this.goalId, required this.goals});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final goal = goals.where((g) => g.id == goalId).firstOrNull;

    return InkWell(
      onTap: goal != null ? () => context.push('/goals') : null,
      borderRadius: BorderRadius.circular(AppRadiusTokens.full),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacingTokens.sm, vertical: AppSpacingTokens.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.target,
              size: 12,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacingTokens.xs),
            Text(
              goal?.title ?? 'Unknown goal',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall
                  .copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectStatusPill extends StatelessWidget {
  final ItemStatus status;

  const _ProjectStatusPill({required this.status});

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
  final Project project;
  final Color accent;

  const _EditButton({required this.project, required this.accent});

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
    final edited = await showModalBottomSheet<ProjectFormData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProjectForm(project: project),
    );
    if (edited == null) return;

    final controller = ref.read(projectControllerProvider.notifier);
    final updated = project.copyWith(
      title: edited.title,
      description: edited.description,
      goalId: edited.goalId,
      targetDate: edited.targetDate,
      category: edited.category,
      color: edited.color,
      updatedAt: DateTime.now(),
    );
    final result = await controller.updateProject(updated);

    if (result.isLeft && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.left?.userMessage ?? 'Could not update project'),
        ),
      );
    }
  }
}

class _ProjectsEmptyState extends StatelessWidget {
  const _ProjectsEmptyState();

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacingTokens.lg),
        child: AppEmptyState(
          icon: LucideIcons.folderPlus,
          title: 'No projects yet',
          message:
              'A project is a body of work. Add one when you have something to '
              'organize.',
          actionLabel: 'Add a project',
        ),
      ),
    );
  }
}

/// Data class for the project form.
class ProjectFormData {
  final String title;
  final String? description;
  final String? goalId;
  final DateTime? targetDate;
  final String? category;
  final String? color;

  const ProjectFormData({
    required this.title,
    this.description,
    this.goalId,
    this.targetDate,
    this.category,
    this.color,
  });
}

/// The project create/edit form sheet.
class _ProjectForm extends ConsumerStatefulWidget {
  final Project? project;

  const _ProjectForm({this.project});

  @override
  ConsumerState<_ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends ConsumerState<_ProjectForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _goalId;
  DateTime? _targetDate;
  String? _category;
  String? _color;

  @override
  void initState() {
    super.initState();
    final project = widget.project;
    if (project != null) {
      _titleController.text = project.title;
      _descriptionController.text = project.description ?? '';
      _goalId = project.goalId;
      _targetDate = project.targetDate;
      _category = project.category;
      _color = project.color;
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
    final isEditing = widget.project != null;
    final goals = ref.watch(goalsProvider);
    final goalTitles = {for (final g in goals) g.id: g.title};
    final accent = AppColors.accent(theme.colorScheme,
        AppColors.accentLiveDeep, AppColors.accentLive);

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
                        isEditing ? 'Edit Project' : 'New Project',
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
                      labelText: 'Project Title',
                      hintText: 'e.g., Flutter App Rewrite',
                      prefixIcon: Icon(LucideIcons.folder),
                    ),
                    maxLength: 120,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Please enter a project title'
                            : null,
                    textInputAction: TextInputAction.next,
                    autofocus: !isEditing,
                  ),
                  const SizedBox(height: AppSpacingTokens.md),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'What is this project for?',
                      prefixIcon: Icon(LucideIcons.fileText),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 2,
                    maxLength: 400,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: AppSpacingTokens.md),
                  _goalSelector(goalTitles, accent),
                  const SizedBox(height: AppSpacingTokens.md),
                  _targetDateSelector(accent),
                  const SizedBox(height: AppSpacingTokens.md),
                  _categorySelector(accent),
                  const SizedBox(height: AppSpacingTokens.lg),
                  GlowButton(
                    label: isEditing ? 'Save Changes' : 'Add Project',
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

  Widget _goalSelector(Map<String, String> goalTitles, Color accent) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Goal (optional)',
          style: AppTextStyles.labelLarge
              .copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacingTokens.sm),
        Wrap(
          spacing: AppSpacingTokens.sm,
          runSpacing: AppSpacingTokens.sm,
          children: [
            GlassPill(
              label: 'No goal',
              icon: LucideIcons.target,
              selected: _goalId == null,
              accent: accent,
              onTap: () => setState(() => _goalId = null),
            ),
            for (final entry in goalTitles.entries)
              GlassPill(
                label: entry.value,
                icon: LucideIcons.target,
                selected: _goalId == entry.key,
                accent: accent,
                onTap: () => setState(() => _goalId = entry.key),
              ),
          ],
        ),
        if (goalTitles.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacingTokens.xs),
            child: Text(
              'No goals yet. Create one on the Goals screen to link projects.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
      ],
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(ProjectFormData(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      goalId: _goalId,
      targetDate: _targetDate,
      category: _category,
      color: _color,
    ));
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}