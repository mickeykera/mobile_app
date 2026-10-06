import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/core/constants/item_status.dart';
import 'package:ascend/features/projects/domain/entities/project.dart';

void main() {
  test('create starts active and unlinked with an id', () {
    final project = Project.create(title: 'Website');

    expect(project.id, startsWith('project_'));
    expect(project.status, ItemStatus.active);
    expect(project.goalId, isNull);
    expect(project.description, isNull);
    expect(project.targetDate, isNull);
    expect(project.completedAt, isNull);
    expect(project.archivedAt, isNull);
  });

  test('create accepts an optional goalId', () {
    final project = Project.create(title: 'Website', goalId: 'goal_1');

    expect(project.goalId, 'goal_1');
  });
}
