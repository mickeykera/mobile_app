import 'package:ascend/core/database/database.dart';
import 'package:ascend/core/extensions/date_extensions.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/habits/data/repositories/habit_repository_impl.dart';
import 'package:ascend/features/habits/domain/entities/habit.dart';
import 'package:ascend/features/progress/domain/services/progress_service.dart';
import 'package:ascend/features/recurring/domain/habit_task_identity.dart';
import 'package:ascend/features/recurring/domain/recurring_streak.dart';
import 'package:ascend/features/recurring/domain/recurring_work.dart';
import 'package:flutter_test/flutter_test.dart';

import 'l1_5_shared.dart';

/// Stage L1.5, steps 7 and 13: the read paths a cutover must not break.
///
/// The cutover contract held in `docs/ascend-stage-l1-5-cutover-prep.md` rests
/// on one ownership rule: `taskId == null` reads stored Habit counters,
/// `taskId != null` reads the Task occurrence log. These tests pin that rule to
/// the real reads the app shows — charts, streaks and the recurring list — and
/// prove them strong under legacy absence: for a migrated item, deleting the
/// legacy numbers changes nothing, because no read consults them. Nothing here
/// writes.
void main() {
  l1_5EnsureBinding();

  const progress = ProgressService();

  /// A pinned "now": a Wednesday, so seeds land on the two calendar days before
  /// it and the streak is unambiguous.
  final now = DateTime(2025, 6, 11, 9);
  final today = now.startOfDay;

  late DatabaseService database;

  setUp(() async {
    AppClock.debugSetNow(() => now);
    database = await l1_5FreshDatabase();
  });

  tearDown(() {
    AppClock.debugResetNow();
  });

  test('a migrated habit is read from its Task log, never its frozen counter',
      () async {
    final habit = await l1_5EligibleHabit(database, completions: 2);
    await l1_5MigrateOne(database, habit.id);

    final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);
    expect(await l1_5TaskRows(database, taskId), hasLength(2));

    // The legacy half, weakened as if the cutover had stopped maintaining it.
    final weakened = (await l1_5AllHabits(database)).single
        .copyWith(currentStreak: 0, longestStreak: 0, totalCompletions: 0);
    await HabitRepositoryImpl(database).updateHabit(weakened);

    final habits = await l1_5AllHabits(database);
    final tasks = await l1_5AllTasks(database);
    final rows = await l1_5AllCompletions(database);

    final map = progress.recurringStreaksByCategory(
      habits: habits,
      tasks: tasks,
      completions: rows,
    );

    expect(map['Mind'], RecurringStreak.forTaskLog(rows, taskId).currentStreak);
    expect(map['Mind'], 2);
  });

  test('an un-migrated habit is still read from its stored counters', () async {
    final habit = await l1_5EligibleHabit(database, completions: 1);
    // A counter advanced past the log, exactly what a legacy-only habit can be.
    await HabitRepositoryImpl(database)
        .updateHabit(habit.copyWith(currentStreak: 5));

    final habits = await l1_5AllHabits(database);
    final map = progress.recurringStreaksByCategory(
      habits: habits,
      tasks: [],
      completions: [],
    );

    expect(map['Mind'], 5);
  });

  test('completion counts never double-count a migrated half', () async {
    final habit = await l1_5EligibleHabit(database, completions: 2);
    await l1_5MigrateOne(database, habit.id);

    final habits = await l1_5AllHabits(database);
    final tasks = await l1_5AllTasks(database);
    final rows = await l1_5AllCompletions(database);

    final window = progress.recurringCompletionsByCategoryFromLog(
      habits: habits,
      completions: rows,
      startDate: today.subtract(const Duration(days: 6)),
      endDate: today,
    );
    expect(window['Mind'], 2, reason: 'migrated legacy rows must be skipped');

    final lifetime = progress.recurringCompletionsByCategory(
      habits: habits,
      tasks: tasks,
      completions: rows,
    );
    expect(lifetime['Mind'], 2);
  });

  test('the recurring list shows a migrated item once, as its Task', () async {
    final habit = await l1_5EligibleHabit(database, completions: 1);
    await l1_5MigrateOne(database, habit.id);

    final habits = await l1_5AllHabits(database);
    final tasks = await l1_5AllTasks(database);

    final work = recurringWorkFrom(habits: habits, tasks: tasks);
    expect(work, hasLength(1));
    expect(work.single.source, RecurringSource.recurringTask);
    expect(work.single.id, HabitTaskIdentity.taskIdForHabit(habit.id));
    expect(work.single.title, habit.title);
  });

  test('a migrated card still resolves metadata through the habit map',
      () async {
    final habit = await l1_5EligibleHabit(database, completions: 1);
    await l1_5MigrateOne(database, habit.id);

    final habits = await l1_5AllHabits(database);
    final tasks = await l1_5AllTasks(database);
    final byTaskId = <String, Habit>{
      for (final h in habits)
        if (h.taskId != null) h.taskId!: h,
    };

    expect(byTaskId, hasLength(1));
    final linked = byTaskId.values.single;
    expect(linked.title, tasks.single.title);
    expect(linked.category, tasks.single.category);
  });
}