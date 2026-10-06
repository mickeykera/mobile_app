import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../focus/domain/entities/focus_session.dart';
import '../../../focus/presentation/controllers/focus_controller.dart';
import '../../../goals/presentation/providers/goal_providers.dart';
import '../../../habits/presentation/providers/habit_providers.dart';
import '../../../projects/domain/entities/project.dart';
import '../../../projects/presentation/providers/project_providers.dart';
import '../../../tasks/presentation/providers/task_providers.dart';
import '../../domain/progress_metrics.dart';
import '../../domain/services/progress_service.dart';

/// Wires [ProgressService] to the controllers so a screen can ask one question
/// and get both metrics back.
///
/// Every number here is computed on read from the task list and the focus
/// sessions. Nothing is cached and nothing is persisted, so the figure on screen
/// cannot drift from the data behind it - there is no second copy to fall out of
/// date.

List<FocusSession> _sessions(Ref ref) =>
    ref.watch(focusControllerProvider).recentSessions;

/// Both of [projectId]'s progress measures.
final projectProgressProvider =
    Provider.family<ProjectProgress, String>((ref, projectId) {
  final project = ref
      .watch(projectControllerProvider)
      .projects
      .where((p) => p.id == projectId)
      .firstOrNull;
  if (project == null) return const ProjectProgress();

  return ref.watch(progressServiceProvider).projectProgress(
    project: project,
    tasks: ref.watch(tasksProvider),
    sessions: _sessions(ref),
    habits: ref.watch(habitsProvider),
    // Deliberately empty rather than "today's completions". The habit
    // completion count means nothing without a stated range, and borrowing
    // the controller's single-day slice would report a lifetime figure as if
    // it were today's. `habitCount` still comes through above; the ranged
    // count is left for the analytics work.
    completions: const [],
  );
});

/// [goalId]'s progress, rolled up from its projects and the tasks naming it.
final goalProgressProvider =
    Provider.family<GoalProgress, String>((ref, goalId) {
  final goal = ref
      .watch(goalControllerProvider)
      .goals
      .where((g) => g.id == goalId)
      .firstOrNull;
  if (goal == null) return const GoalProgress();

  return ref.watch(progressServiceProvider).goalProgress(
        goal: goal,
        projects: ref.watch(projectsProvider),
        tasks: ref.watch(tasksProvider),
        sessions: _sessions(ref),
      );
});

/// Projects serving [goalId].
final projectsForGoalProvider =
    Provider.family<List<Project>, String>((ref, goalId) {
  return ref.watch(projectsProvider).where((p) => p.goalId == goalId).toList();
});
