import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/constants/item_status.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/app_clock.dart';
import '../../domain/entities/goal.dart';
import '../../domain/repositories/goal_repository.dart';

part 'goal_controller.freezed.dart';

@freezed
abstract class GoalState with _$GoalState {
  const factory GoalState({
    @Default([]) List<Goal> goals,
    @Default(false) bool isLoading,
    @Default(false) bool isSaving,
    String? error,
  }) = _GoalState;
}

/// Owns the goal list and the `active -> completed -> archived` lifecycle.
///
/// Mirrors [ProjectController] exactly. Goals and projects move through the same
/// three states and differ only in what sits above them, so the two controllers
/// are deliberately parallel: a divergence between them would be a bug in one of
/// them, not a distinction between the concepts.
class GoalController extends StateNotifier<GoalState> {
  final GoalRepository _repository;

  GoalController(this._repository) : super(const GoalState()) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    state = state.copyWith(isLoading: true, error: null);

    // Archived goals are loaded and filtered on read, so a filed-away goal can
    // still be unarchived.
    final result = await _repository.getAllGoals(includeArchived: true);
    if (!mounted) return;

    if (result.isLeft) {
      state = state.copyWith(isLoading: false, error: result.left!.userMessage);
      return;
    }
    state = state.copyWith(isLoading: false, goals: _sorted(result.right!));
  }

  Future<void> refresh() => _loadInitialData();

  static List<Goal> _sorted(Iterable<Goal> goals) =>
      goals.toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  Goal? _find(String id) {
    for (final goal in state.goals) {
      if (goal.id == id) return goal;
    }
    return null;
  }

  Goal? goalById(String id) => _find(id);

  String titleFor(String id) => _find(id)?.title ?? 'Unknown goal';

  Future<Result<Goal>> createGoal({
    required String title,
    String? description,
    DateTime? targetDate,
    String? category,
    String? color,
    String? icon,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return Either.left(const ValidationFailure('Goal title cannot be empty'));
    }

    state = state.copyWith(isSaving: true, error: null);

    final goal = Goal.create(
      title: trimmed,
      description: description,
      targetDate: targetDate,
      category: category,
      color: color,
      icon: icon,
      sortOrder: state.goals.length,
    );

    final result = await _repository.createGoal(goal);
    if (!mounted) return result;

    if (result.isLeft) {
      state = state.copyWith(isSaving: false, error: result.left!.userMessage);
    } else {
      state = state.copyWith(
        isSaving: false,
        goals: _sorted([...state.goals, result.right!]),
      );
    }
    return result;
  }

  Future<Result<Goal>> updateGoal(Goal goal) async {
    state = state.copyWith(isSaving: true, error: null);

    final result = await _repository.updateGoal(goal);
    if (!mounted) return result;

    if (result.isLeft) {
      state = state.copyWith(isSaving: false, error: result.left!.userMessage);
    } else {
      state = state.copyWith(
        isSaving: false,
        goals: _sorted(state.goals
            .map((g) => g.id == result.right!.id ? result.right! : g)),
      );
    }
    return result;
  }

  /// Moves [id] to [status].
  ///
  /// Reopening a completed goal clears `completedAt`; archiving preserves it,
  /// because a goal that was achieved and then filed away was still achieved.
  /// Identical to `ProjectController.setStatus` on purpose.
  Future<Result<Goal>> setStatus(String id, ItemStatus status) async {
    final goal = _find(id);
    if (goal == null) {
      return Either.left(NotFoundFailure('Goal $id not found'));
    }

    final now = AppClock.now();
    return updateGoal(goal.copyWith(
      status: status,
      completedAt: switch (status) {
        ItemStatus.completed => goal.completedAt ?? now,
        ItemStatus.archived => goal.completedAt,
        ItemStatus.active => null,
      },
      archivedAt: status == ItemStatus.archived ? now : null,
      updatedAt: now,
    ));
  }

  Future<Result<void>> deleteGoal(String id) async {
    state = state.copyWith(isSaving: true, error: null);

    final result = await _repository.deleteGoal(id);
    if (!mounted) return result;

    if (result.isLeft) {
      state = state.copyWith(isSaving: false, error: result.left!.userMessage);
    } else {
      state = state.copyWith(
        isSaving: false,
        goals: state.goals.where((g) => g.id != id).toList(),
      );
    }
    return result;
  }
}
