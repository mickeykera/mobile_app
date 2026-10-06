import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';
import 'package:ascend/features/tasks/presentation/providers/task_providers.dart';

Task _task(
  String id, {
  TaskStatus status = TaskStatus.todo,
  String? projectId,
  String? goalId,
  TaskSchedule schedule = const Unscheduled(),
}) =>
    Task(
      id: id,
      title: 'Task $id',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      sortOrder: 0,
      status: status,
      schedule: schedule,
      projectId: projectId,
      goalId: goalId,
    );

void main() {
  group('taskSections', () {
    test('the Inbox comes first and holds only unfiled tasks', () {
      final sections = taskSections(
        [_task('a'), _task('b', projectId: 'p1')],
        {'p1': 'Ship the parser'},
      );

      expect(sections, hasLength(2));
      expect(sections.first.inbox, isTrue);
      expect(sections.first.title, 'Inbox');
      expect(sections.first.projectId, isNull);
      expect(sections.first.tasks.map((t) => t.id), ['a']);
      expect(sections.last.inbox, isFalse);
      expect(sections.last.projectId, 'p1');
      expect(sections.last.tasks.map((t) => t.id), ['b']);
    });

    test('an empty inbox produces no section at all', () {
      final sections = taskSections(
        [_task('a', projectId: 'p1')],
        {'p1': 'Ship the parser'},
      );

      expect(sections, hasLength(1));
      expect(sections.single.inbox, isFalse);
    });

    test('a project with no tasks is skipped rather than shown empty', () {
      final sections = taskSections(
        [_task('inbox'), _task('a', projectId: 'p1')],
        {'p1': 'Has work', 'p2': 'Has none'},
      );

      expect(sections.map((s) => s.title), ['Inbox', 'Has work']);
    });

    test('a goal-only task gets its own section rather than vanishing', () {
      final sections = taskSections([_task('a', goalId: 'g1')], const {});

      expect(sections, hasLength(1));
      expect(sections.single.inbox, isFalse);
      expect(sections.single.title, 'By goal');
      expect(sections.single.projectId, isNull);
      expect(sections.single.tasks.map((t) => t.id), ['a']);
    });

    test('a task with both a project and a goal lands in the project only', () {
      final sections = taskSections(
        [_task('a', projectId: 'p1', goalId: 'g1')],
        {'p1': 'Ship it'},
      );

      expect(sections.map((s) => s.title), ['Ship it'],
          reason: 'listing it twice would let the two rows disagree');
    });

    test('no tasks means no sections', () {
      expect(taskSections(const [], const {}), isEmpty);
    });

    test('project order follows the title map, not the task list', () {
      final sections = taskSections(
        [_task('a', projectId: 'p2'), _task('b', projectId: 'p1')],
        {'p1': 'First', 'p2': 'Second'},
      );

      expect(sections.map((s) => s.title), ['First', 'Second']);
    });
  });

  group('finiteCompletionRatio', () {
    test('counts done over total', () {
      final tasks = [
        _task('a', status: TaskStatus.done),
        _task('b'),
        _task('c'),
        _task('d'),
      ];

      expect(finiteCompletionRatio(tasks), 0.25);
    });

    test('recurring tasks are excluded from both sides', () {
      final tasks = [
        _task('a', status: TaskStatus.done),
        _task('r', schedule: const Recurring(DailyRecurrence())),
      ];

      expect(finiteCompletionRatio(tasks), 1.0,
          reason: 'a recurring task is never done, so including it would pin '
              'the ratio below 1 forever');
      expect(hasFiniteTasks(tasks), isTrue);
    });

    test('archived tasks are excluded', () {
      final tasks = [
        _task('a', status: TaskStatus.done),
        _task('b', status: TaskStatus.archived),
      ];

      expect(finiteCompletionRatio(tasks), 1.0);
      expect(hasFiniteTasks(tasks), isTrue);
    });

    test('no finite tasks is zero, and reports that it has none', () {
      final tasks = [
        _task('r', schedule: const Recurring(DailyRecurrence())),
      ];

      expect(finiteCompletionRatio(tasks), 0);
      expect(hasFiniteTasks(tasks), isFalse,
          reason: 'the screen needs to know not to draw a 0% ring');
    });

    test('an empty list is zero and has no finite tasks', () {
      expect(finiteCompletionRatio(const []), 0);
      expect(hasFiniteTasks(const []), isFalse);
    });

    test('a fully done list is exactly 1, never more', () {
      final tasks = [
        _task('a', status: TaskStatus.done),
        _task('b', status: TaskStatus.done),
      ];

      expect(finiteCompletionRatio(tasks), 1.0);
    });
  });

  group('hasFiniteTasks', () {
    test('an unscheduled task still counts as finite', () {
      expect(hasFiniteTasks([_task('a')]), isTrue,
          reason: 'unscheduled means undated, not unbounded');
    });
  });
}
