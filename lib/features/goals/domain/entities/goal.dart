import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/constants/item_status.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';

part 'goal.freezed.dart';

/// A goal: the "why" above the projects and tasks that serve it.
///
/// This is deliberately plain data. Whether a goal is overdue, or how far
/// along it is, is derived from its projects/tasks later; storing or guessing
/// that here would create a second source of truth.
@freezed
abstract class Goal with _$Goal {
  const factory Goal({
    required String id,
    required String title,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int sortOrder,
    required ItemStatus status,
    String? description,
    DateTime? targetDate,
    String? category,
    String? color,
    String? icon,
    DateTime? completedAt,
    DateTime? archivedAt,
  }) = _Goal;

  const Goal._();

  factory Goal.create({
    required String title,
    String? description,
    DateTime? targetDate,
    String? category,
    String? color,
    String? icon,
    int sortOrder = 0,
  }) {
    final now = AppClock.now();
    return Goal(
      id: IdGenerator.generateGoalId(),
      title: title,
      description: description,
      targetDate: targetDate,
      category: category,
      color: color,
      icon: icon,
      createdAt: now,
      updatedAt: now,
      sortOrder: sortOrder,
      status: ItemStatus.active,
    );
  }
}
