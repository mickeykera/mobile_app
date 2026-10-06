import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ascend/core/database/database.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService database;
  final now = DateTime(2025, 6, 11, 9);

  setUp(() async {
    AppClock.debugSetNow(() => now);
    SharedPreferences.setMockInitialValues({});
    database = DatabaseService();
    await database.close();
    await database.initialize();
  });
  tearDown(AppClock.debugResetNow);

  test('a task round-trips every persisted field', () async {
    final completedAt = DateTime(2025, 6, 12, 8);
    final archivedAt = DateTime(2025, 7, 1, 8);
    final task = Task.create(
      title: 'Ship launch',
      description: 'Cut the release',
      schedule: Recurring(
        const WeekdayRecurrence(),
        dueAt: DateTime(2025, 6, 16),
        snoozedUntil: DateTime(2025, 6, 13),
      ),
      projectId: 'project_1',
      goalId: 'goal_1',
      category: 'Work',
      sortOrder: 2,
    ).copyWith(
      status: TaskStatus.archived,
      completedAt: completedAt,
      archivedAt: archivedAt,
    );

    await TaskRepositoryImpl(database).createTask(task);

    final reloaded =
        (await TaskRepositoryImpl(database).getAllTasks(includeArchived: true))
            .right!
            .single;

    expect(reloaded.id, task.id);
    expect(reloaded.title, 'Ship launch');
    expect(reloaded.description, 'Cut the release');
    expect(reloaded.projectId, 'project_1');
    expect(reloaded.goalId, 'goal_1');
    expect(reloaded.category, 'Work');
    expect(reloaded.createdAt, task.createdAt);
    expect(reloaded.updatedAt, task.updatedAt);
    expect(reloaded.sortOrder, 2);
    expect(reloaded.status, TaskStatus.archived);
    expect(reloaded.schedule, task.schedule);
    expect(reloaded.completedAt, completedAt);
    expect(reloaded.archivedAt, archivedAt);
  });

  test('each schedule variant round-trips', () async {
    final repository = TaskRepositoryImpl(database);
    final unscheduled = Task.create(title: 'Backlog', sortOrder: 0);
    final once = Task.create(
        title: 'Dated',
        schedule: Once(DateTime(2025, 6, 14, 18)),
        sortOrder: 1);
    final recurring = Task.create(
      title: 'Weekly',
      schedule: Recurring(
        const CustomRecurrence({1, 3, 5}),
        dueAt: DateTime(2025, 6, 16),
      ),
      sortOrder: 2,
    );
    await repository.createTask(unscheduled);
    await repository.createTask(once);
    await repository.createTask(recurring);

    final reloaded = (await TaskRepositoryImpl(database).getAllTasks()).right!;

    expect(reloaded.map((t) => t.schedule).toList(), [
      unscheduled.schedule,
      once.schedule,
      recurring.schedule,
    ]);
  });

  test('absent optional fields stay null across a reload', () async {
    final task = Task.create(title: 'Minimal');

    await TaskRepositoryImpl(database).createTask(task);

    final reloaded =
        (await TaskRepositoryImpl(database).getAllTasks()).right!.single;
    expect(reloaded.description, isNull);
    expect(reloaded.projectId, isNull);
    expect(reloaded.goalId, isNull);
    expect(reloaded.category, isNull);
    expect(reloaded.completedAt, isNull);
    expect(reloaded.archivedAt, isNull);
    expect(reloaded.schedule, const Unscheduled());
  });

  test('a record missing optional keys loads with safe defaults', () async {
    // Simulates a task written by a build that predates the optional fields.
    await database.setJsonList(DatabaseService.tasksKey, [
      {
        'id': 'task_legacy',
        'title': 'Legacy task',
        'createdAt': '2025-06-11T09:00:00.000',
        'updatedAt': '2025-06-11T09:00:00.000',
      },
    ]);

    final task =
        (await TaskRepositoryImpl(database).getAllTasks()).right!.single;

    expect(task.id, 'task_legacy');
    expect(task.description, isNull);
    expect(task.projectId, isNull);
    expect(task.goalId, isNull);
    expect(task.category, isNull);
    expect(task.sortOrder, 0);
    expect(task.status, TaskStatus.todo);
    expect(task.schedule, const Unscheduled());
    expect(task.completedAt, isNull);
    expect(task.archivedAt, isNull);
  });

  test('the inbox holds only tasks with no project and no goal', () async {
    final repository = TaskRepositoryImpl(database);
    final inbox = Task.create(title: 'Inbox');
    final projectTask = Task.create(title: 'Project', projectId: 'p1');
    final goalTask = Task.create(title: 'Goal', goalId: 'g1');
    await repository.createTask(inbox);
    await repository.createTask(projectTask);
    await repository.createTask(goalTask);

    final inboxTasks =
        (await TaskRepositoryImpl(database).getInboxTasks()).right!;
    expect(inboxTasks.map((t) => t.id), [inbox.id]);
  });

  test('tasks can be queried by project and by goal', () async {
    final repository = TaskRepositoryImpl(database);
    final projectTask = Task.create(title: 'Project', projectId: 'p1');
    final goalTask = Task.create(title: 'Goal', goalId: 'g1');
    final other = Task.create(title: 'Other', projectId: 'p2');
    await repository.createTask(projectTask);
    await repository.createTask(goalTask);
    await repository.createTask(other);

    expect(
      (await TaskRepositoryImpl(database).getTasksForProject('p1'))
          .right!
          .map((t) => t.id),
      [projectTask.id],
    );
    expect(
      (await TaskRepositoryImpl(database).getTasksForGoal('g1'))
          .right!
          .map((t) => t.id),
      [goalTask.id],
    );
  });

  test('archived tasks are hidden unless includeArchived is set', () async {
    final repository = TaskRepositoryImpl(database);
    final active = Task.create(title: 'Active');
    final archived = Task.create(title: 'Archived');
    await repository.createTask(active);
    await repository.createTask(archived);
    await repository.archiveTask(archived.id);

    final visible = (await TaskRepositoryImpl(database).getAllTasks()).right!;
    expect(visible.map((t) => t.id), [active.id]);

    final all =
        (await TaskRepositoryImpl(database).getAllTasks(includeArchived: true))
            .right!;
    final archivedReloaded = all.singleWhere((t) => t.id == archived.id);
    expect(archivedReloaded.status, TaskStatus.archived);
    expect(archivedReloaded.archivedAt, isNotNull);
  });

  test('unarchive returns a task to the backlog', () async {
    final task = Task.create(title: 'Come back');
    final repository = TaskRepositoryImpl(database);
    await repository.createTask(task);
    await repository.archiveTask(task.id);
    await repository.unarchiveTask(task.id);

    final reloaded =
        (await TaskRepositoryImpl(database).getTaskById(task.id)).right!;
    expect(reloaded.status, TaskStatus.todo);
    expect(reloaded.archivedAt, isNull);
  });

  test('archive and unarchive report a missing task', () async {
    final repository = TaskRepositoryImpl(database);

    expect((await repository.archiveTask('missing')).isLeft, isTrue);
    expect((await repository.unarchiveTask('missing')).isLeft, isTrue);
  });

  test('multiple tasks are returned in sortOrder', () async {
    final repository = TaskRepositoryImpl(database);
    await repository.createTask(Task.create(title: 'C', sortOrder: 2));
    await repository.createTask(Task.create(title: 'A', sortOrder: 0));
    await repository.createTask(Task.create(title: 'B', sortOrder: 1));

    final titles = (await TaskRepositoryImpl(database).getAllTasks())
        .right!
        .map((t) => t.title)
        .toList();
    expect(titles, ['A', 'B', 'C']);
  });

  test('reorderTasks rewrites sortOrder deterministically', () async {
    final repository = TaskRepositoryImpl(database);
    final first = Task.create(title: 'First', sortOrder: 0);
    final second = Task.create(title: 'Second', sortOrder: 1);
    await repository.createTask(first);
    await repository.createTask(second);

    await repository.reorderTasks([second.id, first.id]);

    final titles = (await TaskRepositoryImpl(database).getAllTasks())
        .right!
        .map((t) => t.title)
        .toList();
    expect(titles, ['Second', 'First']);
  });

  test('an empty repository returns an empty list', () async {
    expect((await TaskRepositoryImpl(database).getAllTasks()).right, isEmpty);
  });

  test('getTaskById returns null for an unknown id', () async {
    expect((await TaskRepositoryImpl(database).getTaskById('missing')).right,
        isNull);
  });

  test('deleteTask removes the record', () async {
    final task = Task.create(title: 'Gone');
    final repository = TaskRepositoryImpl(database);
    await repository.createTask(task);

    await repository.deleteTask(task.id);

    expect((await TaskRepositoryImpl(database).getTaskById(task.id)).right,
        isNull);
  });
}
