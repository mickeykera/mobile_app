import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';

void main() {
  final now = DateTime(2025, 6, 11, 9);
  setUp(() => AppClock.debugSetNow(() => now));
  tearDown(AppClock.debugResetNow);

  test('create stamps id, timestamps, todo status and an unscheduled default',
      () {
    final task = Task.create(title: 'Write the report');

    expect(task.id, startsWith('task_'));
    expect(task.title, 'Write the report');
    expect(task.status, TaskStatus.todo);
    expect(task.schedule, const Unscheduled());
    expect(task.createdAt, now);
    expect(task.updatedAt, now);
    expect(task.completedAt, isNull);
    expect(task.archivedAt, isNull);
    expect(task.isComplete, isFalse);
    expect(task.isInbox, isTrue);
  });

  test('a task filed under a project or goal is not in the inbox', () {
    expect(Task.create(title: 'Filed', projectId: 'p1').isInbox, isFalse);
    expect(Task.create(title: 'Filed', goalId: 'g1').isInbox, isFalse);
  });

  test('isComplete tracks the done status', () {
    final task = Task.create(title: 'Done').copyWith(status: TaskStatus.done);

    expect(task.isComplete, isTrue);
  });

  test('isDueOn delegates to the schedule', () {
    final day = DateTime(2025, 6, 14);
    final task = Task.create(title: 'Dated', schedule: Once(day));

    expect(task.isDueOn(day, now: now), isTrue);
    expect(task.isDueOn(DateTime(2025, 6, 13), now: now), isFalse);
  });

  test('an unscheduled task is never due', () {
    final task = Task.create(title: 'Backlog');

    expect(task.isDueOn(now, now: now), isFalse);
  });
}
