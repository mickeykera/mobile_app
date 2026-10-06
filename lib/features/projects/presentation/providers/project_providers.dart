import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/item_status.dart';
import '../../data/repositories/project_repository_impl.dart';
import '../../domain/entities/project.dart';
import '../controllers/project_controller.dart';

final projectControllerProvider =
    StateNotifierProvider<ProjectController, ProjectState>((ref) {
  return ProjectController(ref.watch(projectRepositoryProvider));
});

/// Projects that are still in play: active and completed, archived excluded.
///
/// Archived projects stay in storage and are reachable through the repository -
/// they are just not something to file new work into, so keeping them out of
/// this list stops them being picked by mistake.
final projectsProvider = Provider<List<Project>>((ref) {
  return ref
      .watch(projectControllerProvider)
      .projects
      .where((p) => p.status != ItemStatus.archived)
      .toList();
});

/// Projects offered when filing a task, keyed by id.
///
/// A map rather than a list so the task form can resolve a title in one lookup
/// and cannot end up indexing two parallel lists out of step.
final projectTitlesProvider = Provider<Map<String, String>>((ref) {
  return {
    for (final project in ref.watch(projectsProvider))
      project.id: project.title,
  };
});
