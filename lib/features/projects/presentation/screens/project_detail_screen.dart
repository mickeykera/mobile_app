import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/text_styles.dart';
import '../../../../app/widgets/app_empty_state.dart';
import '../../../../app/widgets/glass_card.dart';
import '../../../../app/widgets/progress_ring.dart';
import '../../../../core/constants/item_status.dart';
import '../../../progress/domain/progress_metrics.dart';
import '../../../progress/presentation/providers/progress_providers.dart';
import '../../../tasks/domain/entities/task.dart';
import '../../../tasks/presentation/providers/task_providers.dart';
import '../providers/project_providers.dart';

/// One project's body of work, with both of its progress measures.
///
/// The two numbers are shown side by side and never blended. The ring answers
/// "is the work list shrinking"; the minutes answer "is this getting real
/// time". Either can move without the other, and a single score would hide that
/// - which is the whole reason the dual metric exists.
class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref
        .watch(projectControllerProvider)
        .projects
        .where((p) => p.id == projectId)
        .firstOrNull;

    if (project == null) {
      return const Scaffold(
        body: SafeArea(
          child: AppEmptyState(
            icon: LucideIcons.folderX,
            title: 'Project not found',
            message: 'It may have been deleted on another screen.',
          ),
        ),
      );
    }

    final progress = ref.watch(projectProgressProvider(projectId));
    final tasks = ref.watch(tasksForProjectProvider(projectId));
    final scheme = Theme.of(context).colorScheme;
    final accent = AppColors.accent(
        scheme, AppColors.accentLiveDeep, AppColors.accentLive);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          _Header(
            title: project.title,
            subtitle: project.description,
            status: project.status,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacingTokens.lg),
              child: _DualMetrics(progress: progress, accent: accent),
            ),
          ),
          if (tasks.isEmpty)
            const SliverToBoxAdapter(child: _NoTasks())
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacingTokens.lg, 0,
                    AppSpacingTokens.lg, AppSpacingTokens.sm),
                child: Text(
                  'TASKS',
                  style: AppTextStyles.overline
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacingTokens.lg),
                child: Column(
                  children: [
                    for (final task in tasks)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacingTokens.sm),
                        child: _TaskLine(task: task),
                      ),
                  ],
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacingTokens.lg),
              child: _Lifecycle(projectId: projectId),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String? subtitle;
  final ItemStatus status;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.status,
  });

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
            Text('PROJECT',
                style: AppTextStyles.overline
                    .copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacingTokens.xs),
            Text(title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.displaySmall
                    .copyWith(color: scheme.onSurface)),
            if (subtitle != null && subtitle!.trim().isNotEmpty)
              Text(
                subtitle!.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: AppSpacingTokens.sm),
            _StatusPill(status: status),
          ],
        ),
      ).animate().fadeIn(duration: AppAnimationTokens.slow),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final ItemStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      ItemStatus.active => ('Active', scheme.onSurfaceVariant),
      ItemStatus.completed => (
          'Completed',
          AppColors.accent(
              scheme, AppColors.accentPrimaryDeep, AppColors.accentPrimary)
        ),
      ItemStatus.archived => ('Archived', scheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacingTokens.sm, vertical: AppSpacingTokens.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadiusTokens.full),
      ),
      child:
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }
}

/// The two metrics, deliberately un-blended.
class _DualMetrics extends StatelessWidget {
  final ProjectProgress progress;
  final Color accent;

  const _DualMetrics({required this.progress, required this.accent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // A project with only recurring work has no finite ratio to show. A
          // 0% ring there would read as total failure, so the ring is replaced
          // by the count and the wording changes instead.
          if (progress.hasFiniteTasks)
            ProgressRing(
              value: progress.completionRatio,
              size: 76,
              color: accent,
              child: Text(
                '${progress.doneTaskCount}/${progress.totalTaskCount}',
                style: AppTextStyles.metricMedium
                    .copyWith(color: scheme.onSurface),
              ),
            )
          else
            Icon(LucideIcons.inbox, size: 40, color: accent),
          const SizedBox(width: AppSpacingTokens.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progress.hasFiniteTasks
                      ? 'Tasks complete'
                      : 'No finite tasks yet',
                  style: AppTextStyles.titleSmall
                      .copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: AppSpacingTokens.xs),
                _MetricLine(
                  icon: LucideIcons.clock,
                  label: '${progress.focusMinutes} min focused',
                  color: scheme.onSurfaceVariant,
                ),
                if (progress.recurringTaskCount > 0)
                  _MetricLine(
                    icon: LucideIcons.repeat,
                    label:
                        '${progress.recurringTaskCount} recurring, not counted',
                    color: scheme.onSurfaceVariant,
                  ),
                if (progress.habitCount > 0)
                  _MetricLine(
                    icon: LucideIcons.target,
                    label: '${progress.habitCount} habits attached',
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetricLine({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacingTokens.xs),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacingTokens.xs),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

/// A read-only task line.
///
/// Ticking happens on the Tasks screen, which owns the write path. This screen
/// shows the shape of the work without offering a second way to change it, so
/// the two can never disagree about what is done.
class _TaskLine extends StatelessWidget {
  final Task task;

  const _TaskLine({required this.task});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacingTokens.md,
        vertical: AppSpacingTokens.sm,
      ),
      child: Row(
        children: [
          Icon(
            task.isComplete ? LucideIcons.circleCheck : LucideIcons.circle,
            size: 18,
            color: task.isComplete ? accent(scheme) : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacingTokens.md),
          Expanded(
            child: Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.titleSmall.copyWith(
                color: scheme.onSurface,
                decoration: task.isComplete ? TextDecoration.lineThrough : null,
                decorationColor: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color accent(ColorScheme scheme) => AppColors.accent(
      scheme, AppColors.accentPrimaryDeep, AppColors.accentPrimary);
}

class _NoTasks extends StatelessWidget {
  const _NoTasks();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacingTokens.lg),
      child: AppEmptyState(
        icon: LucideIcons.listTodo,
        title: 'No tasks in this project',
        message: 'Add one from the Tasks screen and file it here.',
      ),
    );
  }
}

/// The `active -> completed -> archived` transitions, as plain buttons.
///
/// Not a menu: there are only ever two or three options, they are the reason
/// this screen exists, and a labelled button states its consequence rather than
/// making the user guess from an icon.
class _Lifecycle extends ConsumerWidget {
  final String projectId;

  const _Lifecycle({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref
        .watch(projectControllerProvider)
        .projects
        .where((p) => p.id == projectId)
        .firstOrNull;
    if (project == null) return const SizedBox.shrink();

    final controller = ref.read(projectControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (project.status == ItemStatus.active)
          _LifecycleAction(
            label: 'Mark complete',
            icon: LucideIcons.circleCheck,
            onTap: () => controller.setStatus(projectId, ItemStatus.completed),
          ),
        if (project.status == ItemStatus.completed) ...[
          _LifecycleAction(
            label: 'Reopen',
            icon: LucideIcons.rotateCcw,
            onTap: () => controller.setStatus(projectId, ItemStatus.active),
          ),
          const SizedBox(height: AppSpacingTokens.sm),
          _LifecycleAction(
            label: 'Archive',
            icon: LucideIcons.archive,
            onTap: () => controller.setStatus(projectId, ItemStatus.archived),
          ),
        ],
        if (project.status == ItemStatus.archived)
          _LifecycleAction(
            label: 'Unarchive',
            icon: LucideIcons.archiveRestore,
            onTap: () => controller.setStatus(projectId, ItemStatus.active),
          ),
      ],
    );
  }
}

class _LifecycleAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _LifecycleAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacingTokens.md,
        vertical: AppSpacingTokens.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurface),
          const SizedBox(width: AppSpacingTokens.md),
          Text(label,
              style:
                  AppTextStyles.titleSmall.copyWith(color: scheme.onSurface)),
        ],
      ),
    );
  }
}
