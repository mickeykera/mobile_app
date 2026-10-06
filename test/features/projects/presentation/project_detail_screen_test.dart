import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ascend/app/theme/app_theme.dart';
import 'package:ascend/core/constants/item_status.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/focus/data/repositories/focus_repository_impl.dart';
import 'package:ascend/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/habits/presentation/providers/habit_providers.dart';
import 'package:ascend/features/projects/data/repositories/project_repository_impl.dart';
import 'package:ascend/features/projects/domain/entities/project.dart';
import 'package:ascend/features/projects/presentation/screens/project_detail_screen.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';
import 'package:ascend/features/tasks/presentation/providers/task_providers.dart';

import '../../focus/presentation/focus_controller_test.dart'
    show FakeFocusRepository;
import '../../habits/presentation/habit_controller_test.dart'
    show FakeHabitRepository;
import '../../goals/presentation/goal_controller_test.dart'
    show FakeGoalRepository;
import '../../tasks/presentation/task_controller_test.dart'
    show FakeTaskRepository;
import 'project_controller_test.dart' show FakeProjectRepository;

Project _project(
  String id,
  String title, {
  ItemStatus status = ItemStatus.active,
  String? goalId,
  String? description,
}) =>
    Project(
      id: id,
      title: title,
      description: description,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      sortOrder: 0,
      status: status,
      goalId: goalId,
    );

Task _task(
  String id,
  String title, {
  TaskStatus status = TaskStatus.todo,
  String? projectId,
  TaskSchedule schedule = const Unscheduled(),
}) =>
    Task(
      id: id,
      title: title,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      sortOrder: 0,
      status: status,
      schedule: schedule,
      projectId: projectId,
    );

Habit _habit(String id, String title, {String? projectId}) => Habit(
      id: id,
      title: title,
      description: '',
      category: 'Body',
      frequency: 'Daily',
      customWeekdays: const <int>[],
      timeOfDay: 'Morning',
      targetCount: 1,
      targetDuration: const Duration(minutes: 20),
      cue: '',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      sortOrder: 0,
      isArchived: false,
      streakFreezesUsed: 0,
      currentStreak: 0,
      longestStreak: 0,
      totalCompletions: 40,
      projectId: projectId,
    );

GoRouter _stubRouter(String projectId) => GoRouter(
      initialLocation: '/projects/$projectId',
      routes: [
        GoRoute(
          path: '/projects/:id',
          builder: (context, state) =>
              ProjectDetailScreen(projectId: state.pathParameters['id']!),
        ),
      ],
    );

Future<ProviderContainer> _boot({
  List<Project> projects = const [],
  List<Task> tasks = const [],
  List<Habit> habits = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      projectRepositoryProvider
          .overrideWithValue(FakeProjectRepository(projects)),
      taskRepositoryProvider.overrideWithValue(FakeTaskRepository(tasks)),
      goalRepositoryProvider.overrideWithValue(FakeGoalRepository()),
      focusRepositoryProvider.overrideWithValue(FakeFocusRepository()),
      habitRepositoryProvider
          .overrideWithValue(FakeHabitRepository(habits: habits)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pump(WidgetTester tester, ProviderContainer container,
    {String projectId = 'p1'}) async {
  tester.view.physicalSize = const Size(411 * 3, 915 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: _stubRouter(projectId),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  final now = DateTime(2025, 6, 11, 9, 30);
  setUp(() => AppClock.debugSetNow(() => now));
  tearDown(AppClock.debugResetNow);

  testWidgets('an unknown project id shows a not-found state, not a crash',
      (tester) async {
    await _pump(tester, await _boot(projects: [_project('other', 'Parser')]));

    expect(find.text('Project not found'), findsOneWidget);
  });

  testWidgets('the title, status and description are shown', (tester) async {
    await _pump(
      tester,
      await _boot(
        projects: [
          _project('p1', 'Ship the parser', description: 'A real chunk of work')
        ],
      ),
    );

    expect(find.text('Ship the parser'), findsOneWidget);
    expect(find.text('A real chunk of work'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('both metrics sit side by side rather than merged',
      (tester) async {
    await _pump(
      tester,
      await _boot(
        projects: [_project('p1', 'Ship the parser')],
        tasks: [
          _task('a', 'One', projectId: 'p1', status: TaskStatus.done),
          _task('b', 'Two', projectId: 'p1', status: TaskStatus.done),
          _task('c', 'Three', projectId: 'p1'),
          _task('d', 'Four', projectId: 'p1'),
        ],
      ),
    );

    expect(find.text('2/4'), findsOneWidget);
    expect(find.text('Tasks complete'), findsOneWidget);
    expect(find.textContaining('min focused'), findsOneWidget);
  });

  testWidgets('a recurring task is listed but kept out of the ratio',
      (tester) async {
    await _pump(
      tester,
      await _boot(
        projects: [_project('p1', 'Ship the parser')],
        tasks: [
          _task('a', 'One-off', projectId: 'p1', status: TaskStatus.done),
          _task('r', 'Daily review',
              projectId: 'p1', schedule: const Recurring(DailyRecurrence())),
        ],
      ),
    );

    expect(find.text('1/1'), findsOneWidget,
        reason: 'the recurring task is never "done", so counting it would '
            'pin the project below 100% forever');
    expect(find.textContaining('1 recurring, not counted'), findsOneWidget);
  });

  testWidgets('a project with only recurring work shows no ratio',
      (tester) async {
    await _pump(
      tester,
      await _boot(
        projects: [_project('p1', 'Ship the parser')],
        tasks: [
          _task('r', 'Daily review',
              projectId: 'p1', schedule: const Recurring(DailyRecurrence())),
        ],
      ),
    );

    expect(find.text('0/0'), findsNothing);
    expect(find.text('No finite tasks yet'), findsOneWidget);
  });

  testWidgets('a project with no tasks says so', (tester) async {
    await _pump(tester, await _boot(projects: [_project('p1', 'Empty')]));

    expect(find.text('No tasks in this project'), findsOneWidget);
  });

  group('the undated habit completion count is never shown', () {
    // `ProgressService.projectProgress` is handed an empty completion list by
    // `projectProgressProvider`, so `habitCompletionCount` is structurally 0
    // here rather than measured. That is the right call - a completion count
    // needs a stated date range, and borrowing the single day the habit
    // controller happens to hold would report a lifetime number as if it were
    // today's - but it leaves a zero in the model that would be a lie if any
    // screen ever rendered it. These tests pin that it does not.
    testWidgets('attached habits are counted, but no completion figure appears',
        (tester) async {
      await _pump(
        tester,
        await _boot(
          projects: [_project('p1', 'Parser')],
          habits: [
            _habit('h1', 'Morning run', projectId: 'p1'),
            _habit('h2', 'Read pages', projectId: 'p1'),
          ],
        ),
      );

      // The accurate half is shown...
      expect(find.text('2 habits attached'), findsOneWidget);

      // ...and nothing dresses the unmeasured zero up as data.
      expect(find.textContaining(RegExp(r'\d+\s*completions?')), findsNothing);
      expect(find.textContaining('habit completion'), findsNothing);
    });

    testWidgets('no habits attached means no habit line, not "0 habits"',
        (tester) async {
      await _pump(tester, await _boot(projects: [_project('p1', 'Parser')]));

      expect(find.textContaining('habits attached'), findsNothing,
          reason: 'a zero here would read as a measured "no habits", rather '
              'than as "this project has nothing to say about habits"');
    });

    testWidgets('a habit filed to another project does not leak in',
        (tester) async {
      await _pump(
        tester,
        await _boot(
          projects: [_project('p1', 'Parser')],
          habits: [_habit('h1', 'Morning run', projectId: 'p9')],
        ),
      );

      expect(find.textContaining('habits attached'), findsNothing);
    });
  });

  testWidgets('a finished task is struck through', (tester) async {
    await _pump(
      tester,
      await _boot(
        projects: [_project('p1', 'Parser')],
        tasks: [
          _task('a', 'Done thing', projectId: 'p1', status: TaskStatus.done),
          _task('b', 'Open thing', projectId: 'p1'),
        ],
      ),
    );

    expect(tester.widget<Text>(find.text('Done thing')).style?.decoration,
        TextDecoration.lineThrough);
    expect(
        tester.widget<Text>(find.text('Open thing')).style?.decoration, isNull,
        reason: 'striking through unfinished work would be a lie');
  });

  group('lifecycle', () {
    testWidgets('an active project offers only "Mark complete"',
        (tester) async {
      await _pump(tester, await _boot(projects: [_project('p1', 'Parser')]));

      expect(find.text('Mark complete'), findsOneWidget);
      expect(find.text('Reopen'), findsNothing);
      expect(find.text('Archive'), findsNothing);
    });

    testWidgets('Mark complete moves the project and rewrites the options',
        (tester) async {
      final container = await _boot(projects: [_project('p1', 'Parser')]);
      await _pump(tester, container);

      await tester.tap(find.text('Mark complete'));
      await tester.pumpAndSettle();

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Reopen'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Mark complete'), findsNothing);
    });

    testWidgets('a completed project can be archived', (tester) async {
      final container = await _boot(projects: [
        _project('p1', 'Parser', status: ItemStatus.completed)
            .copyWith(completedAt: now)
      ]);
      await _pump(tester, container);

      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();

      expect(find.text('Archived'), findsOneWidget);
      expect(find.text('Unarchive'), findsOneWidget);
    });

    testWidgets('reopening a completed project clears the stamp',
        (tester) async {
      final container = await _boot(projects: [
        _project('p1', 'Parser', status: ItemStatus.completed)
            .copyWith(completedAt: now)
      ]);
      await _pump(tester, container);

      await tester.tap(find.text('Reopen'));
      await tester.pumpAndSettle();

      final project =
          container.read(projectRepositoryProvider) as FakeProjectRepository;
      expect(project.stored.single.status, ItemStatus.active);
      expect(project.stored.single.completedAt, isNull);
    });

    testWidgets('unarchiving brings the project back to active',
        (tester) async {
      final container = await _boot(
        projects: [_project('p1', 'Parser', status: ItemStatus.archived)],
      );
      await _pump(tester, container);

      await tester.tap(find.text('Unarchive'));
      await tester.pumpAndSettle();

      expect(find.text('Active'), findsOneWidget);
    });
  });
}
