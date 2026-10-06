import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ascend/app/theme/app_theme.dart';
import 'package:ascend/core/constants/item_status.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/focus/data/repositories/focus_repository_impl.dart';
import 'package:ascend/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:ascend/features/goals/domain/entities/goal.dart';
import 'package:ascend/features/goals/presentation/screens/goals_screen.dart';
import 'package:ascend/features/tasks/presentation/providers/task_providers.dart';
import 'package:ascend/features/projects/data/repositories/project_repository_impl.dart';
import 'package:ascend/features/projects/domain/entities/project.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';

import '../../focus/presentation/focus_controller_test.dart'
    show FakeFocusRepository;
import '../../projects/presentation/project_controller_test.dart'
    show FakeProjectRepository;
import '../../tasks/presentation/task_controller_test.dart'
    show FakeTaskRepository;
import 'goal_controller_test.dart' show FakeGoalRepository;

Goal _goal(String id, String title, {ItemStatus status = ItemStatus.active}) =>
    Goal(
      id: id,
      title: title,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      sortOrder: 0,
      status: status,
    );

Project _project(
  String id,
  String title, {
  String? goalId,
  ItemStatus status = ItemStatus.active,
}) =>
    Project(
      id: id,
      title: title,
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
  String? goalId,
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
      goalId: goalId,
    );

/// The screen under test, behind a router so the project chips have a target.
///
/// The real `routerProvider` builds the whole shell and would pull the focus
/// ticker into a layout test, so only `/goals` and the project drilldown are
/// wired here.
GoRouter _stubRouter() => GoRouter(
      initialLocation: '/goals',
      routes: [
        GoRoute(
            path: '/goals', builder: (context, state) => const GoalsScreen()),
        GoRoute(
          path: '/projects/:id',
          builder: (context, state) => Scaffold(
            body: Text('Project ${state.pathParameters['id']}'),
          ),
        ),
      ],
    );

Future<ProviderContainer> _boot({
  List<Goal> goals = const [],
  List<Project> projects = const [],
  List<Task> tasks = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      goalRepositoryProvider.overrideWithValue(FakeGoalRepository(goals)),
      projectRepositoryProvider
          .overrideWithValue(FakeProjectRepository(projects)),
      taskRepositoryProvider.overrideWithValue(FakeTaskRepository(tasks)),
      focusRepositoryProvider.overrideWithValue(FakeFocusRepository()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  tester.view.physicalSize = const Size(411 * 3, 915 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: _stubRouter(),
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

  testWidgets('an empty account shows the empty state', (tester) async {
    await _pump(tester, await _boot());

    expect(find.text('No goals yet'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);
  });

  testWidgets('a goal lists the projects serving it', (tester) async {
    await _pump(
      tester,
      await _boot(
        goals: [_goal('g1', 'Learn to sail')],
        projects: [
          _project('p1', 'Theory', goalId: 'g1'),
          _project('p2', 'On the water', goalId: 'g1'),
        ],
      ),
    );

    expect(find.text('Learn to sail'), findsOneWidget);
    expect(find.text('Theory'), findsOneWidget);
    expect(find.text('On the water'), findsOneWidget);
    expect(find.textContaining('2 projects'), findsOneWidget);
  });

  testWidgets('a project belonging to no goal is left out', (tester) async {
    await _pump(
      tester,
      await _boot(
        goals: [_goal('g1', 'Learn to sail')],
        projects: [_project('p1', 'Orphan', goalId: null)],
      ),
    );

    expect(find.text('Orphan'), findsNothing);
  });

  testWidgets('the finite-task ratio is shown next to the focus minutes',
      (tester) async {
    await _pump(
      tester,
      await _boot(
        goals: [_goal('g1', 'Ship it')],
        projects: [_project('p1', 'Parser', goalId: 'g1')],
        tasks: [
          _task('a', 'One', projectId: 'p1', status: TaskStatus.done),
          _task('b', 'Two', projectId: 'p1', status: TaskStatus.done),
          _task('c', 'Three', projectId: 'p1', status: TaskStatus.todo),
          _task('d', 'Four', projectId: 'p1', status: TaskStatus.todo),
        ],
      ),
    );

    expect(find.text('50%'), findsOneWidget);
    // The two figures are kept apart rather than merged into one score.
    expect(find.textContaining('2/4 tasks'), findsOneWidget);
    expect(find.textContaining('min focused'), findsOneWidget);
  });

  testWidgets('a goal with only recurring work reports no ratio',
      (tester) async {
    await _pump(
      tester,
      await _boot(
        goals: [_goal('g1', 'Keep the streak')],
        projects: [_project('p1', 'Morning pages', goalId: 'g1')],
        tasks: [
          _task('a', 'Page',
              projectId: 'p1', schedule: const Recurring(DailyRecurrence())),
        ],
      ),
    );

    expect(find.text('0%'), findsNothing,
        reason: 'a 0% ring would read as failure, not as "not applicable"');
    expect(find.textContaining('No finite tasks'), findsOneWidget);
  });

  testWidgets('an archived goal is hidden but a completed one is not',
      (tester) async {
    await _pump(
      tester,
      await _boot(
        goals: [
          _goal('g1', 'Still going'),
          _goal('g2', 'Finished thing', status: ItemStatus.completed),
          _goal('g3', 'Filed away', status: ItemStatus.archived),
        ],
      ),
    );

    expect(find.text('Still going'), findsOneWidget);
    expect(find.text('Finished thing'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Filed away'), findsNothing);
  });

  testWidgets('tapping a project chip opens that project', (tester) async {
    await _pump(
      tester,
      await _boot(
        goals: [_goal('g1', 'Learn to sail')],
        projects: [_project('p1', 'Theory', goalId: 'g1')],
      ),
    );

    await tester.tap(find.text('Theory'));
    await tester.pumpAndSettle();

    expect(find.text('Project p1'), findsOneWidget);
  });
}
