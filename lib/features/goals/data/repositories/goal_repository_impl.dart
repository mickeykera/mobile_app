import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/item_status.dart';
import '../../../../core/database/database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/app_clock.dart';
import '../../domain/entities/goal.dart';
import '../../domain/repositories/goal_repository.dart';

class GoalRepositoryImpl implements GoalRepository {
  final DatabaseService _database;
  final List<Goal> _goals = [];

  /// Memoised load, not a `bool` guard, for the same reason as
  /// [HabitRepositoryImpl]: a plain bool loses the race between two concurrent
  /// callers and doubles every loaded row.
  Future<void>? _loading;

  GoalRepositoryImpl(this._database);

  Future<void> _ensureLoaded() => _loading ??= _loadFromPrefs();

  Future<void> _loadFromPrefs() async {
    final goalsJson = _database.getJsonList(DatabaseService.goalsKey) ?? [];
    for (final json in goalsJson) {
      _goals.add(_goalFromJson(json));
    }
  }

  Future<void> _saveGoals() async {
    await _database.setJsonList(
        DatabaseService.goalsKey, _goals.map(_goalToJson).toList());
  }

  Goal _goalFromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      targetDate: _dateFromJson(json['targetDate']),
      category: json['category'] as String?,
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      sortOrder: json['sortOrder'] as int? ?? 0,
      status: ItemStatus.fromStorage(json['status']),
      completedAt: _dateFromJson(json['completedAt']),
      archivedAt: _dateFromJson(json['archivedAt']),
    );
  }

  Map<String, dynamic> _goalToJson(Goal goal) {
    return {
      'id': goal.id,
      'title': goal.title,
      'description': goal.description,
      'targetDate': goal.targetDate?.toIso8601String(),
      'category': goal.category,
      'color': goal.color,
      'icon': goal.icon,
      'createdAt': goal.createdAt.toIso8601String(),
      'updatedAt': goal.updatedAt.toIso8601String(),
      'sortOrder': goal.sortOrder,
      'status': goal.status.storageValue,
      'completedAt': goal.completedAt?.toIso8601String(),
      'archivedAt': goal.archivedAt?.toIso8601String(),
    };
  }

  DateTime? _dateFromJson(Object? value) =>
      value is String ? DateTime.parse(value) : null;

  Goal? _findGoal(String id) {
    for (final goal in _goals) {
      if (goal.id == id) return goal;
    }
    return null;
  }

  @override
  Future<Result<List<Goal>>> getAllGoals({bool includeArchived = false}) async {
    await _ensureLoaded();
    try {
      final goals = _goals
          .where((g) => includeArchived || g.status != ItemStatus.archived)
          .toList();
      goals.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return Either.right(goals);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to fetch goals: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Goal?>> getGoalById(String id) async {
    await _ensureLoaded();
    try {
      return Either.right(_findGoal(id));
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to fetch goal: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Goal>> createGoal(Goal goal) async {
    await _ensureLoaded();
    try {
      _goals.add(goal);
      await _saveGoals();
      return Either.right(goal);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to create goal: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Goal>> updateGoal(Goal goal) async {
    await _ensureLoaded();
    try {
      final index = _goals.indexWhere((g) => g.id == goal.id);
      if (index >= 0) {
        _goals[index] = goal;
        await _saveGoals();
      }
      return Either.right(goal);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to update goal: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> deleteGoal(String id) async {
    await _ensureLoaded();
    try {
      _goals.removeWhere((g) => g.id == id);
      await _saveGoals();
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to delete goal: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> archiveGoal(String id) async {
    await _ensureLoaded();
    try {
      final goal = _findGoal(id);
      if (goal == null) {
        return Either.left(const NotFoundFailure('Goal not found'));
      }

      final now = AppClock.now();
      _goals[_goals.indexWhere((g) => g.id == id)] = goal.copyWith(
        status: ItemStatus.archived,
        archivedAt: now,
        updatedAt: now,
      );
      await _saveGoals();
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to archive goal: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> unarchiveGoal(String id) async {
    await _ensureLoaded();
    try {
      final goal = _findGoal(id);
      if (goal == null) {
        return Either.left(const NotFoundFailure('Goal not found'));
      }

      _goals[_goals.indexWhere((g) => g.id == id)] = goal.copyWith(
        status: ItemStatus.active,
        archivedAt: null,
        updatedAt: AppClock.now(),
      );
      await _saveGoals();
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to unarchive goal: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> reorderGoals(List<String> goalIds) async {
    await _ensureLoaded();
    try {
      for (int i = 0; i < goalIds.length; i++) {
        final goal = _findGoal(goalIds[i]);
        if (goal != null) {
          _goals[_goals.indexWhere((g) => g.id == goal.id)] = goal.copyWith(
            sortOrder: i,
            updatedAt: AppClock.now(),
          );
        }
      }
      await _saveGoals();
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to reorder goals: $e',
          originalError: e, stackTrace: st));
    }
  }
}

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final database = ref.watch(databaseServiceProvider);
  return GoalRepositoryImpl(database);
});
