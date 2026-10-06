import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ascend/core/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // DatabaseService is a singleton; start every case from a clean, empty store.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseService().close();
  });

  test('initialize stamps the current schema version', () async {
    final database = DatabaseService();
    await database.initialize();

    expect(DatabaseService.currentSchemaVersion, 5);
    expect(database.getSchemaVersion(), DatabaseService.currentSchemaVersion);
  });

  test('an existing version is not overwritten', () async {
    SharedPreferences.setMockInitialValues({'schema_version': 99});

    final database = DatabaseService();
    await database.initialize();

    expect(database.getSchemaVersion(), 99);
  });

  test('an install with no stamp reads as version 0', () {
    expect(DatabaseService().getSchemaVersion(), 0);
  });

  test('v1 migrates forward, adding empty goal, project, and task collections',
      () async {
    SharedPreferences.setMockInitialValues({
      'schema_version': 1,
      'habits': '[{"id":"habit_1"}]',
    });

    final database = DatabaseService();
    await database.initialize();

    expect(database.getSchemaVersion(), 5);
    expect(database.getJsonList(DatabaseService.goalsKey), isEmpty);
    expect(database.getJsonList(DatabaseService.projectsKey), isEmpty);
    expect(database.getJsonList(DatabaseService.tasksKey), isEmpty);
    // The habits collection already exists from v1; migration preserves it.
    expect(database.getJsonList(DatabaseService.habitsKey), hasLength(1));
  });

  test('v2 migrates to the current version without rewriting habit records',
      () async {
    const habits = '[{"id":"habit_1","title":"Read"}]';
    SharedPreferences.setMockInitialValues({
      'schema_version': 2,
      'habits': habits,
    });

    final database = DatabaseService();
    await database.initialize();

    expect(database.getSchemaVersion(), 5);
    // The link fields are optional, so the stored habits must be byte-identical.
    expect(database.getString('habits'), habits);
  });

  test('v3 adds the task collection without rewriting existing rows', () async {
    const completions = '[{"id":"completion_1","habitId":"habit_1"}]';
    const focus = '[{"id":"session_1"}]';
    SharedPreferences.setMockInitialValues({
      'schema_version': 3,
      'habit_completions': completions,
      'focus_sessions': focus,
    });

    final database = DatabaseService();
    await database.initialize();

    expect(database.getSchemaVersion(), 5);
    expect(database.getJsonList(DatabaseService.tasksKey), isEmpty);
    // The new completion/focus fields are optional, so the stored rows must be
    // byte-identical after migration.
    expect(database.getString('habit_completions'), completions);
    expect(database.getString('focus_sessions'), focus);
  });

  test('v4 adds the habits collection key if absent', () async {
    SharedPreferences.setMockInitialValues({
      'schema_version': 4,
      'habits': '[{"id":"habit_1","title":"Read"}]',
    });

    final database = DatabaseService();
    await database.initialize();

    expect(database.getSchemaVersion(), 5);
    expect(database.getJsonList(DatabaseService.habitsKey), isNotEmpty);
  });

  test('a fresh install ends at the current version with every collection',
      () async {
    final database = DatabaseService();
    await database.initialize();

    expect(database.getJsonList(DatabaseService.goalsKey), isNotNull);
    expect(database.getJsonList(DatabaseService.projectsKey), isNotNull);
    expect(database.getJsonList(DatabaseService.tasksKey), isNotNull);
    expect(database.getJsonList(DatabaseService.habitsKey), isNotNull);
  });

  test('migration leaves existing persisted data untouched', () async {
    const habits = '[{"id":"habit_1","title":"Read"}]';
    const completions = '[{"id":"completion_1","habitId":"habit_1"}]';
    const focus = '[{"id":"session_1"}]';
    const journal = '[{"id":"entry_1"}]';
    SharedPreferences.setMockInitialValues({
      'schema_version': 1,
      'habits': habits,
      'habit_completions': completions,
      'focus_sessions': focus,
      'journal_entries': journal,
    });

    final database = DatabaseService();
    await database.initialize();

    expect(database.getString('habits'), habits);
    expect(database.getString('habit_completions'), completions);
    expect(database.getString('focus_sessions'), focus);
    expect(database.getString('journal_entries'), journal);
  });

  test('migration is idempotent and never clobbers seeded collections',
      () async {
    SharedPreferences.setMockInitialValues({'schema_version': 1});
    final database = DatabaseService();
    await database.initialize();

    // The user creates a goal after the first migration pass.
    await database.setJsonList(DatabaseService.goalsKey, [
      {'id': 'goal_1', 'title': 'Mine'},
    ]);
    await database.setJsonList(DatabaseService.tasksKey, [
      {'id': 'task_1', 'title': 'Mine'},
    ]);

    // A later launch re-runs initialization; the stored rows must survive.
    await database.close();
    await database.initialize();
    await database.ensureSchemaVersion();

    expect(database.getSchemaVersion(), 5);
    expect(database.getJsonList(DatabaseService.goalsKey), [
      {'id': 'goal_1', 'title': 'Mine'},
    ]);
    expect(database.getJsonList(DatabaseService.tasksKey), [
      {'id': 'task_1', 'title': 'Mine'},
    ]);
  });
}
