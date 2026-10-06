import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/core/constants/app_constants.dart';
import 'package:ascend/core/constants/item_status.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/focus/domain/entities/focus_session.dart';
import 'package:ascend/features/goals/domain/entities/goal.dart';
import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/habits/domain/entities/habit_completion.dart';
import 'package:ascend/features/progress/domain/services/progress_service.dart';
import 'package:ascend/features/projects/domain/entities/project.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';

void main() {
  // 2025-06-11 is a Wednesday.
  final wednesday = DateTime(2025, 6, 11, 9);
  const service = ProgressService();

  setUp(() => AppClock.debugSetNow(() => wednesday));
  tearDown(AppClock.debugResetNow);

  HabitCompletion buildCompletion(String habitId,
          {DateTime? at, int count = 1}) =>
      HabitCompletion.create(
        habitId: habitId,
        count: count,
      ).copyWith(completedAt: at ?? wednesday);

  Habit buildHabit({
    required String id,
    String category = 'Mind',
    String frequency = 'Daily',
    int totalCompletions = 0,
    int currentStreak = 0,
    String? projectId,
    bool isArchived = false,
  }) =>
      Habit.create(
        title: 'Read',
        category: category,
        frequency: frequency,
        projectId: projectId,
      ).copyWith(
        id: id,
        totalCompletions: totalCompletions,
        currentStreak: currentStreak,
        isArchived: isArchived,
      );

  FocusSession buildSession({
    int workMinutes = 25,
    String? projectName,
    String? projectId,
  }) =>
      FocusSession.create(
        mode: 'Pomodoro',
        projectName: projectName,
        projectId: projectId,
      ).copyWith(totalWorkMinutes: workMinutes);

  group('ratings', () {
    test('the average skips missing readings', () {
      expect(service.averageRating([3, null, 4]), closeTo(3.5, 0.0001));
    });

    test('the average is zero when nothing was rated', () {
      expect(service.averageRating([null, null]), 0);
      expect(service.averageRating(const []), 0);
    });

    test('a distribution buckets by label and drops out-of-range readings', () {
      final distribution = service.moodDistribution([1, 1, 3, 9, null, 0]);

      expect(distribution['Very Low'], 2);
      expect(distribution['Neutral'], 1);
      expect(distribution['High'], isNull);
    });

    test('mood and energy use their own label sets', () {
      expect(service.moodDistribution([5]), {AppConstants.moodVeryHigh: 1});
      expect(service.energyDistribution([5]), {AppConstants.energyVeryHigh: 1});
    });
  });

  group('focus breakdown', () {
    test('totals minutes and splits them by project name', () {
      final breakdown = service.focusBreakdown([
        buildSession(workMinutes: 25, projectName: 'Launch'),
        buildSession(workMinutes: 15, projectName: 'Launch'),
        buildSession(workMinutes: 10, projectName: 'Reading'),
      ]);

      expect(breakdown.totalMinutes, 50);
      expect(breakdown.byCategory, {'Launch': 40, 'Reading': 10});
    });

    test('a session with no project name falls into one bucket', () {
      final breakdown = service.focusBreakdown([buildSession(workMinutes: 25)]);

      expect(breakdown.byCategory, {ProgressService.uncategorizedFocus: 25});
    });
  });

  group('habit rollups', () {
    test('lifetime completions and streaks group by category', () {
      final habits = [
        buildHabit(
            id: 'h1', category: 'Mind', totalCompletions: 5, currentStreak: 3),
        buildHabit(
            id: 'h2', category: 'Mind', totalCompletions: 2, currentStreak: 1),
        buildHabit(
            id: 'h3', category: 'Body', totalCompletions: 7, currentStreak: 4),
      ];

      expect(service.habitCompletionsByCategory(habits), {
        'Mind': 7,
        'Body': 7,
      });
      expect(service.habitStreaksByCategory(habits), {'Mind': 4, 'Body': 4});
    });

    test('log rollups sum each row count and keep empty categories at zero',
        () {
      final habits = [
        buildHabit(id: 'h1', category: 'Mind'),
        buildHabit(id: 'h2', category: 'Body'),
      ];

      final byCategory = service.habitCompletionsByCategoryFromLog(habits, [
        buildCompletion('h1', count: 3),
        buildCompletion('h1', count: 1),
        HabitCompletion.create(itemId: 'task_1', itemType: 'task')
            .copyWith(completedAt: wednesday),
      ]);

      expect(byCategory, {'Mind': 4, 'Body': 0});
    });

    test('completed ids are grouped per day and ignore task rows', () {
      final byDay = service.completedHabitIdsByDay([
        buildCompletion('h1', at: wednesday),
        buildCompletion('h2', at: wednesday),
        buildCompletion('h1', at: DateTime(2025, 6, 12, 21)),
        HabitCompletion.create(itemId: 'task_1', itemType: 'task')
            .copyWith(completedAt: wednesday),
      ]);

      expect(byDay[DateTime(2025, 6, 11)], {'h1', 'h2'});
      expect(byDay[DateTime(2025, 6, 12)], {'h1'});
    });

    test('a day reports the share of due habits that were completed', () {
      final habits = [
        buildHabit(id: 'h1'),
        buildHabit(id: 'h2'),
        buildHabit(id: 'h3', frequency: 'Weekends'),
      ];
      final completed = service.completedHabitIdsByDay([buildCompletion('h1')]);

      // h3 is a weekend habit, so Wednesday has two due habits and one was done.
      expect(
        service.dayHabitCompletionPercent(
          habits: habits,
          completedByDay: completed,
          day: wednesday,
        ),
        50,
      );
    });

    test('a day with nothing due has no completion share', () {
      final habits = [buildHabit(id: 'h1', frequency: 'Weekends')];

      expect(
        service.dayHabitCompletionPercent(
          habits: habits,
          completedByDay: const {},
          day: wednesday,
        ),
        isNull,
      );
    });
  });

  group('project progress', () {
    final project = Project.create(title: 'Ship v1');

    test('the ratio counts finite tasks only', () {
      final tasks = [
        Task.create(title: 'One', projectId: project.id, sortOrder: 0)
            .copyWith(status: TaskStatus.done),
        Task.create(title: 'Two', projectId: project.id, sortOrder: 1)
            .copyWith(status: TaskStatus.done),
        Task.create(title: 'Three', projectId: project.id, sortOrder: 2),
        // Recurring work is tracked as completion rows, not as task status, so
        // it must not sit in the ratio as a permanently unfinished item.
        Task.create(
          title: 'Weekly review',
          projectId: project.id,
          schedule: const Recurring(DailyRecurrence()),
          sortOrder: 3,
        ),
      ];

      final progress = service.projectProgress(
        project: project,
        tasks: tasks,
        sessions: const [],
      );

      expect(progress.doneTaskCount, 2);
      expect(progress.totalTaskCount, 3);
      expect(progress.recurringTaskCount, 1);
      expect(progress.completionRatio, closeTo(0.667, 0.001));
      expect(progress.hasFiniteTasks, isTrue);
    });

    test('archived and unfiled tasks are left out', () {
      final tasks = [
        Task.create(title: 'Kept', projectId: project.id)
            .copyWith(status: TaskStatus.done),
        Task.create(title: 'Archived', projectId: project.id)
            .copyWith(status: TaskStatus.archived),
        Task.create(title: 'Inbox'),
      ];

      final progress = service.projectProgress(
        project: project,
        tasks: tasks,
        sessions: const [],
      );

      expect(progress.totalTaskCount, 1);
      expect(progress.doneTaskCount, 1);
    });

    test('a project with only recurring work has no ratio to report', () {
      final progress = service.projectProgress(
        project: project,
        tasks: [
          Task.create(
              title: 'Daily',
              projectId: project.id,
              schedule: const Recurring(DailyRecurrence())),
        ],
        sessions: const [],
      );

      expect(progress.totalTaskCount, 0);
      expect(progress.recurringTaskCount, 1);
      expect(progress.hasFiniteTasks, isFalse);
      expect(progress.completionRatio, 0);
    });

    test('focus minutes only count sessions naming the project', () {
      final other = Project.create(title: 'Other');
      final progress = service.projectProgress(
        project: project,
        tasks: const [],
        sessions: [
          buildSession(workMinutes: 25, projectId: project.id),
          buildSession(workMinutes: 15, projectId: other.id),
          buildSession(workMinutes: 30),
        ],
      );

      expect(progress.focusMinutes, 25);
    });

    test('habit activity is counted apart from the task ratio', () {
      final progress = service.projectProgress(
        project: project,
        tasks: const [],
        sessions: const [],
        habits: [
          buildHabit(id: 'h1', projectId: project.id),
          buildHabit(id: 'h2', projectId: project.id, isArchived: true),
          buildHabit(id: 'h3'),
        ],
        completions: [
          buildCompletion('h1', count: 2),
          buildCompletion('h3'),
        ],
      );

      expect(progress.habitCount, 1);
      expect(progress.habitCompletionCount, 2);
      expect(progress.totalTaskCount, 0);
    });
  });

  group('goal progress', () {
    final goal = Goal.create(title: 'Ship the year');

    test('tasks count whether they name the goal or one of its projects', () {
      final project = Project.create(title: 'Launch', goalId: goal.id);
      final other = Project.create(title: 'Other', goalId: 'goal_other');
      final tasks = [
        Task.create(title: 'Via goal', goalId: goal.id)
            .copyWith(status: TaskStatus.done),
        Task.create(title: 'Via project', projectId: project.id),
        Task.create(title: 'Elsewhere', projectId: other.id),
      ];

      final progress = service.goalProgress(
        goal: goal,
        projects: [project, other],
        tasks: tasks,
        sessions: const [],
      );

      expect(progress.projectCount, 1);
      expect(progress.totalTaskCount, 2);
      expect(progress.doneTaskCount, 1);
      expect(progress.completionRatio, 0.5);
    });

    test('completed projects are counted separately', () {
      final active = Project.create(title: 'Active', goalId: goal.id);
      final done = Project.create(title: 'Done', goalId: goal.id)
          .copyWith(status: ItemStatus.completed);

      final progress = service.goalProgress(
        goal: goal,
        projects: [active, done],
        tasks: const [],
        sessions: const [],
      );

      expect(progress.projectCount, 2);
      expect(progress.completedProjectCount, 1);
    });

    test('focus minutes roll up from every project on the goal', () {
      final first = Project.create(title: 'First', goalId: goal.id);
      final second = Project.create(title: 'Second', goalId: goal.id);
      final other = Project.create(title: 'Other', goalId: 'goal_other');

      final progress = service.goalProgress(
        goal: goal,
        projects: [first, second, other],
        tasks: const [],
        sessions: [
          buildSession(workMinutes: 25, projectId: first.id),
          buildSession(workMinutes: 10, projectId: second.id),
          buildSession(workMinutes: 45, projectId: other.id),
        ],
      );

      expect(progress.focusMinutes, 35);
    });

    test('a goal with nothing on it reports zero rather than dividing', () {
      final progress = service.goalProgress(
        goal: goal,
        projects: const [],
        tasks: const [],
        sessions: const [],
      );

      expect(progress.completionRatio, 0);
      expect(progress.hasFiniteTasks, isFalse);
      expect(progress.projectCount, 0);
    });
  });
}
