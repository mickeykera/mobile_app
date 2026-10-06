import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ascend/core/constants/item_status.dart';
import 'package:ascend/core/database/database.dart';
import 'package:ascend/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:ascend/features/goals/domain/entities/goal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = DatabaseService();
    await database.close();
    await database.initialize();
  });

  test('a goal round-trips every persisted field', () async {
    final target = DateTime(2025, 12, 31);
    final completedAt = DateTime(2025, 6, 12, 8);
    final archivedAt = DateTime(2025, 7, 1, 8);
    final goal = Goal.create(
      title: 'Run a marathon',
      description: '42.2 km',
      targetDate: target,
      category: 'Body',
      color: '#112233',
      icon: 'footprints',
      sortOrder: 2,
    ).copyWith(
      status: ItemStatus.archived,
      completedAt: completedAt,
      archivedAt: archivedAt,
    );

    await GoalRepositoryImpl(database).createGoal(goal);

    final reloaded =
        (await GoalRepositoryImpl(database).getAllGoals(includeArchived: true))
            .right!
            .single;

    expect(reloaded.id, goal.id);
    expect(reloaded.title, goal.title);
    expect(reloaded.description, goal.description);
    expect(reloaded.targetDate, target);
    expect(reloaded.category, 'Body');
    expect(reloaded.color, '#112233');
    expect(reloaded.icon, 'footprints');
    expect(reloaded.createdAt, goal.createdAt);
    expect(reloaded.updatedAt, goal.updatedAt);
    expect(reloaded.sortOrder, 2);
    expect(reloaded.status, ItemStatus.archived);
    expect(reloaded.completedAt, completedAt);
    expect(reloaded.archivedAt, archivedAt);
  });

  test('absent optional fields stay null across a reload', () async {
    final goal = Goal.create(title: 'Minimal');

    await GoalRepositoryImpl(database).createGoal(goal);

    final reloaded =
        (await GoalRepositoryImpl(database).getAllGoals()).right!.single;
    expect(reloaded.description, isNull);
    expect(reloaded.targetDate, isNull);
    expect(reloaded.category, isNull);
    expect(reloaded.color, isNull);
    expect(reloaded.icon, isNull);
    expect(reloaded.completedAt, isNull);
    expect(reloaded.archivedAt, isNull);
  });

  test('a record missing optional keys loads with safe defaults', () async {
    // Simulates a goal written by a build that predates the optional fields.
    await database.setJsonList(DatabaseService.goalsKey, [
      {
        'id': 'goal_legacy',
        'title': 'Legacy goal',
        'createdAt': '2025-06-11T09:00:00.000',
        'updatedAt': '2025-06-11T09:00:00.000',
      },
    ]);

    final goal =
        (await GoalRepositoryImpl(database).getAllGoals(includeArchived: true))
            .right!
            .single;

    expect(goal.id, 'goal_legacy');
    expect(goal.description, isNull);
    expect(goal.targetDate, isNull);
    expect(goal.category, isNull);
    expect(goal.color, isNull);
    expect(goal.icon, isNull);
    expect(goal.sortOrder, 0);
    expect(goal.status, ItemStatus.active);
    expect(goal.completedAt, isNull);
    expect(goal.archivedAt, isNull);
  });

  test('a status transition survives a reload without losing other data',
      () async {
    final goal = Goal.create(title: 'Ship v1', description: 'First release');
    final repository = GoalRepositoryImpl(database);
    await repository.createGoal(goal);

    final completedAt = DateTime(2025, 6, 12, 8);
    await repository.updateGoal(goal.copyWith(
      status: ItemStatus.completed,
      completedAt: completedAt,
    ));

    final reloaded =
        (await GoalRepositoryImpl(database).getGoalById(goal.id)).right!;
    expect(reloaded.status, ItemStatus.completed);
    expect(reloaded.completedAt, completedAt);
    expect(reloaded.title, 'Ship v1');
    expect(reloaded.description, 'First release');
    expect(reloaded.createdAt, goal.createdAt);
  });

  test('archived goals are hidden unless includeArchived is set', () async {
    final active = Goal.create(title: 'Active');
    final archived = Goal.create(title: 'Archived');
    final repository = GoalRepositoryImpl(database);
    await repository.createGoal(active);
    await repository.createGoal(archived);
    await repository.archiveGoal(archived.id);

    final visible = (await GoalRepositoryImpl(database).getAllGoals()).right!;
    expect(visible.map((g) => g.id), [active.id]);

    final all =
        (await GoalRepositoryImpl(database).getAllGoals(includeArchived: true))
            .right!;
    final archivedReloaded = all.singleWhere((g) => g.id == archived.id);
    expect(archivedReloaded.status, ItemStatus.archived);
    expect(archivedReloaded.archivedAt, isNotNull);
  });

  test('unarchive returns a goal to active and clears archivedAt', () async {
    final goal = Goal.create(title: 'Come back');
    final repository = GoalRepositoryImpl(database);
    await repository.createGoal(goal);
    await repository.archiveGoal(goal.id);
    await repository.unarchiveGoal(goal.id);

    final reloaded =
        (await GoalRepositoryImpl(database).getGoalById(goal.id)).right!;
    expect(reloaded.status, ItemStatus.active);
    expect(reloaded.archivedAt, isNull);
  });

  test('multiple goals are returned in sortOrder', () async {
    final repository = GoalRepositoryImpl(database);
    await repository.createGoal(Goal.create(title: 'C', sortOrder: 2));
    await repository.createGoal(Goal.create(title: 'A', sortOrder: 0));
    await repository.createGoal(Goal.create(title: 'B', sortOrder: 1));

    final titles = (await GoalRepositoryImpl(database).getAllGoals())
        .right!
        .map((g) => g.title)
        .toList();
    expect(titles, ['A', 'B', 'C']);
  });

  test('reorderGoals rewrites sortOrder deterministically', () async {
    final repository = GoalRepositoryImpl(database);
    final first = Goal.create(title: 'First', sortOrder: 0);
    final second = Goal.create(title: 'Second', sortOrder: 1);
    await repository.createGoal(first);
    await repository.createGoal(second);

    await repository.reorderGoals([second.id, first.id]);

    final titles = (await GoalRepositoryImpl(database).getAllGoals())
        .right!
        .map((g) => g.title)
        .toList();
    expect(titles, ['Second', 'First']);
  });

  test('an empty repository returns an empty list', () async {
    final goals = (await GoalRepositoryImpl(database).getAllGoals()).right!;
    expect(goals, isEmpty);
  });

  test('getGoalById returns null for an unknown id', () async {
    final goal =
        (await GoalRepositoryImpl(database).getGoalById('missing')).right;
    expect(goal, isNull);
  });

  test('deleteGoal removes the record', () async {
    final goal = Goal.create(title: 'Gone');
    final repository = GoalRepositoryImpl(database);
    await repository.createGoal(goal);

    await repository.deleteGoal(goal.id);

    expect((await GoalRepositoryImpl(database).getGoalById(goal.id)).right,
        isNull);
  });
}
