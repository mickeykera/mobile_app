import 'package:ascend/core/database/database.dart';
import 'package:ascend/core/extensions/date_extensions.dart';
import 'package:ascend/core/utils/app_clock.dart';
import 'package:ascend/features/habits/data/repositories/habit_repository_impl.dart';
import 'package:ascend/features/recurring/domain/habit_task_identity.dart';
import 'package:ascend/features/recurring/domain/recurring_streak.dart';
import 'package:ascend/features/recurring/domain/recurring_work.dart';
import 'package:flutter_test/flutter_test.dart';

import 'l1_5_shared.dart';

/// Stage L1.5, steps 5 and 6: who owns recurrence, and who owns completion.
///
/// After migration the Task is the canonical recurring item:
///
///  * *completion* — a tick lands exactly one row in the Task occurrence log and
///    never touches the Habit's frozen counters or its own completion history;
///    un-ticking removes exactly that row;
///  * *recurrence* — the migrated Task's schedule is the due-calculator for the
///    pair. A legacy-side reschedule (habits screen snooze) that edits the Habit
///    only is visible as a divergence (contract finding D5): the item stays due
///    on the Task, which is definitively the item the read paths surface.
void main() {
  l1_5EnsureBinding();

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

  group('completion ownership at the repository boundary', () {
    test('a migrated tick writes the Task log only and freezes the Habit',
        () async {
      final habit =
          await l1_5EligibleHabit(database, completions: 2, seedEndDaysAgo: 1);
      await l1_5MigrateOne(database, habit.id);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);

      expect(await l1_5TaskRows(database, taskId), hasLength(2));
      expect(await l1_5HabitRows(database, habit.id), hasLength(2));

      final frozen = await l1_5ReloadHabit(database, habit.id);
      expect(frozen.currentStreak, 2);
      expect(frozen.totalCompletions, 2);

      // A tick today, the way the migrated card ticks it.
      await HabitRepositoryImpl(database).recordRecurringTaskOccurrence(
        taskId: taskId,
        date: today,
        count: 1,
      );

      // Exactly one new row, in the Task log.
      expect(await l1_5TaskRows(database, taskId), hasLength(3));
      expect(await l1_5HabitRows(database, habit.id), hasLength(2));

      // The Habit legitimately did not move.
      final after = await l1_5ReloadHabit(database, habit.id);
      expect(after.currentStreak, 2);
      expect(after.totalCompletions, 2);

      // The streak reads from the log the write just extended.
      final rows = await l1_5AllCompletions(database);
      expect(RecurringStreak.forTaskLog(rows, taskId).currentStreak, 3);
    });

    test('un-ticking removes the Task row only, same day', () async {
      final habit =
          await l1_5EligibleHabit(database, completions: 2, seedEndDaysAgo: 1);
      await l1_5MigrateOne(database, habit.id);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);

      await HabitRepositoryImpl(database).recordRecurringTaskOccurrence(
        taskId: taskId,
        date: today,
        count: 1,
      );
      expect(await l1_5TaskRows(database, taskId), hasLength(3));

      await HabitRepositoryImpl(database).deleteRecurringTaskOccurrence(
        taskId: taskId,
        date: today,
      );

      expect(await l1_5TaskRows(database, taskId), hasLength(2));
      expect(await l1_5HabitRows(database, habit.id), hasLength(2));
      final after = await l1_5ReloadHabit(database, habit.id);
      expect(after.currentStreak, 2);
    });
  });

  group('recurrence ownership', () {
    test('a legacy-side snooze diverges but the Task stays the due-calculator',
        () async {
      final habit = await l1_5EligibleHabit(
          database, frequency: 'Daily', completions: 0);
      await l1_5MigrateOne(database, habit.id);
      final taskId = HabitTaskIdentity.taskIdForHabit(habit.id);

      // The habits screen snoozes through the Habit (D5). The Task is not
      // touched: recurrence for the pair remains what it was copied as.
      final snoozed = (await l1_5AllHabits(database)).single
          .copyWith(snoozedUntil: now.add(const Duration(days: 2)));
      await HabitRepositoryImpl(database).updateHabit(snoozed);

      final task = await l1_5ReloadTask(database, taskId);
      expect(task.isDueOn(today, now: now), isTrue,
          reason: 'snooze is a Habit-side write and must not leak');

      // The read path surfaces the Task's schedule, so the item is still due.
      final work = recurringWorkFrom(
        habits: await l1_5AllHabits(database),
        tasks: await l1_5AllTasks(database),
      );
      expect(work.single.source, RecurringSource.recurringTask);
      expect(work.single.schedule.isDueOn(today, now: now), isTrue);
    });

    test('overrides copied at migration time are honored on the Task',
        () async {
      final habit = await l1_5EligibleHabit(
        database,
        frequency: 'Daily',
        completions: 0,
        dueAt: now.add(const Duration(days: 2)),
      );
      await l1_5MigrateOne(database, habit.id);
      final task = await l1_5ReloadTask(
          database, HabitTaskIdentity.taskIdForHabit(habit.id));

      // Day before the reschedule: held out. Reschedule day: due even though
      // recurrence would not have skipped it (it is Daily, so no skip happens —
      // the override window is about not forcing an early day).
      expect(task.isDueOn(today, now: now), isFalse);
      expect(task.isDueOn(today.add(const Duration(days: 1)), now: now),
          isFalse);
      expect(task.isDueOn(today.add(const Duration(days: 2)), now: now), isTrue);
      expect(task.isDueOn(today.add(const Duration(days: 3)), now: now), isTrue);
    });
  });
}