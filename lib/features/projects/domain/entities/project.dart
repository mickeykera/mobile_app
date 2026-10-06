import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/constants/item_status.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';

part 'project.freezed.dart';

/// A project: a body of work that may serve a [goalId].
///
/// As with [Goal], progress is not stored here - it is derived from the tasks
/// and focus sessions attached to the project. A project is allowed to have no
/// goal at all.
@freezed
abstract class Project with _$Project {
  const factory Project({
    required String id,
    required String title,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int sortOrder,
    required ItemStatus status,
    String? description,
    String? goalId,
    DateTime? targetDate,
    String? category,
    String? color,
    DateTime? completedAt,
    DateTime? archivedAt,
  }) = _Project;

  const Project._();

  factory Project.create({
    required String title,
    String? description,
    String? goalId,
    DateTime? targetDate,
    String? category,
    String? color,
    int sortOrder = 0,
  }) {
    final now = AppClock.now();
    return Project(
      id: IdGenerator.generateProjectId(),
      title: title,
      description: description,
      goalId: goalId,
      targetDate: targetDate,
      category: category,
      color: color,
      createdAt: now,
      updatedAt: now,
      sortOrder: sortOrder,
      status: ItemStatus.active,
    );
  }
}
