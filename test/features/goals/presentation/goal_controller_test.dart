import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/core/constants/item_status.dart';
import 'package:ascend/core/errors/failures.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/goals/domain/entities/goal.dart';
import 'package:ascend/features/goals/domain/repositories/goal_repository.dart';
import 'package:ascend/features/goals/presentation/controllers/goal_controller.dart';

class FakeGoalRepository implements GoalRepository {
  final List<Goal> stored;
  bool failOnRead = false;
  bool failOnWrite = false;

  FakeGoalRepository([List<Goal>? initial])
      : stored = initial == null ? [] : List<Goal>.from(initial);

  @override
  Future<Result<List<Goal>>> getAllGoals({bool includeArchived = false}) async {
    if (failOnRead) return Either.left(const CacheFailure('read failed'));
    return Either.right(stored
        .where((g) => includeArchived || g.status != ItemStatus.archived)
        .toList());
  }

  @override
  Future<Result<Goal?>> getGoalById(String id) async => Either.right(_find(id));

  @override
  Future<Result<Goal>> createGoal(Goal goal) async {
    if (failOnWrite) return Either.left(const CacheFailure('write failed'));
    stored.add(goal);
    return Either.right(goal);
  }

  @override
  Future<Result<Goal>> updateGoal(Goal goal) async {
    if (failOnWrite) return Either.left(const CacheFailure('write failed'));
    final index = stored.indexWhere((g) => g.id == goal.id);
    if (index >= 0) stored[index] = goal;
    return Either.right(goal);
  }

  @override
  Future<Result<void>> deleteGoal(String id) async {
    if (failOnWrite) return Either.left(const CacheFailure('write failed'));
    stored.removeWhere((g) => g.id == id);
    return Either.right(null);
  }

  @override
  Future<Result<void>> archiveGoal(String id) async {
    final goal = _find(id);
    if (goal == null) return Either.left(const NotFoundFailure('not found'));
    stored[stored.indexWhere((g) => g.id == id)] =
        goal.copyWith(status: ItemStatus.archived, archivedAt: AppClock.now());
    return Either.right(null);
  }

  @override
  Future<Result<void>> unarchiveGoal(String id) async {
    final goal = _find(id);
    if (goal == null) return Either.left(const NotFoundFailure('not found'));
    stored[stored.indexWhere((g) => g.id == id)] =
        goal.copyWith(status: ItemStatus.active, archivedAt: null);
    return Either.right(null);
  }

  @override
  Future<Result<void>> reorderGoals(List<String> goalIds) async {
    for (var i = 0; i < goalIds.length; i++) {
      final goal = _find(goalIds[i]);
      if (goal != null) {
        stored[stored.indexWhere((g) => g.id == goal.id)] =
            goal.copyWith(sortOrder: i);
      }
    }
    return Either.right(null);
  }

  Goal? _find(String id) {
    for (final goal in stored) {
      if (goal.id == id) return goal;
    }
    return null;
  }
}

Goal _goal(String id, {ItemStatus status = ItemStatus.active, int order = 0}) =>
    Goal(
      id: id,
      title: 'Goal $id',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      sortOrder: order,
      status: status,
    );

void main() {
  final now = DateTime(2025, 6, 11, 9);
  setUp(() => AppClock.debugSetNow(() => now));
  tearDown(AppClock.debugResetNow);

  late FakeGoalRepository repository;

  setUp(() {
    repository = FakeGoalRepository();
  });

  Future<GoalController> build([List<Goal> seed = const []]) async {
    repository.stored.addAll(seed);
    final built = GoalController(repository);
    await Future<void>.delayed(Duration.zero);
    return built;
  }

  test('loads archived goals too, so they can be unarchived', () async {
    final controller =
        await build([_goal('a'), _goal('b', status: ItemStatus.archived)]);

    expect(controller.state.goals.map((g) => g.id), ['a', 'b']);
  });

  test('a new goal starts active and undated', () async {
    final controller = await build();

    final result = await controller.createGoal(title: '  Learn to sail  ');

    expect(result.right!.title, 'Learn to sail');
    expect(result.right!.status, ItemStatus.active);
    expect(result.right!.completedAt, isNull);
    expect(result.right!.targetDate, isNull,
        reason: 'a goal states a why, not a date');
  });

  test('a goal can carry a target date', () async {
    final controller = await build();
    final target = DateTime(2026, 1, 1);

    final result =
        await controller.createGoal(title: 'Race', targetDate: target);

    expect(result.right!.targetDate, target);
  });

  test('a blank title is rejected and nothing is stored', () async {
    final controller = await build();

    final result = await controller.createGoal(title: '   ');

    expect(result.isLeft, isTrue);
    expect(result.left, isA<ValidationFailure>());
    expect(controller.state.goals, isEmpty);
    expect(repository.stored, isEmpty);
  });

  group('lifecycle', () {
    test('active -> completed stamps completedAt', () async {
      final controller = await build([_goal('a')]);

      final result = await controller.setStatus('a', ItemStatus.completed);

      expect(result.right!.status, ItemStatus.completed);
      expect(result.right!.completedAt, now);
    });

    test('reopening a completed goal clears completedAt', () async {
      final controller = await build([
        _goal('a', status: ItemStatus.completed).copyWith(completedAt: now)
      ]);

      await controller.setStatus('a', ItemStatus.active);

      expect(controller.goalById('a')!.completedAt, isNull);
    });

    test('active -> archived stamps archivedAt', () async {
      final controller = await build([_goal('a')]);

      final result = await controller.setStatus('a', ItemStatus.archived);

      expect(result.right!.archivedAt, now);
    });

    test('completed -> archived keeps completedAt', () async {
      final controller = await build([_goal('a')]);
      await controller.setStatus('a', ItemStatus.completed);

      await controller.setStatus('a', ItemStatus.archived);

      final goal = controller.goalById('a')!;
      expect(goal.status, ItemStatus.archived);
      expect(goal.completedAt, isNotNull);
    });

    test('an unknown id is a NotFoundFailure', () async {
      final controller = await build();

      final result = await controller.setStatus('nope', ItemStatus.completed);

      expect(result.isLeft, isTrue);
      expect(result.left, isA<NotFoundFailure>());
    });
  });

  test('titleFor falls back rather than throwing on an unknown id', () async {
    final controller = await build([_goal('a')]);

    expect(controller.titleFor('a'), 'Goal a');
    expect(controller.titleFor('missing'), 'Unknown goal');
  });

  test('a failed load surfaces the message', () async {
    repository.failOnRead = true;
    final controller = await build();

    expect(controller.state.error, isNotNull);
    expect(controller.state.goals, isEmpty);
  });

  test('a failed write leaves the list untouched', () async {
    final controller = await build([_goal('a')]);
    repository.failOnWrite = true;

    final result = await controller.createGoal(title: 'Nope');

    expect(result.isLeft, isTrue);
    expect(controller.state.goals, hasLength(1));
    expect(controller.state.isSaving, isFalse);
  });

  test('deleting drops the goal', () async {
    final controller = await build([_goal('a')]);

    await controller.deleteGoal('a');

    expect(controller.state.goals, isEmpty);
  });

  test('goals load in sortOrder', () async {
    final controller =
        await build([_goal('b', order: 2), _goal('a', order: 0)]);

    expect(controller.state.goals.map((g) => g.id), ['a', 'b']);
  });

  test('a new goal lands after the existing ones', () async {
    final controller =
        await build([_goal('a', order: 0), _goal('b', order: 1)]);

    await controller.createGoal(title: 'Third');

    expect(controller.state.goals.map((g) => g.title),
        ['Goal a', 'Goal b', 'Third']);
  });
}
