import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/item_status.dart';
import '../../data/repositories/goal_repository_impl.dart';
import '../../domain/entities/goal.dart';
import '../controllers/goal_controller.dart';

final goalControllerProvider =
    StateNotifierProvider<GoalController, GoalState>((ref) {
  return GoalController(ref.watch(goalRepositoryProvider));
});

/// Goals that are still in play: active and completed, archived excluded.
final goalsProvider = Provider<List<Goal>>((ref) {
  return ref
      .watch(goalControllerProvider)
      .goals
      .where((g) => g.status != ItemStatus.archived)
      .toList();
});
