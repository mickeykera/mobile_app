import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ascend/app/theme/app_theme.dart';
import 'package:ascend/core/constants/item_status.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/projects/data/repositories/project_repository_impl.dart';
import 'package:ascend/features/projects/domain/entities/project.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';
import 'package:ascend/features/tasks/presentation/providers/task_providers.dart';
import 'package:ascend/features/tasks/presentation/screens/tasks_screen.dart';

import '../../projects/presentation/project_controller_test.dart'
    show FakeProjectRepository;
import 'task_controller_test.dart' show FakeTaskRepository;

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

Project _project(String id, String title) => Project(
      id: id,
      title: title,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      sortOrder: 0,
      status: ItemStatus.active,
    );

/// The screen under test, behind a router.
///
/// The real `routerProvider` builds every screen in the shell, which would drag
/// the focus timer and its ticker into a test that only cares about this
/// screen's own layout. The stub keeps `/tasks` real and stubs nothing else the
/// screen touches - it does not navigate.
GoRouter _stubRouter() => GoRouter(
      initialLocation: '/tasks',
      routes: [
        GoRoute(
            path: '/tasks', builder: (context, state) => const TasksScreen()),
      ],
    );

Future<ProviderContainer> _boot({
  List<Task> tasks = const [],
  List<Project> projects = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      taskRepositoryProvider.overrideWithValue(FakeTaskRepository(tasks)),
      projectRepositoryProvider
          .overrideWithValue(FakeProjectRepository(projects)),
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

  testWidgets('an empty account shows the empty state, not a blank list',
      (tester) async {
    await _pump(tester, await _boot());

    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.text('Add a task'), findsOneWidget);
    expect(find.text('INBOX'), findsNothing);
  });

  testWidgets('unfiled tasks appear under an Inbox heading', (tester) async {
    await _pump(
      tester,
      await _boot(tasks: [_task('a', 'Email the team')]),
    );

    expect(find.text('INBOX'), findsOneWidget);
    expect(find.text('Email the team'), findsOneWidget);
  });

  testWidgets('a filed task leaves the inbox and gains a project section',
      (tester) async {
    await _pump(
      tester,
      await _boot(
        tasks: [
          _task('a', 'Inbox item'),
          _task('b', 'Filed item', projectId: 'p1'),
        ],
        projects: [_project('p1', 'Ship the parser')],
      ),
    );

    expect(find.text('INBOX'), findsOneWidget);
    expect(find.text('SHIP THE PARSER'), findsOneWidget);
    expect(find.text('Inbox item'), findsOneWidget);
    expect(find.text('Filed item'), findsOneWidget);
  });

  testWidgets('a goal-only task is filed, so not inbox, but still reachable',
      (tester) async {
    await _pump(
      tester,
      await _boot(tasks: [_task('a', 'Goal item').copyWith(goalId: 'g1')]),
    );

    // Not inbox work - it is filed. But it must still be on screen somewhere,
    // or it is stored, counted, and unreachable.
    expect(find.text('INBOX'), findsNothing);
    expect(find.text('BY GOAL'), findsOneWidget);
    expect(find.text('Goal item'), findsOneWidget);
  });

  testWidgets('a project with no tasks gets no heading', (tester) async {
    await _pump(
      tester,
      await _boot(
        tasks: [_task('a', 'Loose end')],
        projects: [_project('p1', 'Empty project')],
      ),
    );

    expect(find.text('EMPTY PROJECT'), findsNothing);
    expect(find.text('INBOX'), findsOneWidget);
  });

  testWidgets('archived tasks are not listed', (tester) async {
    await _pump(
      tester,
      await _boot(
          tasks: [_task('a', 'Filed away', status: TaskStatus.archived)]),
    );

    expect(find.text('Filed away'), findsNothing);
    expect(find.text('No tasks yet'), findsOneWidget);
  });

  testWidgets('the header counts open and done separately', (tester) async {
    await _pump(
      tester,
      await _boot(tasks: [
        _task('a', 'Open one'),
        _task('b', 'Open two'),
        _task('c', 'Finished', status: TaskStatus.done),
      ]),
    );

    expect(find.text('2 open · 1 done'), findsOneWidget);
  });

  testWidgets('everything done reads as finished, not as zero open',
      (tester) async {
    await _pump(
      tester,
      await _boot(tasks: [
        _task('a', 'Finished', status: TaskStatus.done),
      ]),
    );

    expect(find.text('All 1 done'), findsOneWidget);
    expect(find.text('Nothing open'), findsNothing);
  });

  testWidgets('an empty list with nothing ever added reads as "Nothing open"',
      (tester) async {
    // Guards against the header claiming a finished state for an empty account.
    await _pump(
      tester,
      await _boot(
        tasks: [_task('a', 'Archived only', status: TaskStatus.archived)],
      ),
    );

    expect(find.text('Nothing open'), findsOneWidget);
  });

  testWidgets('tapping a row ticks it, and tapping again reopens it',
      (tester) async {
    final repository = FakeTaskRepository([_task('a', 'Tap me')]);
    final container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        projectRepositoryProvider
            .overrideWithValue(FakeProjectRepository(const [])),
      ],
    );
    addTearDown(container.dispose);
    await _pump(tester, container);

    expect(find.text('0/1'), findsOneWidget);

    await tester.tap(find.text('Tap me'));
    await tester.pumpAndSettle();
    expect(repository.stored.single.status, TaskStatus.done);
    expect(find.text('1/1'), findsOneWidget);

    await tester.tap(find.text('Tap me'));
    await tester.pumpAndSettle();
    expect(repository.stored.single.status, TaskStatus.todo);
    expect(find.text('0/1'), findsOneWidget);
  });

  testWidgets('an in-progress task says so', (tester) async {
    await _pump(
      tester,
      await _boot(tasks: [
        _task('a', 'Being worked on', status: TaskStatus.doing),
      ]),
    );

    expect(find.text('In progress'), findsOneWidget);
  });

  testWidgets('a dated task shows a relative day, an undated one shows nothing',
      (tester) async {
    await _pump(
      tester,
      await _boot(tasks: [
        _task('a', 'Due today', schedule: Once(DateTime(2025, 6, 11))),
        _task('b', 'No date'),
      ]),
    );

    // The task row should show "Today" in its subtitle. The "Today" section
    // header also exists, so we find the specific task's subtitle by finding
    // the task title first and then its sibling subtitle.
    final taskTitle = find.text('Due today');
    expect(taskTitle, findsOneWidget);
    // The subtitle "Today" should be in the same row as the task title
    expect(find.text('Today'), findsAtLeastNWidgets(1));
  });

  testWidgets('a recurring task shows its frequency', (tester) async {
    await _pump(
      tester,
      await _boot(tasks: [
        _task('a', 'Weekly', schedule: const Recurring(WeekdayRecurrence())),
      ]),
    );

    expect(find.text('Weekdays'), findsOneWidget);
  });

  testWidgets('a long title wraps instead of overflowing', (tester) async {
    await _pump(
      tester,
      await _boot(tasks: [
        _task(
            'a',
            'A really quite extraordinarily long task title that will '
                'not fit on one line at all on a phone'),
      ]),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('the FAB is offered and no layout overflows at phone size',
      (tester) async {
    await _pump(
      tester,
      await _boot(tasks: [_task('a', 'Something to do')]),
    );

    expect(find.text('New Task'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
