import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/core/constants/item_status.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/goals/domain/entities/goal.dart';

void main() {
  // 2025-06-11 is a Wednesday.
  final now = DateTime(2025, 6, 11, 9);

  setUp(() => AppClock.debugSetNow(() => now));
  tearDown(AppClock.debugResetNow);

  group('Goal.create', () {
    test('starts active with an id, timestamps and no optional data', () {
      final goal = Goal.create(title: 'Run a marathon');

      expect(goal.id, startsWith('goal_'));
      expect(goal.title, 'Run a marathon');
      expect(goal.status, ItemStatus.active);
      expect(goal.createdAt, now);
      expect(goal.updatedAt, now);
      expect(goal.sortOrder, 0);
      expect(goal.description, isNull);
      expect(goal.targetDate, isNull);
      expect(goal.completedAt, isNull);
      expect(goal.archivedAt, isNull);
    });

    test('carries the optional planning fields', () {
      final target = DateTime(2025, 12, 31);
      final goal = Goal.create(
        title: 'Read more',
        description: 'Twelve books this year',
        targetDate: target,
        category: 'Mind',
        color: '#AABBCC',
        icon: 'book',
        sortOrder: 3,
      );

      expect(goal.description, 'Twelve books this year');
      expect(goal.targetDate, target);
      expect(goal.category, 'Mind');
      expect(goal.color, '#AABBCC');
      expect(goal.icon, 'book');
      expect(goal.sortOrder, 3);
    });
  });

  group('Goal status transitions', () {
    test('completing preserves identity and planning data', () {
      final goal = Goal.create(
        title: 'Ship v1',
        description: 'First release',
        targetDate: DateTime(2025, 7, 1),
      );

      final completed = goal.copyWith(
        status: ItemStatus.completed,
        completedAt: now,
        updatedAt: now,
      );

      expect(completed.id, goal.id);
      expect(completed.title, goal.title);
      expect(completed.description, goal.description);
      expect(completed.targetDate, goal.targetDate);
      expect(completed.createdAt, goal.createdAt);
      expect(completed.status, ItemStatus.completed);
      expect(completed.completedAt, now);
    });
  });

  group('ItemStatus.fromStorage', () {
    test('round-trips every known value', () {
      for (final status in ItemStatus.values) {
        expect(ItemStatus.fromStorage(status.storageValue), status);
      }
    });

    test('missing or unknown values fall back to active', () {
      expect(ItemStatus.fromStorage(null), ItemStatus.active);
      expect(ItemStatus.fromStorage('paused'), ItemStatus.active);
    });
  });
}
