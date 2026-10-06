import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/text_styles.dart';
import '../../../../app/widgets/glow_button.dart';
import '../../../../app/widgets/pill_chip.dart';
import '../../../../core/constants/category_type.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../goals/presentation/providers/goal_providers.dart';
import '../../../projects/presentation/providers/project_providers.dart';
import '../../domain/entities/task.dart';
import '../../domain/value_objects/task_schedule.dart';
import '../controllers/task_controller.dart';

/// Opens the task sheet and applies whatever it returns.
///
/// The sheet returns the *edited shape* rather than writing itself, so the
/// controller stays the only thing that touches storage and the sheet stays
/// testable without a repository.
Future<void> showTaskFormSheet(
  BuildContext context,
  TaskController controller, {
  Task? task,
  String? initialProjectId,
}) async {
  final edited = await showModalBottomSheet<Task>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _TaskForm(
      task: task,
      initialProjectId: initialProjectId,
    ),
  );
  if (edited == null) return;

  final result = task == null
      ? await controller.createTask(
          title: edited.title,
          description: edited.description,
          schedule: edited.schedule,
          projectId: edited.projectId,
          goalId: edited.goalId,
          category: edited.category,
        )
      : await controller.updateTask(edited);

  if (result.isLeft && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.left?.userMessage ?? 'Could not save task'),
      ),
    );
  }
}

class _TaskForm extends ConsumerStatefulWidget {
  final Task? task;
  final String? initialProjectId;

  const _TaskForm({this.task, this.initialProjectId});

  @override
  ConsumerState<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<_TaskForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  /// No id means "no project", which is the Inbox. Not an empty string: a task
  /// with `projectId: ''` would fail `isInbox` and vanish from the Inbox while
  /// belonging to no project either.
  String? _projectId;

  /// The goal this task serves. Can be null even if projectId is set.
  String? _goalId;

  /// Category for the task (e.g., Mind, Body, Craft, Discipline).
  String? _category;

  /// `null` while the user has not chosen, so an untouched new task saves as
  /// `Unscheduled` rather than being silently dated to today.
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    if (task != null) {
      _titleController.text = task.title;
      _descriptionController.text = task.description ?? '';
      _projectId = task.projectId;
      _goalId = task.goalId;
      _category = task.category;
      final schedule = task.schedule;
      if (schedule is Once) _dueDate = schedule.dueDate;
    } else {
      _projectId = widget.initialProjectId;
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
    final isEditing = widget.task != null;
    final projectTitles = ref.watch(projectTitlesProvider);
    final accent = AppColors.accent(theme.colorScheme,
        AppColors.accentPrimaryDeep, AppColors.accentPrimaryDark);

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
                        isEditing ? 'Edit Task' : 'New Task',
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
                      labelText: 'Task Title',
                      hintText: 'e.g., Draft the quarterly plan',
                      prefixIcon: Icon(LucideIcons.type),
                    ),
                    maxLength: 120,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Please enter a task title'
                            : null,
                    textInputAction: TextInputAction.next,
                    autofocus: !isEditing,
                  ),
                  const SizedBox(height: AppSpacingTokens.md),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'Anything worth remembering',
                      prefixIcon: Icon(LucideIcons.fileText),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 2,
                    maxLength: 400,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: AppSpacingTokens.md),
                  _scheduleSelector(accent),
                  const SizedBox(height: AppSpacingTokens.md),
                  _projectSelector(projectTitles, accent),
                  const SizedBox(height: AppSpacingTokens.md),
                  _goalSelector(accent),
                  const SizedBox(height: AppSpacingTokens.md),
                  _categorySelector(accent),
                  const SizedBox(height: AppSpacingTokens.lg),
                  GlowButton(
                    label: isEditing ? 'Save Changes' : 'Add Task',
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

  /// When the task is due: never, today, or a picked date.
  ///
  /// Only `Once` and `Unscheduled` are offered. A recurring option belongs to
  /// the habit flow, which owns streaks and `targetCount`; putting it here
  /// would create tasks the completion log cannot yet count.
  ///
  /// A recurring Task is a migrated habit, and this form has no way to express
  /// its recurrence - so it shows the schedule read-only instead of letting a
  /// save silently rewrite a `Recurring` task into a one-off. Changing
  /// recurrence stays in the habit flow (Stage L2 §7).
  Widget _scheduleSelector(Color accent) {
    final theme = Theme.of(context);
    final recurring = _baseRecurringSchedule;
    if (recurring != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'When',
            style: AppTextStyles.labelLarge
                .copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacingTokens.sm),
          GlassPill(
            label: 'Recurring · ${recurring.rule.frequency}',
            icon: LucideIcons.repeat,
            selected: true,
            accent: accent,
          ),
        ],
      );
    }

    final today = _startOfDay(AppClock.now());
    final isToday = _dueDate != null && _isSameDay(_dueDate!, today);
    final isCustom =
        _dueDate != null && !isToday && !_isSameDay(_dueDate!, today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'When',
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
              icon: LucideIcons.inbox,
              selected: _dueDate == null,
              accent: accent,
              onTap: () => setState(() => _dueDate = null),
            ),
            GlassPill(
              label: 'Today',
              icon: LucideIcons.sun,
              selected: isToday,
              accent: accent,
              onTap: () => setState(() => _dueDate = today),
            ),
            GlassPill(
              label: _dueDate == null
                  ? 'Pick a date'
                  : '${_dueDate!.day}/${_dueDate!.month}',
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
    final now = AppClock.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    setState(() => _dueDate = _startOfDay(picked));
  }

  /// Which project owns the task. "Inbox" is the explicit no-project choice.
  Widget _projectSelector(Map<String, String> projectTitles, Color accent) {
    final theme = Theme.of(context);
    final ids = projectTitles.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Project',
          style: AppTextStyles.labelLarge
              .copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacingTokens.sm),
        Wrap(
          spacing: AppSpacingTokens.sm,
          runSpacing: AppSpacingTokens.sm,
          children: [
            GlassPill(
              label: 'Inbox',
              icon: LucideIcons.inbox,
              selected: _projectId == null,
              accent: accent,
              onTap: () => setState(() => _projectId = null),
            ),
            for (final id in ids)
              GlassPill(
                label: projectTitles[id] ?? 'Unknown project',
                icon: LucideIcons.folder,
                selected: _projectId == id,
                accent: accent,
                onTap: () => setState(() => _projectId = id),
              ),
          ],
        ),
        if (ids.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacingTokens.xs),
            child: Text(
              'No projects yet. This task stays in your Inbox until you file it.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  /// Which goal this task serves. Optional.
  Widget _goalSelector(Color accent) {
    final theme = Theme.of(context);
    final goals = ref.watch(goalsProvider);
    final goalTitles = {for (final g in goals) g.id: g.title};

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
              'No goals yet. Create one on the Goals screen to link tasks.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  /// Category for the task (e.g., Mind, Body, Craft, Discipline).
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

    final base = widget.task;
    // A recurring Task round-trips its existing schedule untouched: this form
    // cannot express recurrence, so rebuilding the schedule from the Once/
    // Unscheduled selector would destroy it (Stage L2 §7). The selector is
    // shown read-only for these tasks, so `_dueDate` carries no meaning here.
    final recurring = _baseRecurringSchedule;
    final dueDate = _dueDate;
    // The schedule is the single source of truth for "when": the entity never
    // carries a separate dueDate column that could disagree with it.
    final schedule = recurring ??
        (dueDate == null ? const Unscheduled() : Once(_startOfDay(dueDate)));

    final task = base?.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          schedule: schedule,
          projectId: _projectId,
          goalId: _goalId,
          category: _category,
          updatedAt: AppClock.now(),
        ) ??
        Task.create(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          schedule: schedule,
          projectId: _projectId,
          goalId: _goalId,
          category: _category,
        );

    Navigator.of(context).pop(task);
  }

  /// The existing schedule when editing a recurring task, else null.
  Recurring? get _baseRecurringSchedule {
    final schedule = widget.task?.schedule;
    return schedule is Recurring ? schedule : null;
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
