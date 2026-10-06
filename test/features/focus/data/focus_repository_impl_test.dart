import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ascend/core/database/database.dart';
import 'package:ascend/features/focus/data/repositories/focus_repository_impl.dart';
import 'package:ascend/features/focus/domain/entities/focus_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = DatabaseService();
    await database.close();
    await database.initialize();
  });

  test('the work-item link fields round-trip through persistence', () async {
    final session = FocusSession.create(
      mode: 'Pomodoro',
      habitId: 'habit_1',
      projectName: 'Launch',
      taskId: 'task_1',
      projectId: 'project_1',
      outcome: 'Drafted the intro',
    );

    await FocusRepositoryImpl(database).createSession(session);

    final reloaded =
        (await FocusRepositoryImpl(database).getSessions()).right!.single;
    expect(reloaded.habitId, 'habit_1');
    expect(reloaded.projectName, 'Launch');
    expect(reloaded.taskId, 'task_1');
    expect(reloaded.projectId, 'project_1');
    expect(reloaded.outcome, 'Drafted the intro');
  });

  test('legacy session JSON without the link keys reads them as null',
      () async {
    final session = FocusSession.create(
      mode: 'Pomodoro',
      taskId: 'task_1',
      projectId: 'project_1',
      outcome: 'Notes',
    );
    await FocusRepositoryImpl(database).createSession(session);

    // Simulate a record written before schema v4 by dropping the new keys.
    final stored = database.getJsonList('focus_sessions')!;
    for (final row in stored) {
      row.remove('taskId');
      row.remove('projectId');
      row.remove('outcome');
    }
    await database.setJsonList('focus_sessions', stored);

    final reloaded =
        (await FocusRepositoryImpl(database).getSessions()).right!.single;
    expect(reloaded.taskId, isNull);
    expect(reloaded.projectId, isNull);
    expect(reloaded.outcome, isNull);
  });
}
