import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/item_status.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../focus/domain/entities/focus_session.dart';
import '../../../goals/domain/entities/goal.dart';
import '../../../habits/domain/entities/habit.dart';
import '../../../habits/domain/entities/habit_completion.dart';
import '../../../projects/domain/entities/project.dart';
import '../../../recurring/domain/recurring_streak.dart';
import '../../../recurring/domain/task_streak.dart';
import '../../../tasks/domain/entities/task.dart';
import '../../../tasks/domain/value_objects/task_schedule.dart';
import '../../../tasks/domain/value_objects/task_status.dart';
import '../progress_metrics.dart';

/// The one place derived progress is computed.
///
/// Nothing here is stored: every number is recomputed from the task list, the
/// completion log and the focus sessions, so there is no second copy of the
/// truth to fall out of date. The methods take plain collections rather than
/// repositories, which keeps them pure and makes the definitions testable
/// without a database.
class ProgressService {
  const ProgressService();

  /// The bucket a focus session with no project name falls into.
  static const String uncategorizedFocus = 'Uncategorized';

  /// Mean of the non-null [ratings]; zero when there are none.
  double averageRating(Iterable<int?> ratings) {
    var sum = 0;
    var count = 0;
    for (final rating in ratings) {
      if (rating == null) continue;
      sum += rating;
      count++;
    }
    return count == 0 ? 0 : sum / count;
  }

  /// How many times each [labels] entry was reported.
  ///
  /// Null and out-of-range ratings are dropped rather than clamped: a 6 on a
  /// five-point scale is a bad reading, not the top of the scale.
  Map<String, int> ratingDistribution(
    Iterable<int?> ratings,
    List<String> labels,
  ) {
    final distribution = <String, int>{};
    for (final rating in ratings) {
      if (rating == null || rating < 1 || rating > labels.length) continue;
      final label = labels[rating - 1];
      distribution[label] = (distribution[label] ?? 0) + 1;
    }
    return distribution;
  }

  /// Mood readings bucketed by [AppConstants.moodLevels].
  Map<String, int> moodDistribution(Iterable<int?> ratings) =>
      ratingDistribution(ratings, AppConstants.moodLevels);

  /// Energy readings bucketed by [AppConstants.energyLevels].
  Map<String, int> energyDistribution(Iterable<int?> ratings) =>
      ratingDistribution(ratings, AppConstants.energyLevels);

  /// Total work minutes across [sessions], and the split by project name.
  FocusBreakdown focusBreakdown(List<FocusSession> sessions) {
    var totalMinutes = 0;
    final byCategory = <String, int>{};
    for (final session in sessions) {
      totalMinutes += session.totalWorkMinutes;
      final category = session.projectName ?? uncategorizedFocus;
      byCategory[category] =
          (byCategory[category] ?? 0) + session.totalWorkMinutes;
    }
    return FocusBreakdown(totalMinutes: totalMinutes, byCategory: byCategory);
  }

  /// Lifetime completion counters per habit category, from the habits themselves.
  Map<String, int> habitCompletionsByCategory(List<Habit> habits) {
    final byCategory = <String, int>{};
    for (final habit in habits) {
      byCategory[habit.category] =
          (byCategory[habit.category] ?? 0) + habit.totalCompletions;
    }
    return byCategory;
  }

  /// Completion counts per habit category, counted from the log.
  ///
  /// Unlike [habitCompletionsByCategory] this sums each row's own `count`, so a
  /// `targetCount: 3` habit contributes three for the day it was hit - which is
  /// what a user looking at a date range expects to see.
  Map<String, int> habitCompletionsByCategoryFromLog(
    List<Habit> habits,
    List<HabitCompletion> completions,
  ) {
    final categoryByHabitId = <String, String>{};
    // Every category the habits know about is seeded at zero first, so a
    // category with no completions in the window reads as 0 rather than
    // vanishing - a chart that drops a category looks like the category was
    // deleted.
    final byCategory = <String, int>{};
    for (final habit in habits) {
      categoryByHabitId[habit.id] = habit.category;
      byCategory.putIfAbsent(habit.category, () => 0);
    }
    for (final completion in completions) {
      if (!completion.isHabitCompletion) continue;
      final category = categoryByHabitId[completion.ownerId];
      if (category == null) continue;
      byCategory[category] = (byCategory[category] ?? 0) + completion.count;
    }
    return byCategory;
  }

  /// Current streak length per habit category.
  Map<String, int> habitStreaksByCategory(List<Habit> habits) {
    final byCategory = <String, int>{};
    for (final habit in habits) {
      byCategory[habit.category] =
          (byCategory[habit.category] ?? 0) + habit.currentStreak;
    }
    return byCategory;
  }

  /// Current streak length per recurring Task category, read from the canonical
  /// day-consecutive rule in [RecurringStreak].
  ///
  /// Tasks with no category are skipped rather than bucketed under a placeholder:
  /// an uncategorised Task has nowhere in a category chart to go, and inventing
  /// a bucket would make the chart look like the category exists.
  ///
  /// There is deliberately no `now` parameter. A day-consecutive streak is the
  /// run ending at the most recent completion, not the run ending today, so
  /// unlike the scheduled-consecutive reading it replaced it needs no clock — and
  /// a read path that cannot go stale between call sites cannot be tested with a
  /// hidden `DateTime.now()` in the middle of it.
  Map<String, int> taskStreaksByCategory(
    List<Task> tasks,
    List<HabitCompletion> completions,
  ) {
    final categoryByTaskId = <String, String>{};
    for (final task in tasks) {
      if (task.schedule is! Recurring) continue;
      final category = task.category;
      if (category != null) categoryByTaskId[task.id] = category;
    }

    final byCategory = <String, int>{};
    for (final snapshot
        in computeTaskStreaks(tasks: tasks, completions: completions)) {
      final category = categoryByTaskId[snapshot.taskId];
      if (category == null) continue;
      byCategory[category] =
          (byCategory[category] ?? 0) + snapshot.currentStreak;
    }
    return byCategory;
  }

  /// Current streak length per category across **all** recurring work, legacy and
  /// migrated together.
  ///
  /// This is the rule the whole app reads through, and it exists because a
  /// migrated habit is representable twice:
  ///
  /// - a habit with `taskId == null` is read through its stored counter, because
  ///   the legacy write path is still the only thing maintaining it;
  /// - a habit with `taskId != null` contributes **nothing** here. Its Task's
  ///   occurrence log already contains a copy of every one of its legacy rows, so
  ///   reading its frozen counters as well would count the same days twice.
  ///
  /// Independently created recurring Tasks count too, under their own category —
  /// they are recurring work with no legacy twin, and there is nothing to
  /// double-count them against.
  ///
  /// The migration copies `category` onto the Task, so a migrated habit's streak
  /// lands in the same bucket it always did.
  Map<String, int> recurringStreaksByCategory({
    required List<Habit> habits,
    required List<Task> tasks,
    required List<HabitCompletion> completions,
  }) {
    final byCategory = <String, int>{};
    for (final habit in habits) {
      if (habit.taskId != null) continue;
      byCategory[habit.category] =
          (byCategory[habit.category] ?? 0) + habit.currentStreak;
    }
    addAll(byCategory, taskStreaksByCategory(tasks, completions));
    return byCategory;
  }

  /// Lifetime completion counts per category across legacy and migrated
  /// recurring work, under the same ownership rule as
  /// [recurringStreaksByCategory].
  ///
  /// Un-migrated habits contribute their stored lifetime counter and recurring
  /// Tasks contribute their occurrence rows. Categories are seeded at zero
  /// first, so a category with no completions reads as 0 rather than vanishing
  /// from a chart, which looks like the category was deleted.
  Map<String, int> recurringCompletionsByCategory({
    required List<Habit> habits,
    required List<Task> tasks,
    required List<HabitCompletion> completions,
  }) {
    final byCategory = <String, int>{};
    for (final habit in habits) {
      byCategory.putIfAbsent(habit.category, () => 0);
      if (habit.taskId != null) continue;
      byCategory[habit.category] =
          (byCategory[habit.category] ?? 0) + habit.totalCompletions;
    }
    addAll(byCategory, taskCompletionsByCategoryFromLog(tasks, completions));
    return byCategory;
  }

  /// Completion counts per category within a window, under the same ownership
  /// rule as [recurringCompletionsByCategory].
  ///
  /// Every habit is counted from the log rather than from its stored counter,
  /// because a counter is lifetime-only and this is a window: an un-migrated
  /// habit's rows count, and a migrated habit's Task rows count in place of the
  /// legacy rows they were copied from. Each row contributes its own `count`, so
  /// a `targetCount: 3` habit reports three for the day it was hit.
  ///
  /// A null bound means unbounded on that side.
  Map<String, int> recurringCompletionsByCategoryFromLog({
    required List<Habit> habits,
    required List<HabitCompletion> completions,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final migratedHabitIds = <String>{};
    final categoryByTaskId = <String, String>{};
    for (final habit in habits) {
      final taskId = habit.taskId;
      if (taskId != null) {
        migratedHabitIds.add(habit.id);
        categoryByTaskId[taskId] = habit.category;
      }
    }

    // Every category the habits know about is seeded at zero first, so a
    // category with no completions in the window reads as 0 rather than
    // vanishing - a chart that drops a category looks like the category was
    // deleted.
    final byCategory = <String, int>{};
    final categoryByHabitId = <String, String>{};
    for (final habit in habits) {
      categoryByHabitId[habit.id] = habit.category;
      byCategory.putIfAbsent(habit.category, () => 0);
    }

    // Both bounds are whole days. A range picker hands back midnight on the
    // selected dates, and comparing that against a 09:00 completion would drop
    // the final day of the range - the same days the repository's own range
    // query and the heatmap window both include.
    final from = startDate?.startOfDay;
    final to = endDate?.endOfDay;

    for (final completion in completions) {
      final at = completion.completedAt;
      if (from != null && at.isBefore(from)) continue;
      if (to != null && at.isAfter(to)) continue;

      final String? category;
      if (completion.isHabitCompletion) {
        if (migratedHabitIds.contains(completion.ownerId)) continue;
        category = categoryByHabitId[completion.ownerId];
      } else if (completion.itemType == 'task') {
        category = categoryByTaskId[completion.itemId];
      } else {
        continue;
      }
      if (category == null) continue;

      byCategory[category] = (byCategory[category] ?? 0) + completion.count;
    }
    return byCategory;
  }

  /// Completion counts per calendar day across legacy and migrated recurring
  /// work, over the trailing [weeks] weeks — the habit heatmap's read path.
  ///
  /// Replaces one heatmap query per habit with one pass over the shared
  /// completion log, which matters because the log now holds two owners' rows.
  /// A migrated habit's legacy rows are skipped and its Task rows counted
  /// instead, for the reason in [recurringStreaksByCategory]. Recurring Tasks
  /// with no habit behind them are left out: this is the *habit* heatmap, and a
  /// standalone Task appearing in it would be a different question.
  ///
  /// The window matches `HabitRepository.getCompletionHeatmap` — the whole of
  /// the first day through the whole of the last — so swapping one read for the
  /// other does not shift a single cell.
  Map<DateTime, int> recurringCompletionHeatmap({
    required List<Habit> habits,
    required List<HabitCompletion> completions,
    int weeks = 12,
    DateTime? now,
  }) {
    final migratedHabitIds = <String>{};
    final migratedTaskIds = <String>{};
    for (final habit in habits) {
      final taskId = habit.taskId;
      if (taskId == null) continue;
      migratedHabitIds.add(habit.id);
      migratedTaskIds.add(taskId);
    }

    final endDate = now ?? AppClock.now();
    final startDate = RecurringStreak.startOfDay(
      endDate.subtract(Duration(days: weeks * 7)),
    );
    final lastMoment = endDate.endOfDay;

    final heatmap = <DateTime, int>{};
    for (final completion in completions) {
      if (!completion.completedAt.isAfter(startDate) &&
          !completion.completedAt.isAtSameMomentAs(startDate)) {
        continue;
      }
      if (completion.completedAt.isAfter(lastMoment)) continue;

      final String? owner;
      if (completion.isHabitCompletion) {
        if (migratedHabitIds.contains(completion.ownerId)) continue;
        owner = completion.ownerId;
      } else if (completion.itemType == 'task') {
        if (!migratedTaskIds.contains(completion.itemId)) continue;
        owner = completion.itemId;
      } else {
        continue;
      }
      if (owner == null) continue;

      final day = completion.completedAt.startOfDay;
      heatmap[day] = (heatmap[day] ?? 0) + completion.count;
    }
    return heatmap;
  }

  /// Merges [additions] into [target] in place, summing keys they share.
  static void addAll(Map<String, int> target, Map<String, int> additions) {
    additions.forEach((key, value) {
      target[key] = (target[key] ?? 0) + value;
    });
  }

  /// Task id to Habit id for every migrated habit in [habits].
  ///
  /// A migrated habit is written twice: legacy rows carry its own id, and the
  /// occurrence rows the write path now uses carry the Task's id. Every
  /// habit-scoped read needs to collapse those into one owner before it counts
  /// anything, and every one of them resolves it through this map rather than
  /// inventing its own rule — that is how the same habit cannot end up counted
  /// twice, or counted zero times, in two panels of the same screen.
  static Map<String, String> habitIdByTaskId(Iterable<Habit> habits) {
    final byTaskId = <String, String>{};
    for (final habit in habits) {
      final taskId = habit.taskId;
      if (taskId != null) byTaskId[taskId] = habit.id;
    }
    return byTaskId;
  }

  /// Which habit ids were completed on each day.
  ///
  /// Pass [taskIdToHabitId] — from [habitIdByTaskId] — to read a dataset that
  /// contains migrated habits. Their Task occurrence rows then count for the
  /// habit, and the legacy rows those rows were copied from are counted instead,
  /// so a migrated habit reports the same days it did before migration instead
  /// of reporting only its frozen legacy half.
  ///
  /// With no map, Task rows are skipped: a standalone recurring Task is not a
  /// habit day, and crediting one would report a habit completed by nobody.
  Map<DateTime, Set<String>> completedHabitIdsByDay(
    List<HabitCompletion> completions, [
    Map<String, String> taskIdToHabitId = const {},
  ]) {
    final byDay = <DateTime, Set<String>>{};
    for (final completion in completions) {
      final String? habitId;
      if (completion.isHabitCompletion) {
        habitId = completion.ownerId;
      } else if (completion.itemType == 'task') {
        habitId = taskIdToHabitId[completion.itemId];
      } else {
        continue;
      }
      if (habitId == null) continue;
      byDay
          .putIfAbsent(completion.completedAt.startOfDay, () => <String>{})
          .add(habitId);
    }
    return byDay;
  }

  /// Which recurring Task ids were completed on each day.
  Map<DateTime, Set<String>> completedTaskIdsByDay(
    List<HabitCompletion> completions,
  ) {
    final byDay = <DateTime, Set<String>>{};
    for (final completion in completions) {
      if (completion.itemType != 'task') continue;
      final taskId = completion.itemId;
      if (taskId == null) continue;
      byDay
          .putIfAbsent(completion.completedAt.startOfDay, () => <String>{})
          .add(taskId);
    }
    return byDay;
  }

  /// Share (0-100) of the habits due on [day] that were completed that day.
  ///
  /// Null when nothing was due: a day with no habits has no completion to
  /// report, and forcing it to 0% or 100% would drag a trend line with it.
  double? dayHabitCompletionPercent({
    required List<Habit> habits,
    required Map<DateTime, Set<String>> completedByDay,
    required DateTime day,
  }) {
    final date = day.startOfDay;
    final due = habits.where((h) => h.isDueOnDate(date)).toList();
    if (due.isEmpty) return null;

    final completed = completedByDay[date] ?? const <String>{};
    final completedDue = due.where((h) => completed.contains(h.id)).length;
    return completedDue / due.length * 100;
  }

  /// Share (0-100) of the recurring Tasks due on [day] that were completed that day.
  ///
  /// Null when nothing was due.
  double? dayTaskCompletionPercent({
    required List<Task> tasks,
    required Map<DateTime, Set<String>> completedByDay,
    required DateTime day,
  }) {
    final date = day.startOfDay;
    final now = DateTime.now();
    final due = tasks
        .where((t) => t.schedule is Recurring && t.isDueOn(date, now: now))
        .toList();
    if (due.isEmpty) return null;

    final completed = completedByDay[date] ?? const <String>{};
    final completedDue = due.where((t) => completed.contains(t.id)).length;
    return completedDue / due.length * 100;
  }

  /// Completion counts per Task category, counted from the occurrence log.
  ///
  /// Sums each row's `count` for recurring Tasks only.
  Map<String, int> taskCompletionsByCategoryFromLog(
    List<Task> tasks,
    List<HabitCompletion> completions,
  ) {
    final categoryByTaskId = <String, String>{};
    final byCategory = <String, int>{};
    for (final task in tasks) {
      if (task.schedule is! Recurring) continue;
      if (task.category != null) {
        categoryByTaskId[task.id] = task.category!;
        byCategory.putIfAbsent(task.category!, () => 0);
      }
    }
    for (final completion in completions) {
      if (completion.itemType != 'task') continue;
      final category = categoryByTaskId[completion.itemId];
      if (category == null) continue;
      byCategory[category] = (byCategory[category] ?? 0) + completion.count;
    }
    return byCategory;
  }

  /// Both of a project's progress measures, from the tasks and sessions that
  /// name it.
  ///
  /// Archived tasks and habits are excluded: an archived item is out of the
  /// user's sight, so counting it would move a progress number for something
  /// they can no longer act on.
  ///
  /// For migrated habits (taskId != null), completions come from the Task
  /// occurrence log (itemType='task'), not the Habit log.
  ProjectProgress projectProgress({
    required Project project,
    required List<Task> tasks,
    required List<FocusSession> sessions,
    List<Habit> habits = const [],
    List<HabitCompletion> completions = const [],
  }) {
    final projectTasks = _activeTasks(tasks)
        .where((task) => task.projectId == project.id)
        .toList();
    final (done, total, recurring) = _taskCompletion(projectTasks);

    final projectHabits = habits
        .where((h) => h.projectId == project.id && !h.isArchived)
        .toList();

    // Split habits: non-migrated use Habit log, migrated use Task log
    final nonMigratedHabits =
        projectHabits.where((h) => h.taskId == null).toList();
    final migratedHabits =
        projectHabits.where((h) => h.taskId != null).toList();

    final nonMigratedHabitIds = nonMigratedHabits.map((h) => h.id).toSet();
    final habitCompletions = completions
        .where((c) =>
            c.isHabitCompletion && nonMigratedHabitIds.contains(c.ownerId))
        .fold<int>(0, (sum, c) => sum + c.count);

    // Migrated habit completions come from Task log via their taskId
    final migratedTaskIds = migratedHabits.map((h) => h.taskId!).toSet();
    final migratedCompletions = completions
        .where(
            (c) => c.itemType == 'task' && migratedTaskIds.contains(c.itemId))
        .fold<int>(0, (sum, c) => sum + c.count);

    return ProjectProgress(
      doneTaskCount: done,
      totalTaskCount: total,
      recurringTaskCount: recurring,
      habitCount: projectHabits.length,
      habitCompletionCount: habitCompletions + migratedCompletions,
      focusMinutes: _focusMinutesIn(sessions, {project.id}),
      completionRatio: _ratio(done, total),
    );
  }

  /// A goal's progress, rolled up from its projects and their tasks.
  ///
  /// A task counts towards the goal when it names the goal directly or when it
  /// belongs to one of the goal's projects. Both routes are legitimate - a goal
  /// can hold work before it has any projects, and a project can add its own
  /// tasks - and treating either as the only valid route would silently drop
  /// the other's work.
  GoalProgress goalProgress({
    required Goal goal,
    required List<Project> projects,
    required List<Task> tasks,
    required List<FocusSession> sessions,
  }) {
    final goalProjects = projects.where((p) => p.goalId == goal.id).toList();
    final projectIds = goalProjects.map((p) => p.id).toSet();

    final goalTasks = _activeTasks(tasks)
        .where((task) =>
            task.goalId == goal.id || projectIds.contains(task.projectId))
        .toList();
    final (done, total, _) = _taskCompletion(goalTasks);

    return GoalProgress(
      projectCount: goalProjects.length,
      completedProjectCount:
          goalProjects.where((p) => p.status == ItemStatus.completed).length,
      doneTaskCount: done,
      totalTaskCount: total,
      focusMinutes: _focusMinutesIn(sessions, projectIds),
      completionRatio: _ratio(done, total),
    );
  }

  static List<Task> _activeTasks(List<Task> tasks) =>
      tasks.where((t) => t.status != TaskStatus.archived).toList();

  /// (done, finite total, recurring) for [tasks].
  ///
  /// Recurring work is deliberately outside the ratio. Its occurrences are
  /// virtual and recorded as completion rows, so the task itself is never
  /// "done" - counting it would leave a permanently unfinished item sitting at
  /// 0% in every project that adopts one.
  static (int, int, int) _taskCompletion(List<Task> tasks) {
    var done = 0;
    var total = 0;
    var recurring = 0;
    for (final task in tasks) {
      if (task.schedule is Recurring) {
        recurring++;
        continue;
      }
      total++;
      if (task.status == TaskStatus.done) done++;
    }
    return (done, total, recurring);
  }

  static double _ratio(int done, int total) => total == 0 ? 0 : done / total;

  static int _focusMinutesIn(
    List<FocusSession> sessions,
    Set<String> projectIds,
  ) {
    var minutes = 0;
    for (final session in sessions) {
      final projectId = session.projectId;
      if (projectId == null || !projectIds.contains(projectId)) continue;
      minutes += session.totalWorkMinutes;
    }
    return minutes;
  }
}

final progressServiceProvider = Provider<ProgressService>((ref) {
  return const ProgressService();
});
