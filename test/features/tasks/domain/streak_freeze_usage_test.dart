import 'package:ascend/core/constants/app_constants.dart';
import 'package:ascend/features/tasks/domain/value_objects/streak_freeze_usage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stage L1.3 value-object tests for the canonical streak-freeze usage.
void main() {
  group('StreakFreezeUsage', () {
    test('defaults to zero spent', () {
      const usage = StreakFreezeUsage();
      expect(usage.used, 0);
      expect(usage.remaining, AppConstants.maxStreakFreezes);
      expect(usage.exhausted, isFalse);
    });

    test('use() spends exactly one freeze', () {
      const usage = StreakFreezeUsage(1);
      final next = usage.use();
      expect(next.used, 2);
      expect(usage.used, 1, reason: 'must be immutable');
    });

    test('use() cannot spend past the allowance', () {
      const usage = StreakFreezeUsage(AppConstants.maxStreakFreezes);
      expect(usage.exhausted, isTrue);
      expect(usage.use(), usage, reason: 'spending is a no-op when exhausted');
    });

    test('remaining floors at zero', () {
      const usage = StreakFreezeUsage(AppConstants.maxStreakFreezes + 4);
      expect(usage.remaining, 0);
    });

    test('equality and hashCode are by usage, not identity', () {
      expect(const StreakFreezeUsage(2), const StreakFreezeUsage(2));
      expect(const StreakFreezeUsage(2).hashCode,
          const StreakFreezeUsage(2).hashCode);
      expect(const StreakFreezeUsage(1), isNot(const StreakFreezeUsage(2)));
    });
  });
}
