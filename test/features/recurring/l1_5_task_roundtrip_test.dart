import 'dart:convert';

import 'package:ascend/core/database/database.dart';
import 'package:ascend/core/extensions/date_extensions.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/habits/data/repositories/habit_repository_impl.dart';
import 'package:ascend/features/recurring/domain/habit_task_identity.dart';
import 'package:ascend/features/recurring/domain/migration.dart';
import 'package:ascend/features/tasks/domain/entities/task.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_schedule.dart';
import 'package:ascend/features/tasks/domain/value_objects/task_status.dart';
import 'package:flutter_test/flutter_test.dart';

import 'l1_5_shared.dart';

/// Stage L1.5, step 4: the completeness round-trip the cutover leans on.
///
/// A write-ownership cutover is only sound if the Task already carries every
/// field of the legacy pair it would replace. These tests prove three things
/// about the production construct — the real [MigrationService] writing to the
/// real repositories over mocked storage — by reading every field back:
///
///  1. a fully-customised habit migrates onto a Task that round-trips every
///     owned field against a byte-equal legacy pair;
///  2. a Task written without capability keys (the Stage L0 shape) still reads
///     as capable of representing that habit, via the shared defaults;
///  3. the migrated schedule and the habit's recurrence are the same due-ness,
///     day for day, over a window — including the `dueAt`/`snoozedUntil`
///     overrides that live on top of the rule.
void main() {
  l1_5EnsureBinding();

  final now = DateTime(2025, 6, 11, 9);
  late DatabaseService database;

  setUp(() async {
    AppClock.debugSetNow(() => now);
    database = await l1_5FreshDatabase();
  });

  tearDown(() {
    AppClock.debugResetNow();
  });

  List<Map<String, dynamic>> persistedTasks() =>
      database.getJsonList(DatabaseService.tasksKey) ?? const [];

  void stripTaskKey(String taskId, String key) {
    final stored = persistedTasks();
    for (final task in stored) {
      if (task['id'] != taskId) continue;
      task.remove(key);
    }
    database.setJsonList(DatabaseService.tasksKey, stored);
  }

  group('completeness of the migrated Task', () {
    test('every owned field of the legacy pair round-trips onto the Task',
        () async {
      final habit = await l1_5EligibleHabit(
        database,
        title: 'Deep work',
        category: 'Work',
        description: 'Two focused sessions',
        frequency: 'Custom',
        customWeekdays: [1, 3, 5],
        projectId: 'proj_7',
        goalId: 'goal_9',
        targetCount: 3,
        targetDurationMinutes: 45,
        cue: 'After standup',
        timeOfDay: 'Evening',
        streakFreezesUsed: 2,
        dueAt: DateTime(2025, 6, 13, 8),
        snoozedUntil: DateTime(2025, 6, 12, 8),
      );

      final outcome = await l1_5MigrateOne(database, habit.id);
      expect(outcome.verification.isVerified, isTrue,
          reason: outcome.verification.failures.join('; '));

      final task =
          await l1_5ReloadTask(database, HabitTaskIdentity.taskIdForHabit(habit.id));
      final expected = Task.create(
        title: habit.title,
        category: habit.category,
        description: habit.description,
        schedule: habit.recurringSchedule,
        projectId: habit.projectId,
        goalId: habit.goalId,
      ).copyWith(
        status: habit.isArchived ? TaskStatus.archived : TaskStatus.todo,
      );

      expect(task.title, expected.title);
      expect(task.category, expected.category);
      expect(task.description, expected.description);
      expect(task.projectId, expected.projectId);
      expect(task.goalId, expected.goalId);
      expect(task.status, expected.status);
      expect(jsonEncode(task.schedule.toJson()),
          jsonEncode(expected.schedule.toJson()));

      expect(LegacyHabitCapabilities.fromTask(task),
          LegacyHabitCapabilities.fromHabit(habit));
    });
  });

  group('capability defaults', () {
    test('a Task with no capability keys reads as a default habit',
        () async {
      final habit = await l1_5EligibleHabit(database, completions: 0);
      final outcome = await l1_5MigrateOne(database, habit.id);
      final taskId = outcome.taskId!;

      // Stage L0 wrote no capability keys. Simulate that shape.
      for (final key in const [
        'targetCount',
        'targetDurationMinutes',
        'cue',
        'timeOfDay',
        'streakFreezesUsed'
      ]) {
        stripTaskKey(taskId, key);
      }

      final task = await l1_5ReloadTask(database, taskId);
      expect(LegacyHabitCapabilities.fromTask(task),
          LegacyHabitCapabilities.fromHabit(habit));
    });
  });

  group('schedule equivalence', () {
    test('due-ness agrees day for day with the habit it was copied from',
        () async {
      final habit = await l1_5EligibleHabit(
        database,
        frequency: 'Weekdays',
        completions: 0,
        dueAt: DateTime(2025, 6, 12, 8),
        snoozedUntil: DateTime(2025, 6, 13, 8),
      );
      await l1_5MigrateOne(database, habit.id);
      final task = await l1_5ReloadTask(
          database, HabitTaskIdentity.taskIdForHabit(habit.id));

      expect(task.schedule, isA<Recurring>());
      expect(jsonEncode(task.schedule.toJson()),
          jsonEncode(habit.recurringSchedule.toJson()));

      // Two weeks either side of the overrides, compared field by field.
      for (var i = -7; i <= 14; i++) {
        final day = now.startOfDay.add(Duration(days: i));
        expect(task.isDueOn(day, now: now), habit.isDueOnDate(day),
            reason: 'disagreement on day $i');
      }
    });

    test('a reschedule of the habit never leaks past the Task boundary',
        () async {
      final habit = await l1_5EligibleHabit(
          database, frequency: 'Daily', completions: 0);
      await l1_5MigrateOne(database, habit.id);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);

      // The legacy UI reschedules through the habit ("snooze"): D5 in the
      // cutover contract. The Task keeps the schedule it was copied with.
      final rescheduled = (await l1_5AllHabits(database)).single
          .copyWith(snoozedUntil: now.add(const Duration(days: 3)));
      await HabitRepositoryImpl(database).updateHabit(rescheduled);

      final task = await l1_5ReloadTask(database, taskId);
      expect(task.schedule, isA<Recurring>());
      final recurring = task.schedule as Recurring;
      expect(recurring.snoozedUntil, isNull);
      expect(recurring.rule, const DailyRecurrence());
    });
  });
}