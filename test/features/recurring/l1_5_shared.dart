import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ascend/core/database/database.dart';
import 'package:ascend/core/extensions/date_extensions.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/habits/data/repositories/habit_repository_impl.dart';
import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/habits/domain/entities/habit_completion.dart';
import 'package:ascend/features/recurring/domain/habit_task_identity.dart';
import 'package:ascend/features/recurring/domain/migration.dart';
import 'package:ascend/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';

/// Shared harness for Stage L1.5.
///
/// The L1.5 stage is join-up proof over the L1.3/L1.4 write model, so every
/// test here runs the real repositories over mocked SharedPreferences, exactly
/// like `l1_4_parity_hardening_test.dart`. The helpers below are the parts of
/// that suite's fixture that five L1.5 files need rather than one.
void l1_5EnsureBinding() {
  TestWidgetsFlutterBinding.ensureInitialized();
}

/// A blank persisted store with the app's cache warmed, the way [DatabaseService]
/// looks at the moment startup is done.
Future<DatabaseService> l1_5FreshDatabase() async {
  SharedPreferences.setMockInitialValues({});
  final database = DatabaseService();
  await database.close();
  await database.initialize();
  return database;
}

(HabitRepositoryImpl, TaskRepositoryImpl) l1_5Repos(
        DatabaseService database) =>
    (HabitRepositoryImpl(database), TaskRepositoryImpl(database));

Future<List<Habit>> l1_5AllHabits(DatabaseService database) async =>
    (await HabitRepositoryImpl(database)
            .getAllHabits(includeArchived: true))
        .fold((_) => const <Habit>[], (habits) => habits);

Future<List<Task>> l1_5AllTasks(DatabaseService database) async =>
    (await TaskRepositoryImpl(database).getAllTasks())
        .fold((_) => const <Task>[], (tasks) => tasks);

Future<List<HabitCompletion>> l1_5AllCompletions(
        DatabaseService database) async =>
    (await HabitRepositoryImpl(database).getAllCompletions())
        .fold((_) => const <HabitCompletion>[], (rows) => rows);

Future<Habit> l1_5ReloadHabit(DatabaseService database, String habitId) async =>
    l1_5AllHabits(database).then((habits) =>
        habits.singleWhere((h) => h.id == habitId));

Future<Task> l1_5ReloadTask(DatabaseService database, String taskId) async =>
    (await TaskRepositoryImpl(database).getTaskById(taskId))
        .fold((_) => null, (task) => task)!;

/// The Task occurrence rows for [taskId].
Future<List<HabitCompletion>> l1_5TaskRows(
    DatabaseService database, String taskId) async {
  final rows = await l1_5AllCompletions(database);
  return rows.where((c) => c.itemId == taskId && c.itemType == 'task').toList();
}

/// The legacy habit rows for [habitId].
Future<List<HabitCompletion>> l1_5HabitRows(
    DatabaseService database, String habitId) async {
  final rows = await l1_5AllCompletions(database);
  return rows
      .where((c) => c.itemId == habitId && c.itemType == 'habit')
      .toList();
}

/// A habit whose stored counters agree with its log, so the parity gate admits
/// it, carrying every field the boundary cares about.
Future<Habit> l1_5EligibleHabit(
  DatabaseService database, {
  String title = 'Read',
  String category = 'Mind',
  String description = '',
  int completions = 1,
  bool archived = false,
  String frequency = 'Daily',
  List<int> customWeekdays = const [],
  String? projectId,
  String? goalId,
  int targetCount = 1,
  int targetDurationMinutes = 0,
  String cue = '',
  String timeOfDay = 'Morning',
  int streakFreezesUsed = 0,
  DateTime? dueAt,
  DateTime? snoozedUntil,
  int seedEndDaysAgo = 0,
}) async {
  final habit = Habit.create(
    title: title,
    category: category,
    description: description,
    frequency: frequency,
    customWeekdays: customWeekdays,
    projectId: projectId,
    goalId: goalId,
    targetCount: targetCount,
    targetDuration: Duration(minutes: targetDurationMinutes),
    cue: cue,
    timeOfDay: timeOfDay,
  ).copyWith(
    streakFreezesUsed: streakFreezesUsed,
    dueAt: dueAt,
    snoozedUntil: snoozedUntil,
  );
  final stored = archived ? habit.copyWith(isArchived: true) : habit;

  final today = AppClock.now().startOfDay;
  final days = [
    for (var i = completions - 1; i >= 0; i--)
      today
          .subtract(Duration(days: i + seedEndDaysAgo))
          .add(const Duration(hours: 9)),
  ];

  var withCounters = stored;
  for (final day in days) {
    withCounters = withCounters.copyWithCompletion(
      completed: true,
      completionTime: day,
    );
  }

  final habitRepo = HabitRepositoryImpl(database);
  await habitRepo.createHabit(withCounters);
  for (final day in days) {
    await habitRepo.createCompletion(HabitCompletion(
      id: 'completion_seed_${withCounters.id}_${day.toIso8601String()}',
      habitId: withCounters.id,
      itemId: withCounters.id,
      itemType: 'habit',
      completedAt: day,
      count: 1,
    ));
  }
  return withCounters;
}

/// Runs the real migration state machine for one habit and returns the outcome,
/// refusing to continue if the habit was not admitted.
Future<HabitMigrationOutcome> l1_5MigrateOne(
    DatabaseService database, String habitId) async {
  final (habitRepo, taskRepo) = l1_5Repos(database);
  final outcome = (await MigrationService(habitRepo, taskRepo)
          .migrateHabits([habitId]))
      .single;
  return outcome;
}

/// The launch-time capability bridge, run the way startup runs it.
Future<CapabilitySyncReport> l1_5SyncCapabilities(DatabaseService database) async {
  final (habitRepo, taskRepo) = l1_5Repos(database);
  return MigrationService(habitRepo, taskRepo).syncTaskCapabilities();
}

/// A linked migrated pair without running the parity gate: a habit pointing at
/// a Task under its deterministic id. Useful when a test needs the migrated
/// *shape* but does so on a history-less habit.
Future<Habit> l1_5LinkedHabit(DatabaseService database, Task Function() task,
    {String title = 'Read', String category = 'Mind'}) async {
  final base = Habit.create(title: title, category: category);
  final linked = base.copyWith(
      taskId: HabitTaskIdentity.taskIdForHabit(base.id), title: title);
  final createdEmpty = task()
      .copyWith(id: linked.taskId!, createdAt: base.createdAt, title: title);
  await TaskRepositoryImpl(database).createTask(createdEmpty);
  return (await HabitRepositoryImpl(database).createHabit(linked))
      .getOrElse((_) => linked);
}