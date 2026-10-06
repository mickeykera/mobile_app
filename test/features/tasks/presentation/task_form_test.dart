import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/app/theme/app_theme.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/projects/data/repositories/project_repository_impl.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';
import 'package:ascend/features/tasks/presentation/providers/task_providers.dart';
import 'package:ascend/features/tasks/presentation/widgets/task_form.dart';

import '../../projects/presentation/project_controller_test.dart'
    show FakeProjectRepository;
import 'task_controller_test.dart' show FakeTaskRepository;

/// Stage L2 §7: the task form must never rewrite a recurring task's schedule.
///
/// A recurring Task is a migrated habit, and this form only offers Once/
/// Unscheduled. Before the fix, editing the title of a recurring task silently
/// turned it into a one-off; these tests pin the schedule read-only and
/// preserved.
void main() {
  final now = DateTime(2025, 6, 11, 9);

  Task recurringTask() => Task(
        id: 't1',
        title: 'Meditate',
        createdAt: now,
        updatedAt: now,
        sortOrder: 0,
        status: TaskStatus.todo,
        schedule: Recurring(
          const DailyRecurrence(),
          dueAt: DateTime(2025, 6, 20),
        ),
        category: 'Mind',
      );

  Future<ProviderContainer> boot(Task task) async {
    final container = ProviderContainer(overrides: [
      taskRepositoryProvider.overrideWithValue(FakeTaskRepository([task])),
      projectRepositoryProvider
          .overrideWithValue(FakeProjectRepository(const [])),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  Future<void> openForm(
      WidgetTester tester, ProviderContainer container, Task task) async {
    tester.view.physicalSize = const Size(411 * 3, 915 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTaskFormSheet(
                context,
                container.read(taskControllerProvider.notifier),
                task: task,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  setUp(() => AppClock.debugSetNow(() => now));
  tearDown(AppClock.debugResetNow);

  testWidgets('a recurring schedule is shown read-only', (tester) async {
    final task = recurringTask();
    final container = await boot(task);
    await openForm(tester, container, task);

    expect(find.text('Recurring · Daily'), findsOneWidget);
    expect(find.text('No date'), findsNothing);
    expect(find.text('Today'), findsNothing);
  });

  testWidgets('saving an edit preserves the recurrence and its overrides',
      (tester) async {
    final task = recurringTask();
    final container = await boot(task);
    await openForm(tester, container, task);

    await tester.enterText(find.byType(TextFormField).first, 'Meditate daily');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final saved = container.read(taskControllerProvider).tasks.single;
    expect(saved.title, 'Meditate daily');
    expect(saved.schedule, isA<Recurring>());
    final schedule = saved.schedule as Recurring;
    expect(schedule.rule, const DailyRecurrence());
    expect(schedule.dueAt, DateTime(2025, 6, 20));
  });

  testWidgets('a one-off task still offers the date selector', (tester) async {
    final task = Task(
      id: 't2',
      title: 'One off',
      createdAt: now,
      updatedAt: now,
      sortOrder: 0,
      status: TaskStatus.todo,
      schedule: const Unscheduled(),
    );
    final container = await boot(task);
    await openForm(tester, container, task);

    expect(find.text('No date'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.textContaining('Recurring ·'), findsNothing);
  });
}