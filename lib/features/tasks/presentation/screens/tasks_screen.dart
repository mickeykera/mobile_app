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
import '../../../../app/widgets/pressable.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../projects/presentation/providers/project_providers.dart';
import '../../domain/entities/task.dart';
import '../../domain/value_objects/task_schedule.dart';
import '../../domain/value_objects/task_status.dart';
import '../controllers/task_controller.dart';
import '../providers/task_providers.dart';
import '../widgets/task_form.dart';
import '../../../recurring/presentation/providers/recurring_providers.dart';

/// The work item list: everything unfiled, then everything filed.
///
/// Sections are built by [taskSections] rather than by filtering inside the
/// widget tree, so "what is in the Inbox" is answered in one place that a test
/// can call directly. The Inbox is not a stored list - it is exactly the tasks
/// with no project and no goal - so filing a task makes it disappear from the
/// top section with no extra bookkeeping.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final accent = AppColors.accent(
        scheme, AppColors.accentPrimaryDeep, AppColors.accentPrimaryDark);

    final tasks =
        state.tasks.where((t) => t.status != TaskStatus.archived).toList();
    final sections = taskSections(tasks, ref.watch(projectTitlesProvider));

    final openTasks = tasks.where((t) => !t.isComplete).length;
    final doneTasks = tasks.length - openTasks;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          _Header(
            open: openTasks,
            done: doneTasks,
            isLoading: state.isLoading,
          ),
          if (state.error != null)
            SliverToBoxAdapter(child: _ErrorBanner(message: state.error!)),
          if (sections.isEmpty && !state.isLoading) const _TasksEmptyState(),
          for (final section in sections) ...[
            _SectionHeader(
              label: section.title,
              count: section.tasks.length,
              doneCount: section.tasks.where((t) => t.isComplete).length,
              accent: accent,
              sectionType: section.sectionType,
              onAdd: _sectionOnAdd(context, ref, section),
            ),
            _TaskList(tasks: section.tasks, accent: accent),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      floatingActionButton: GlowButton(
        label: 'New Task',
        icon: LucideIcons.plus,
        accent: accent,
        height: 52,
        onPressed: () => showTaskFormSheet(
          context,
          ref.read(taskControllerProvider.notifier),
        ),
      ),
    );
  }

  VoidCallback? _sectionOnAdd(
      BuildContext context, WidgetRef ref, TaskSection section) {
    // Date sections (Today, Upcoming, Overdue) don't have a project to prefill
    if (section.sectionType != TaskSectionType.standard) return null;
    if (section.projectId == null) return null;
    return () => showTaskFormSheet(
          context,
          ref.read(taskControllerProvider.notifier),
          initialProjectId: section.projectId!,
        );
  }
}

/// Title and the day's tally.
/// Entry point to the Goals screen.
///
/// Labelled rather than a bare icon: the icon that reads as "goal" is also the
/// one that reads as "achievement", and mislabelled drilldowns are how people
/// end up somewhere they did not mean to go.
class _GoalsLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextButton.icon(
      onPressed: () => context.push('/goals'),
      icon: const Icon(LucideIcons.target, size: 16),
      label: const Text('Goals'),
      style: TextButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        textStyle: AppTextStyles.labelMedium,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacingTokens.sm, vertical: AppSpacingTokens.xs),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int open;
  final int done;
  final bool isLoading;

  const _Header({
    required this.open,
    required this.done,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = AppClock.now();

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TASKS',
                          style: AppTextStyles.overline
                              .copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: AppSpacingTokens.xs),
                      Text(
                        'Tasks',
                        style: AppTextStyles.displaySmall
                            .copyWith(color: scheme.onSurface),
                      ),
                    ],
                  ),
                ),
                // Goals are the layer above projects, which are the layer above
                // tasks. One entry point here rather than an eighth tab: a tab
                // for every level of the hierarchy is what made the tab bar
                // unreadable in the first place.
                _GoalsLink(),
              ],
            ),
            Text(
              now.dayOfWeek,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacingTokens.md),
            // An empty account and a finished list are different states and get
            // different words; "0 open" alone reads as a failure when there was
            // never any work to do.
            Text(
              isLoading
                  ? 'Loading your tasks'
                  : open == 0 && done > 0
                      ? 'All $done done'
                      : open == 0
                          ? 'Nothing open'
                          : '$open open · $done done',
              style: AppTextStyles.titleSmall.copyWith(color: scheme.onSurface),
            ),
          ],
        ),
      ).animate().fadeIn(duration: AppAnimationTokens.slow),
    );
  }
}

/// Small caps divider above a group, with its counts and an add button.
class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final int doneCount;
  final Color accent;
  final TaskSectionType sectionType;
  final VoidCallback? onAdd;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.doneCount,
    required this.accent,
    this.sectionType = TaskSectionType.standard,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = _iconForSection(sectionType);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacingTokens.lg, 0, AppSpacingTokens.lg, AppSpacingTokens.sm),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacingTokens.xs),
            ],
            Flexible(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.overline
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: AppSpacingTokens.sm),
            Text('$doneCount/$count',
                style: AppTextStyles.labelSmall
                    .copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(width: AppSpacingTokens.sm),
            Expanded(
              child: Divider(color: AppColors.hairline(scheme), height: 1),
            ),
            if (onAdd != null)
              Pressable(
                onTap: onAdd,
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacingTokens.sm),
                  child: Icon(LucideIcons.plus, size: 18, color: accent),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static IconData? _iconForSection(TaskSectionType type) {
    switch (type) {
      case TaskSectionType.today:
        return LucideIcons.sun;
      case TaskSectionType.upcoming:
        return LucideIcons.calendar;
      case TaskSectionType.overdue:
        return LucideIcons.alertTriangle;
      default:
        return null;
    }
  }
}

class _TaskList extends StatelessWidget {
  final List<Task> tasks;
  final Color accent;

  const _TaskList({required this.tasks, required this.accent});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacingTokens.lg),
        child: Column(
          children: [
            for (final task in tasks)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacingTokens.sm),
                child: _TaskRow(task: task, accent: accent),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends ConsumerWidget {
  final Task task;
  final Color accent;

  const _TaskRow({required this.task, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(taskControllerProvider.notifier);
    final working = task.status == TaskStatus.doing;

    // Classification boundary: Recurring tasks use occurrence-based completion,
    // finite tasks (Once/Unscheduled) use status-based completion.
    final isRecurring = task.schedule is Recurring;
    final done = isRecurring ? false : task.isComplete;

    final List<Widget> children = [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadiusTokens.sm),
        ),
        child: Icon(_iconFor(task, done: done), size: 18, color: accent),
      ),
      const SizedBox(width: AppSpacingTokens.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.titleSmall.copyWith(
                color: scheme.onSurface,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: scheme.onSurfaceVariant,
              ),
            ),
            if (_subtitle(task) case final subtitle?)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    ];

    if (working) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(right: AppSpacingTokens.xs),
          child: Icon(LucideIcons.loader, size: 16, color: accent),
        ),
      );
    }

    children.add(_RowMenu(task: task));

    return Pressable(
      onTap: () => _toggleCompletion(controller, task, ref),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacingTokens.md,
          vertical: AppSpacingTokens.md,
        ),
        child: Row(children: children),
      ),
    );
  }

  /// Toggles completion based on task type.
  /// - Recurring: record/delete occurrence for today (no status change).
  /// - Finite (Once/Unscheduled): toggle status between todo/done.
  Future<void> _toggleCompletion(TaskController controller, Task task, WidgetRef ref) async {
    if (task.schedule is Recurring) {
      final now = AppClock.now();
      final completedToday = await ref.read(taskOccurrenceTodayProvider(task.id).future);
      if (completedToday) {
        await controller.deleteOccurrence(task.id, date: now);
      } else {
        await controller.recordOccurrence(task.id, date: now);
      }
    } else {
      controller.setStatus(
        task.id,
        task.isComplete ? TaskStatus.todo : TaskStatus.done,
      );
    }
  }

  /// The status line under the title.
  ///
  /// Only says something when there is something to say: a scheduled task gets a
  /// date, an in-flight one says so, and an unscheduled `todo` in the Inbox gets
  /// no line at all rather than a restatement of its own section.
  String? _subtitle(Task task) {
    if (task.status == TaskStatus.doing) return 'In progress';
    if (task.status == TaskStatus.done) return 'Done';

    final schedule = task.schedule;
    if (schedule is Unscheduled) return null;
    if (schedule is Once) return _relativeDay(schedule.dueDate);
    if (schedule is Recurring) return schedule.rule.frequency;
    return null;
  }

  /// "Today" / "Tomorrow" / "3 days ago" / a date, resolved against the clock
  /// here rather than inside the schedule so the wording lives with the widget.
  static String _relativeDay(DateTime date) {
    final now = AppClock.now().startOfDay;
    final target = date.startOfDay;
    final days = target.difference(now).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days == -1) return 'Yesterday';
    if (days < 0) return '${-days} days ago';
    if (days < 7) return 'In $days days';
    return '${target.day}/${target.month}/${target.year}';
  }

  static IconData _iconFor(Task task, {required bool done}) {
    if (done) return LucideIcons.circleCheck;
    if (task.schedule is Unscheduled) return LucideIcons.inbox;
    return LucideIcons.calendar;
  }
}

/// The secondary transitions: start, file, edit, archive.
///
/// `PopupMenuButton` rather than an icon-only button because the destructive
/// option (archive) needs a label - an unlabelled trash icon next to a
/// tap-the-row-to-complete target is too easy to hit by accident.
class _RowMenu extends ConsumerWidget {
  final Task task;

  const _RowMenu({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isRecurring = task.schedule is Recurring;

    return PopupMenuButton<_TaskAction>(
      tooltip: 'Task actions',
      icon: Icon(LucideIcons.ellipsisVertical,
          size: 18, color: scheme.onSurfaceVariant),
      onSelected: (action) => _run(ref, action),
      itemBuilder: (context) => [
        if (!isRecurring && !task.isComplete && task.status != TaskStatus.doing)
          const PopupMenuItem(
            value: _TaskAction.start,
            child: Text('Start working on it'),
          ),
        if (!isRecurring && task.isComplete)
          const PopupMenuItem(
            value: _TaskAction.reopen,
            child: Text('Reopen'),
          ),
        if (task.projectId != null)
          const PopupMenuItem(
            value: _TaskAction.unfile,
            child: Text('Move to Inbox'),
          ),
        const PopupMenuItem(
          value: _TaskAction.edit,
          child: Text('Edit'),
        ),
        const PopupMenuItem(
          value: _TaskAction.archive,
          child: Text('Archive'),
        ),
      ],
    );
  }

  Future<void> _run(WidgetRef ref, _TaskAction action) async {
    final controller = ref.read(taskControllerProvider.notifier);
    switch (action) {
      case _TaskAction.start:
        await controller.setStatus(task.id, TaskStatus.doing);
      case _TaskAction.reopen:
        await controller.setStatus(task.id, TaskStatus.todo);
      case _TaskAction.unfile:
        await controller.fileUnderProject(task.id, null);
      case _TaskAction.edit:
        await showTaskFormSheet(
          ref.context,
          controller,
          task: task,
        );
      case _TaskAction.archive:
        await controller.archiveTask(task.id);
    }
  }
}

enum _TaskAction { start, reopen, unfile, edit, archive }

class _TasksEmptyState extends ConsumerWidget {
  const _TasksEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacingTokens.lg),
        child: AppEmptyState(
          icon: LucideIcons.listChecks,
          title: 'No tasks yet',
          message:
              'Add one and it lands in your Inbox until you give it a project.',
          actionLabel: 'Add a task',
          onAction: () => showTaskFormSheet(
            context,
            ref.read(taskControllerProvider.notifier),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends ConsumerWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacingTokens.lg, 0, AppSpacingTokens.lg, AppSpacingTokens.sm),
      child: GlassCard(
        child: Row(
          children: [
            Icon(LucideIcons.triangleAlert, size: 18, color: scheme.error),
            const SizedBox(width: AppSpacingTokens.sm),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodySmall.copyWith(color: scheme.error),
              ),
            ),
            // A label that is not tappable would read as a broken button, so it
            // is a real Pressable that re-runs the load.
            Pressable(
              onTap: () => ref.read(taskControllerProvider.notifier).refresh(),
              child: Text(
                'Retry',
                style: AppTextStyles.labelMedium.copyWith(color: scheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
