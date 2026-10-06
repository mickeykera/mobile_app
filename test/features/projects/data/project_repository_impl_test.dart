import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ascend/core/constants/item_status.dart';
import 'package:ascend/core/database/database.dart';
import 'package:ascend/features/projects/data/repositories/project_repository_impl.dart';
import 'package:ascend/features/projects/domain/entities/project.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = DatabaseService();
    await database.close();
    await database.initialize();
  });

  test('a project round-trips every persisted field', () async {
    final target = DateTime(2025, 12, 31);
    final completedAt = DateTime(2025, 6, 12, 8);
    final archivedAt = DateTime(2025, 7, 1, 8);
    final project = Project.create(
      title: 'Launch site',
      description: 'Marketing site',
      goalId: 'goal_123',
      targetDate: target,
      category: 'Craft',
      color: '#445566',
      sortOrder: 4,
    ).copyWith(
      status: ItemStatus.archived,
      completedAt: completedAt,
      archivedAt: archivedAt,
    );

    await ProjectRepositoryImpl(database).createProject(project);

    final reloaded = (await ProjectRepositoryImpl(database)
            .getAllProjects(includeArchived: true))
        .right!
        .single;

    expect(reloaded.id, project.id);
    expect(reloaded.title, project.title);
    expect(reloaded.description, project.description);
    expect(reloaded.goalId, 'goal_123');
    expect(reloaded.targetDate, target);
    expect(reloaded.category, 'Craft');
    expect(reloaded.color, '#445566');
    expect(reloaded.createdAt, project.createdAt);
    expect(reloaded.updatedAt, project.updatedAt);
    expect(reloaded.sortOrder, 4);
    expect(reloaded.status, ItemStatus.archived);
    expect(reloaded.completedAt, completedAt);
    expect(reloaded.archivedAt, archivedAt);
  });

  test('a project without a goal keeps goalId null', () async {
    final project = Project.create(title: 'Standalone');

    await ProjectRepositoryImpl(database).createProject(project);

    final reloaded =
        (await ProjectRepositoryImpl(database).getAllProjects()).right!.single;
    expect(reloaded.goalId, isNull);
  });

  test('a record missing optional keys loads with safe defaults', () async {
    await database.setJsonList(DatabaseService.projectsKey, [
      {
        'id': 'project_legacy',
        'title': 'Legacy project',
        'createdAt': '2025-06-11T09:00:00.000',
        'updatedAt': '2025-06-11T09:00:00.000',
      },
    ]);

    final project = (await ProjectRepositoryImpl(database)
            .getAllProjects(includeArchived: true))
        .right!
        .single;

    expect(project.id, 'project_legacy');
    expect(project.description, isNull);
    expect(project.goalId, isNull);
    expect(project.targetDate, isNull);
    expect(project.category, isNull);
    expect(project.color, isNull);
    expect(project.sortOrder, 0);
    expect(project.status, ItemStatus.active);
    expect(project.completedAt, isNull);
    expect(project.archivedAt, isNull);
  });

  test('archived projects are hidden unless includeArchived is set', () async {
    final active = Project.create(title: 'Active');
    final archived = Project.create(title: 'Archived');
    final repository = ProjectRepositoryImpl(database);
    await repository.createProject(active);
    await repository.createProject(archived);
    await repository.archiveProject(archived.id);

    final visible =
        (await ProjectRepositoryImpl(database).getAllProjects()).right!;
    expect(visible.map((p) => p.id), [active.id]);

    final all = (await ProjectRepositoryImpl(database)
            .getAllProjects(includeArchived: true))
        .right!;
    final archivedReloaded = all.singleWhere((p) => p.id == archived.id);
    expect(archivedReloaded.status, ItemStatus.archived);
    expect(archivedReloaded.archivedAt, isNotNull);
  });

  test('a project status transition and goal link survive a reload', () async {
    final project = Project.create(title: 'Ship', goalId: 'goal_9');
    final repository = ProjectRepositoryImpl(database);
    await repository.createProject(project);

    final completedAt = DateTime(2025, 6, 12, 8);
    await repository.updateProject(project.copyWith(
      status: ItemStatus.completed,
      completedAt: completedAt,
    ));

    final reloaded =
        (await ProjectRepositoryImpl(database).getProjectById(project.id))
            .right!;
    expect(reloaded.status, ItemStatus.completed);
    expect(reloaded.completedAt, completedAt);
    expect(reloaded.goalId, 'goal_9');
  });

  test('multiple projects are returned in sortOrder', () async {
    final repository = ProjectRepositoryImpl(database);
    await repository.createProject(Project.create(title: 'C', sortOrder: 2));
    await repository.createProject(Project.create(title: 'A', sortOrder: 0));
    await repository.createProject(Project.create(title: 'B', sortOrder: 1));

    final titles = (await ProjectRepositoryImpl(database).getAllProjects())
        .right!
        .map((p) => p.title)
        .toList();
    expect(titles, ['A', 'B', 'C']);
  });

  test('reorderProjects rewrites sortOrder deterministically', () async {
    final repository = ProjectRepositoryImpl(database);
    final first = Project.create(title: 'First', sortOrder: 0);
    final second = Project.create(title: 'Second', sortOrder: 1);
    await repository.createProject(first);
    await repository.createProject(second);

    await repository.reorderProjects([second.id, first.id]);

    final titles = (await ProjectRepositoryImpl(database).getAllProjects())
        .right!
        .map((p) => p.title)
        .toList();
    expect(titles, ['Second', 'First']);
  });

  test('an empty repository returns an empty list', () async {
    final projects =
        (await ProjectRepositoryImpl(database).getAllProjects()).right!;
    expect(projects, isEmpty);
  });

  test('deleteProject removes the record', () async {
    final project = Project.create(title: 'Gone');
    final repository = ProjectRepositoryImpl(database);
    await repository.createProject(project);

    await repository.deleteProject(project.id);

    expect(
        (await ProjectRepositoryImpl(database).getProjectById(project.id))
            .right,
        isNull);
  });
}
