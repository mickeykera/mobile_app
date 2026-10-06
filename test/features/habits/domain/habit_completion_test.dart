import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/habits/domain/entities/habit_completion.dart';

void main() {
  setUp(() => AppClock.debugSetNow(() => DateTime(2025, 6, 11, 9)));
  tearDown(AppClock.debugResetNow);

  test('a habit completion fills itemId and itemType from the habitId', () {
    final completion = HabitCompletion.create(habitId: 'h1');

    expect(completion.habitId, 'h1');
    expect(completion.itemId, 'h1');
    expect(completion.itemType, 'habit');
    expect(completion.ownerId, 'h1');
    expect(completion.isHabitCompletion, isTrue);
  });

  test('a task completion carries no habitId', () {
    final completion =
        HabitCompletion.create(itemId: 'task_1', itemType: 'task');

    expect(completion.habitId, isNull);
    expect(completion.itemId, 'task_1');
    expect(completion.itemType, 'task');
    expect(completion.ownerId, 'task_1');
    expect(completion.isHabitCompletion, isFalse);
  });

  test('ownerId falls back to habitId when itemId is absent', () {
    final completion = HabitCompletion(
      id: 'completion_1',
      habitId: 'h1',
      completedAt: AppClock.now(),
      count: 1,
    );

    expect(completion.ownerId, 'h1');
    expect(completion.isHabitCompletion, isTrue);
  });

  test('an untagged row with no habitId is not a habit completion', () {
    final completion = HabitCompletion(
      id: 'completion_1',
      completedAt: AppClock.now(),
      count: 1,
    );

    expect(completion.ownerId, isNull);
    expect(completion.isHabitCompletion, isFalse);
  });
}
