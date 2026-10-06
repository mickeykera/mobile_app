import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../habits/presentation/providers/habit_providers.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/value_objects/task_schedule.dart';
import '../../domain/value_objects/task_status.dart';
import '../controllers/task_controller.dart';

/// The task repository, so every consumer shares one instance.
///
/// Built here rather than inline in the controller for the same reason as
/// `habitRepositoryProvider`: an inline construction means the Tasks screen and
/// the Today screen each hold a *second* in-memory cache built from the same
/// storage, and the two drift the moment one of them writes.
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepositoryImpl(ref.watch(databaseServiceProvider));
});

final taskControllerProvider =
    StateNotifierProvider<TaskController, TaskState>((ref) {
  return TaskController(
    ref.watch(taskRepositoryProvider),
    ref.watch(habitRepositoryProvider),
    cutover: ref.watch(cutoverWritePathProvider),
  );
});

/// Every task the controller is holding, archived ones excluded.
final tasksProvider = Provider<List<Task>>((ref) {
  return ref
      .watch(taskControllerProvider)
      .tasks
      .where((t) => t.status != TaskStatus.archived)
      .toList();
});

/// The Inbox: tasks with neither a project nor a goal.
final inboxTasksProvider = Provider<List<Task>>((ref) {
  return ref.watch(tasksProvider).where((t) => t.isInbox).toList();
});

/// Project ids that currently have at least one task, in first-appearance
/// order, so the Tasks screen only shows sections that have something in them.
final projectsWithTasksProvider = Provider<List<String>>((ref) {
  final ids = <String>[];
  for (final task in ref.watch(tasksProvider)) {
    final projectId = task.projectId;
    if (projectId != null && !ids.contains(projectId)) ids.add(projectId);
  }
  return ids;
});

final tasksForProjectProvider =
    Provider.family<List<Task>, String>((ref, projectId) {
  return ref
      .watch(tasksProvider)
      .where((t) => t.projectId == projectId)
      .toList();
});

/// Tasks due on [day] that are not archived.
///
/// Reads the clock here, at the edge, rather than inside the domain: the schedule
/// rules themselves take `now` as a parameter so they stay pure, and this is the
/// one place that decides what "now" means for the screen.
final tasksDueOnProvider = Provider.family<List<Task>, DateTime>((ref, day) {
  final now = AppClock.now();
  return ref
      .watch(tasksProvider)
      .where((t) => t.status != TaskStatus.done && t.isDueOn(day, now: now))
      .toList();
});

/// Share of the finite tasks in [tasks] that are done, in `0..1`.
///
/// Recurring tasks are left out of both sides of the ratio for the same reason
/// `ProgressService` leaves them out of a project's: a recurring task is never
/// `done`, so including it would pin the bar below 100% forever.
double finiteCompletionRatio(List<Task> tasks) {
  var done = 0;
  var total = 0;
  for (final task in tasks) {
    if (task.status == TaskStatus.archived) continue;
    if (task.schedule is Recurring) continue;
    total++;
    if (task.isComplete) done++;
  }
  return total == 0 ? 0 : done / total;
}

/// Whether [tasks] contains any finite task for the ratio to describe.
bool hasFiniteTasks(List<Task> tasks) => tasks.any(
      (t) => t.status != TaskStatus.archived && t.schedule is! Recurring,
    );

/// Section ordering for the Tasks screen: the Inbox first, then date-based sections
/// (Today, Upcoming, Overdue), then each project by the order its first task appears,
/// then anything filed only to a goal.
///
/// Pure so the screen and any test read the same grouping from one place.
List<TaskSection> taskSections(
  List<Task> tasks,
  Map<String, String> projectTitles, {
  DateTime? now,
}) {
  now ??= AppClock.now();
  final today = now.startOfDay;
  final sections = <TaskSection>[];

  // First, identify all tasks with a Once schedule (finite dated tasks)
  final onceTasks = tasks
      .where((t) => t.schedule is Once)
      .where((t) => !t.isComplete && t.status != TaskStatus.archived)
      .toList();

  // Date-based sections for Once tasks
  final todayTasks = onceTasks
      .where((t) => (t.schedule as Once).dueDate.startOfDay == today)
      .toList();
  if (todayTasks.isNotEmpty) {
    sections.add(TaskSection(
      inbox: false,
      title: 'Today',
      tasks: todayTasks,
      sectionType: TaskSectionType.today,
    ));
  }

  final upcomingTasks = onceTasks
      .where((t) => (t.schedule as Once).dueDate.isAfter(today))
      .toList();
  if (upcomingTasks.isNotEmpty) {
    sections.add(TaskSection(
      inbox: false,
      title: 'Upcoming',
      tasks: upcomingTasks,
      sectionType: TaskSectionType.upcoming,
    ));
  }

  final overdueTasks = onceTasks
      .where((t) => (t.schedule as Once).dueDate.isBefore(today))
      .toList();
  if (overdueTasks.isNotEmpty) {
    sections.add(TaskSection(
      inbox: false,
      title: 'Overdue',
      tasks: overdueTasks,
      sectionType: TaskSectionType.overdue,
    ));
  }

  // Track all task IDs that have been placed in date sections
  final dateSectionTaskIds = <String>{};
  dateSectionTaskIds.addAll(todayTasks.map((t) => t.id));
  dateSectionTaskIds.addAll(upcomingTasks.map((t) => t.id));
  dateSectionTaskIds.addAll(overdueTasks.map((t) => t.id));

  // 1. Inbox (no project, no goal, AND not in a date section)
  final inbox = tasks
      .where((t) => t.isInbox && !dateSectionTaskIds.contains(t.id))
      .toList();
  if (inbox.isNotEmpty) {
    sections.insert(0, TaskSection(inbox: true, title: 'Inbox', tasks: inbox));
  }

  // 2. Project sections (tasks with a project, excluding those already in date sections)
  for (final entry in projectTitles.entries) {
    final projectTasks = tasks
        .where((t) =>
            t.projectId == entry.key && !dateSectionTaskIds.contains(t.id))
        .toList();
    if (projectTasks.isEmpty) continue;
    sections.add(TaskSection(
      inbox: false,
      title: entry.value,
      projectId: entry.key,
      tasks: projectTasks,
    ));
  }

  // 3. Goal-only tasks (no project, but has goal, and not in date sections)
  final goalOnly = tasks
      .where((t) =>
          t.projectId == null &&
          t.goalId != null &&
          !dateSectionTaskIds.contains(t.id))
      .toList();
  if (goalOnly.isNotEmpty) {
    sections.add(TaskSection(
      inbox: false,
      title: 'By goal',
      goalId: goalOnly.first.goalId,
      tasks: goalOnly,
    ));
  }

  return sections;
}

/// The type of a task section, used for rendering and behavior.
enum TaskSectionType {
  /// Standard section (project, goal, inbox)
  standard,
  /// Today's tasks
  today,
  /// Upcoming tasks
  upcoming,
  /// Overdue tasks
  overdue,
}

/// One titled group of tasks on the Tasks screen.
class TaskSection {
  /// Whether this is the Inbox rather than a project or goal.
  final bool inbox;

  final String title;

  /// Null for the Inbox and for the goal section, which spans goals.
  final String? projectId;

  /// Set only by the goal section.
  final String? goalId;

  final List<Task> tasks;

  /// The type of this section for rendering/behavior.
  final TaskSectionType sectionType;

  const TaskSection({
    required this.inbox,
    required this.title,
    required this.tasks,
    this.projectId,
    this.goalId,
    this.sectionType = TaskSectionType.standard,
  });
}
