import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ascend/core/database/database.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/habits/data/repositories/habit_repository_impl.dart';
import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/habits/domain/entities/habit_completion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = DatabaseService();
    await database.close();
    await database.initialize();
  });

  test('dueAt and snoozedUntil survive a reload', () async {
    final dueAt = DateTime(2025, 6, 14, 9);
    final snoozedUntil = DateTime(2025, 6, 12, 9);
    final habit = Habit.create(title: 'Read', category: 'Mind')
        .copyWith(dueAt: dueAt, snoozedUntil: snoozedUntil);

    final writer = HabitRepositoryImpl(database);
    final created = await writer.createHabit(habit);
    expect(created.isRight, isTrue);

    // A second instance reads the persisted JSON, not the writer's cache.
    final reader = HabitRepositoryImpl(database);
    final loaded = await reader.getAllHabits();
    expect(loaded.isRight, isTrue);

    final reloaded = loaded.right!.single;
    expect(reloaded.dueAt, dueAt);
    expect(reloaded.snoozedUntil, snoozedUntil);
  });

  test('habits with no scheduling fields round-trip as null', () async {
    final habit = Habit.create(title: 'Read', category: 'Mind');

    final writer = HabitRepositoryImpl(database);
    await writer.createHabit(habit);

    final reader = HabitRepositoryImpl(database);
    final reloaded = (await reader.getAllHabits()).right!.single;
    expect(reloaded.dueAt, isNull);
    expect(reloaded.snoozedUntil, isNull);
  });

  test('clearing a snooze and setting a due date persists the final state',
      () async {
    final snoozedUntil = DateTime(2025, 6, 12, 9);
    final dueAt = DateTime(2025, 6, 14, 9);
    final habit = Habit.create(title: 'Read', category: 'Mind')
        .copyWith(snoozedUntil: snoozedUntil);

    final writer = HabitRepositoryImpl(database);
    await writer.createHabit(habit);
    await writer.updateHabit(habit.copyWith(snoozedUntil: null, dueAt: dueAt));

    // A reschedule that clears the snooze must not resurrect it on reload.
    final reloaded =
        (await HabitRepositoryImpl(database).getAllHabits()).right!.single;
    expect(reloaded.snoozedUntil, isNull);
    expect(reloaded.dueAt, dueAt);
  });

  test('projectId and goalId round-trip through persistence', () async {
    final habit = Habit.create(
      title: 'Read',
      category: 'Mind',
      projectId: 'project_1',
      goalId: 'goal_1',
    );

    await HabitRepositoryImpl(database).createHabit(habit);

    final reloaded =
        (await HabitRepositoryImpl(database).getAllHabits()).right!.single;
    expect(reloaded.projectId, 'project_1');
    expect(reloaded.goalId, 'goal_1');
  });

  test('an unfiled habit round-trips with null links', () async {
    final habit = Habit.create(title: 'Read', category: 'Mind');

    await HabitRepositoryImpl(database).createHabit(habit);

    final reloaded =
        (await HabitRepositoryImpl(database).getAllHabits()).right!.single;
    expect(reloaded.projectId, isNull);
    expect(reloaded.goalId, isNull);
  });

  test('legacy habit JSON without link keys deserializes with null links',
      () async {
    final habit = Habit.create(
      title: 'Read',
      category: 'Mind',
      projectId: 'project_1',
      goalId: 'goal_1',
    );
    await HabitRepositoryImpl(database).createHabit(habit);

    // Simulate a record written before schema v3 by dropping the new keys.
    final stored = database.getJsonList('habits')!;
    for (final row in stored) {
      row.remove('projectId');
      row.remove('goalId');
    }
    await database.setJsonList('habits', stored);

    final reloaded =
        (await HabitRepositoryImpl(database).getAllHabits()).right!.single;
    expect(reloaded.projectId, isNull);
    expect(reloaded.goalId, isNull);
  });

  test('clearing a link persists as null and keeps the rest of the habit',
      () async {
    final habit = Habit.create(
      title: 'Read',
      category: 'Mind',
      projectId: 'project_1',
      goalId: 'goal_1',
    );
    final repository = HabitRepositoryImpl(database);
    await repository.createHabit(habit);

    await repository.updateHabit(habit.copyWith(projectId: null, goalId: null));

    final reloaded =
        (await HabitRepositoryImpl(database).getAllHabits()).right!.single;
    expect(reloaded.projectId, isNull);
    expect(reloaded.goalId, isNull);
    expect(reloaded.title, 'Read');
    expect(reloaded.category, 'Mind');
  });

  test('a habit completion writes canonical item fields and reads them back',
      () async {
    final repository = HabitRepositoryImpl(database);
    await repository.createCompletion(HabitCompletion.create(habitId: 'h1'));

    final reloaded =
        (await HabitRepositoryImpl(database).getCompletionsForHabit('h1'))
            .right!
            .single;
    expect(reloaded.habitId, 'h1');
    expect(reloaded.itemId, 'h1');
    expect(reloaded.itemType, 'habit');
    expect(reloaded.ownerId, 'h1');
    expect(reloaded.isHabitCompletion, isTrue);
  });

  test('legacy completion JSON with only a habitId reads as a habit row',
      () async {
    // Simulate a row written before the itemId/itemType widening.
    await database.setJsonList('habit_completions', [
      {
        'id': 'completion_legacy',
        'habitId': 'habit_1',
        'completedAt': '2025-06-11T09:00:00.000',
        'count': 1,
      },
    ]);

    final reloaded =
        (await HabitRepositoryImpl(database).getCompletionsForHabit('habit_1'))
            .right!
            .single;
    expect(reloaded.habitId, 'habit_1');
    expect(reloaded.itemId, 'habit_1');
    expect(reloaded.itemType, 'habit');
    expect(reloaded.isHabitCompletion, isTrue);
  });

  test('a task completion round-trips without a habitId', () async {
    final now = DateTime(2025, 6, 11, 9);
    AppClock.debugSetNow(() => now);
    addTearDown(AppClock.debugResetNow);

    await HabitRepositoryImpl(database).createCompletion(
      HabitCompletion.create(itemId: 'task_1', itemType: 'task'),
    );

    final reloaded =
        (await HabitRepositoryImpl(database).getCompletionsInRange(now, now))
            .right!
            .single;
    expect(reloaded.habitId, isNull);
    expect(reloaded.itemId, 'task_1');
    expect(reloaded.itemType, 'task');
    expect(reloaded.ownerId, 'task_1');
    expect(reloaded.isHabitCompletion, isFalse);
  });
}
