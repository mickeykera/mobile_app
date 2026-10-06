import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_clock.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_completion.dart';
import '../../domain/repositories/habit_repository.dart';
import '../../../../core/database/database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/extensions/date_extensions.dart';

class HabitRepositoryImpl implements HabitRepository {
  final DatabaseService _database;
  final List<Habit> _habits = [];
  final List<HabitCompletion> _completions = [];

  /// Memoised load, not a `bool` guard.
  ///
  /// `if (_loaded) return; await _loadFromPrefs(); _loaded = true;` loses the
  /// race: two callers both read `_loaded == false` before either finishes the
  /// `await`, so both run the load and both append to the cache. That doubles
  /// every row - one stored habit came back as two with the same id.
  ///
  /// Holding the `Future` makes the guard idempotent, because `??=` resolves
  /// the first caller's future for everyone who arrives while it is in flight.
  Future<void>? _loading;

  HabitRepositoryImpl(this._database);

  Future<void> _ensureLoaded() => _loading ??= _loadFromPrefs();

  Future<void> _loadFromPrefs() async {
    final habitsJson = _database.getJsonList('habits') ?? [];
    for (final json in habitsJson) {
      _habits.add(_habitFromJson(json));
    }

    final completionsJson = _database.getJsonList('habit_completions') ?? [];
    for (final json in completionsJson) {
      _completions.add(_completionFromJson(json));
    }
  }

  Future<void> _saveHabits() async {
    await _database.setJsonList('habits', _habits.map(_habitToJson).toList());
  }

  Future<void> _saveCompletions() async {
    await _database.setJsonList(
        'habit_completions', _completions.map(_completionToJson).toList());
  }

  Habit _habitFromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      frequency: json['frequency'] as String,
      customWeekdays: (json['customWeekdays'] as List).cast<int>(),
      // The five capability keys are read tolerantly as of Stage L1.3. The
      // schema migrations have never rewritten habit records (the v2 test
      // asserts the stored string is byte-identical), so a record written by a
      // build that predates any of these keys is still in the wild and must
      // load with the legacy default rather than throw. That is what makes a
      // "completely old habit record" survivable end to end: it reads, it
      // migrates, and the missing capability lands on the Task as the default
      // exactly as it would have on the Habit.
      timeOfDay: json['timeOfDay'] as String? ?? AppConstants.timeOfDayMorning,
      targetCount: json['targetCount'] as int? ?? 1,
      targetDuration:
          Duration(minutes: json['targetDurationMinutes'] as int? ?? 0),
      cue: json['cue'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      sortOrder: json['sortOrder'] as int,
      isArchived: json['isArchived'] as bool,
      streakFreezesUsed: json['streakFreezesUsed'] as int? ?? 0,
      lastCompletedAt: json['lastCompletedAt'] != null
          ? DateTime.parse(json['lastCompletedAt'] as String)
          : null,
      dueAt: json['dueAt'] != null
          ? DateTime.parse(json['dueAt'] as String)
          : null,
      snoozedUntil: json['snoozedUntil'] != null
          ? DateTime.parse(json['snoozedUntil'] as String)
          : null,
      projectId: json['projectId'] as String?,
      goalId: json['goalId'] as String?,
      // Added in Stage L0. This field existed on the entity from the start but
      // was never serialised, so every habit read back with `taskId == null`
      // and `updateHabit(habit.copyWith(taskId: ...))` silently discarded the
      // link. That made the migration non-idempotent across process restarts:
      // each launch would re-run it and create another Task. Absent reads as
      // null, so records written before this field existed load unchanged.
      taskId: json['taskId'] as String?,
      currentStreak: json['currentStreak'] as int,
      longestStreak: json['longestStreak'] as int,
      totalCompletions: json['totalCompletions'] as int,
    );
  }

  Map<String, dynamic> _habitToJson(Habit habit) {
    return {
      'id': habit.id,
      'title': habit.title,
      'description': habit.description,
      'category': habit.category,
      'frequency': habit.frequency,
      'customWeekdays': habit.customWeekdays,
      'timeOfDay': habit.timeOfDay,
      'targetCount': habit.targetCount,
      'targetDurationMinutes': habit.targetDuration.inMinutes,
      'cue': habit.cue,
      'createdAt': habit.createdAt.toIso8601String(),
      'updatedAt': habit.updatedAt.toIso8601String(),
      'sortOrder': habit.sortOrder,
      'isArchived': habit.isArchived,
      'streakFreezesUsed': habit.streakFreezesUsed,
      'lastCompletedAt': habit.lastCompletedAt?.toIso8601String(),
      'dueAt': habit.dueAt?.toIso8601String(),
      'snoozedUntil': habit.snoozedUntil?.toIso8601String(),
      'projectId': habit.projectId,
      'goalId': habit.goalId,
      // Added in Stage L0 - see the note in [_habitFromJson]. Without this the
      // migration link was dropped on every save and the migration re-ran from
      // scratch on the next launch.
      'taskId': habit.taskId,
      'currentStreak': habit.currentStreak,
      'longestStreak': habit.longestStreak,
      'totalCompletions': habit.totalCompletions,
    };
  }

  HabitCompletion _completionFromJson(Map<String, dynamic> json) {
    final habitId = json['habitId'] as String?;
    return HabitCompletion(
      id: json['id'] as String,
      habitId: habitId,
      itemId: (json['itemId'] as String?) ?? habitId,
      itemType:
          (json['itemType'] as String?) ?? (habitId != null ? 'habit' : null),
      completedAt: DateTime.parse(json['completedAt'] as String),
      count: json['count'] as int,
      duration: json['durationMinutes'] != null
          ? Duration(minutes: json['durationMinutes'] as int)
          : null,
      note: json['note'] as String?,
      moodRating: json['moodRating'] as int?,
      energyRating: json['energyRating'] as int?,
    );
  }

  Map<String, dynamic> _completionToJson(HabitCompletion completion) {
    return {
      'id': completion.id,
      'habitId': completion.habitId,
      'itemId': completion.itemId ?? completion.habitId,
      'itemType':
          completion.itemType ?? (completion.habitId != null ? 'habit' : null),
      'completedAt': completion.completedAt.toIso8601String(),
      'count': completion.count,
      'durationMinutes': completion.duration?.inMinutes,
      'note': completion.note,
      'moodRating': completion.moodRating,
      'energyRating': completion.energyRating,
    };
  }

  Habit? _findHabit(String id) {
    for (final habit in _habits) {
      if (habit.id == id) return habit;
    }
    return null;
  }

  @override
  Future<Result<List<Habit>>> getAllHabits(
      {bool includeArchived = false}) async {
    await _ensureLoaded();
    try {
      final habits =
          _habits.where((h) => includeArchived || !h.isArchived).toList();
      habits.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return Either.right(habits);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to fetch habits: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Habit?>> getHabitById(String id) async {
    await _ensureLoaded();
    try {
      final habit = _findHabit(id);
      return Either.right(habit);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to fetch habit: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Habit>> createHabit(Habit habit) async {
    await _ensureLoaded();
    try {
      _habits.add(habit);
      await _saveHabits();
      return Either.right(habit);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to create habit: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Habit>> updateHabit(Habit habit) async {
    await _ensureLoaded();
    try {
      final index = _habits.indexWhere((h) => h.id == habit.id);
      if (index >= 0) {
        _habits[index] = habit;
        await _saveHabits();
      }
      return Either.right(habit);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to update habit: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> deleteHabit(String id) async {
    await _ensureLoaded();
    try {
      _habits.removeWhere((h) => h.id == id);
      _completions.removeWhere((c) => c.habitId == id);
      await _saveHabits();
      await _saveCompletions();
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to delete habit: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> archiveHabit(String id) async {
    await _ensureLoaded();
    try {
      final habit = _findHabit(id);
      if (habit == null) {
        return Either.left(const NotFoundFailure('Habit not found'));
      }

      final updated =
          habit.copyWith(isArchived: true, updatedAt: AppClock.now());
      final index = _habits.indexWhere((h) => h.id == id);
      _habits[index] = updated;
      await _saveHabits();
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to archive habit: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> unarchiveHabit(String id) async {
    await _ensureLoaded();
    try {
      final habit = _findHabit(id);
      if (habit == null) {
        return Either.left(const NotFoundFailure('Habit not found'));
      }

      final index = _habits.indexWhere((h) => h.id == id);
      _habits[index] =
          habit.copyWith(isArchived: false, updatedAt: AppClock.now());
      await _saveHabits();
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to unarchive habit: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> reorderHabits(List<String> habitIds) async {
    await _ensureLoaded();
    try {
      for (int i = 0; i < habitIds.length; i++) {
        final habit = _findHabit(habitIds[i]);
        if (habit != null) {
          final updated =
              habit.copyWith(sortOrder: i, updatedAt: AppClock.now());
          final index = _habits.indexWhere((h) => h.id == habit.id);
          _habits[index] = updated;
        }
      }
      await _saveHabits();
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to reorder habits: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<List<HabitCompletion>>> getCompletionsForHabit(
    String habitId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await _ensureLoaded();
    try {
      var completions =
          _completions.where((c) => c.habitId == habitId).toList();

      if (startDate != null) {
        completions = completions
            .where((c) =>
                c.completedAt.isAfter(startDate.startOfDay) ||
                c.completedAt.isAtSameMomentAs(startDate.startOfDay))
            .toList();
      }
      if (endDate != null) {
        completions = completions
            .where((c) =>
                c.completedAt.isBefore(endDate.endOfDay) ||
                c.completedAt.isAtSameMomentAs(endDate.endOfDay))
            .toList();
      }

      completions.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      return Either.right(completions);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to fetch completions: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<List<HabitCompletion>>> getCompletionsForDate(
      DateTime date) async {
    await _ensureLoaded();
    try {
      final start = date.startOfDay;
      final end = date.endOfDay;
      final completions = _completions
          .where((c) =>
              c.completedAt.isAfter(start) ||
              c.completedAt.isAtSameMomentAs(start))
          .where((c) =>
              c.completedAt.isBefore(end) ||
              c.completedAt.isAtSameMomentAs(end))
          .toList();
      completions.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      return Either.right(completions);
    } catch (e, st) {
      return Either.left(CacheFailure(
          'Failed to fetch completions for date: $e',
          originalError: e,
          stackTrace: st));
    }
  }

  @override
  Future<Result<List<HabitCompletion>>> getAllCompletions() async {
    await _ensureLoaded();
    try {
      // Unfiltered read of the same cached list the range calls filter, so this
      // costs no extra storage work. Sorted oldest-first to match
      // getCompletionsForHabit, which the parity report and the streak
      // derivation both read as a history.
      final completions = [..._completions]
        ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
      return Either.right(completions);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to fetch all completions: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<List<HabitCompletion>>> getCompletionsInRange(
      DateTime start, DateTime end) async {
    await _ensureLoaded();
    try {
      final from = start.startOfDay;
      final to = end.endOfDay;
      final completions = _completions
          .where((c) => !c.completedAt.isBefore(from))
          .where((c) => !c.completedAt.isAfter(to))
          .toList();
      completions.sort((a, b) => a.completedAt.compareTo(b.completedAt));
      return Either.right(completions);
    } catch (e, st) {
      return Either.left(CacheFailure(
          'Failed to fetch completions for range: $e',
          originalError: e,
          stackTrace: st));
    }
  }

  @override
  Future<Result<HabitCompletion>> createCompletion(
      HabitCompletion completion) async {
    await _ensureLoaded();
    try {
      _completions.add(completion);
      await _saveCompletions();
      return Either.right(completion);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to create completion: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> deleteCompletion(String id) async {
    await _ensureLoaded();
    try {
      _completions.removeWhere((c) => c.id == id);
      await _saveCompletions();
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to delete completion: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<HabitCompletion>> recordRecurringTaskOccurrence({
    required String taskId,
    required DateTime date,
    required int count,
    Duration? duration,
    String? note,
    int? moodRating,
    int? energyRating,
  }) async {
    await _ensureLoaded();
    try {
      final dayStart = date.startOfDay;
      final dayEnd = date.endOfDay;

      // Same-day dedupe: check if a row already exists for this task+date
      HabitCompletion? existing;
      for (final c in _completions) {
        if (c.itemId == taskId &&
            c.itemType == 'task' &&
            !c.completedAt.isBefore(dayStart) &&
            !c.completedAt.isAfter(dayEnd)) {
          existing = c;
          break;
        }
      }

      if (existing != null) {
        return Either.right(existing);
      }

      final completion = HabitCompletion.create(
        habitId: null,
        itemId: taskId,
        itemType: 'task',
        count: count,
        duration: duration,
        note: note,
        moodRating: moodRating,
        energyRating: energyRating,
      );

      // Override completedAt to be the specific date with current time-of-day
      final now = AppClock.now();
      final completedAt = DateTime(
        date.year,
        date.month,
        date.day,
        now.hour,
        now.minute,
      );
      final fixedCompletion = completion.copyWith(completedAt: completedAt);

      _completions.add(fixedCompletion);
      await _saveCompletions();
      return Either.right(fixedCompletion);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to record task occurrence: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> deleteRecurringTaskOccurrence({
    required String taskId,
    required DateTime date,
  }) async {
    await _ensureLoaded();
    try {
      final dayStart = date.startOfDay;
      final dayEnd = date.endOfDay;

      final beforeCount = _completions.length;
      _completions.removeWhere(
        (c) =>
            c.itemId == taskId &&
            c.itemType == 'task' &&
            !c.completedAt.isBefore(dayStart) &&
            !c.completedAt.isAfter(dayEnd),
      );

      if (_completions.length < beforeCount) {
        await _saveCompletions();
      }
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to delete task occurrence: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> reconcileHabitToTask({
    required String habitId,
    required String taskId,
  }) async {
    await _ensureLoaded();
    try {
      // 1. Load the authoritative Habit completion history (all rows with ownerId == habitId)
      final habitCompletions = _completions
          .where((c) => c.ownerId == habitId && c.isHabitCompletion)
          .toList();

      // 2. Load the corresponding Task's current occurrence rows
      final taskCompletions = _completions
          .where((c) => c.itemId == taskId && c.itemType == 'task')
          .toList();

      // Build a map of existing Task completions by date for quick lookup
      final taskByDate = <DateTime, HabitCompletion>{};
      for (final c in taskCompletions) {
        taskByDate[c.completedAt.startOfDay] = c;
      }

      // 3. For each Habit completion row, ensure a matching Task row exists
      for (final habitCompletion in habitCompletions) {
        final day = habitCompletion.completedAt.startOfDay;
        final existingTaskCompletion = taskByDate[day];

        if (existingTaskCompletion == null) {
          // Create missing Task occurrence row
          final newCompletion = HabitCompletion.create(
            habitId: null,
            itemId: taskId,
            itemType: 'task',
            count: habitCompletion.count,
            duration: habitCompletion.duration,
            note: habitCompletion.note,
            moodRating: habitCompletion.moodRating,
            energyRating: habitCompletion.energyRating,
          );
          // Use the same completedAt as the Habit row
          final fixedCompletion = newCompletion.copyWith(
            completedAt: habitCompletion.completedAt,
          );
          _completions.add(fixedCompletion);
        }
        // If it exists, we could update count/duration/note to match Habit,
        // but per spec we treat Habit as source of truth for content too.
        // For now we leave existing rows as-is (idempotent).
      }

      // 4. For each Task row with no corresponding Habit row, delete it (orphaned)
      final habitDates =
          habitCompletions.map((c) => c.completedAt.startOfDay).toSet();
      final orphaned = taskCompletions
          .where((c) => !habitDates.contains(c.completedAt.startOfDay))
          .toList();

      for (final orphan in orphaned) {
        _completions.removeWhere((c) => c.id == orphan.id);
      }

      await _saveCompletions();
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to reconcile habit to task: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<int>> getCurrentStreak(String habitId) async {
    await _ensureLoaded();
    try {
      final habit = _findHabit(habitId);
      if (habit == null) {
        return Either.left(const NotFoundFailure('Habit not found'));
      }
      return Either.right(habit.currentStreak);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to get streak: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<int>> getLongestStreak(String habitId) async {
    await _ensureLoaded();
    try {
      final habit = _findHabit(habitId);
      if (habit == null) {
        return Either.left(const NotFoundFailure('Habit not found'));
      }
      return Either.right(habit.longestStreak);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to get longest streak: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<double>> getCompletionRate(String habitId,
      {DateTime? startDate, DateTime? endDate}) async {
    await _ensureLoaded();
    try {
      final habit = _findHabit(habitId);
      if (habit == null) {
        return Either.left(const NotFoundFailure('Habit not found'));
      }
      // `startDate`/`endDate` are accepted for interface symmetry with the
      // other range-aware queries but are deliberately not applied: the
      // `completionRate` on the entity is a lifetime figure measured from
      // `createdAt`, and narrowing it to an arbitrary window would silently
      // change what the number means to any caller that starts passing dates.
      // A ranged rate needs its own definition, so this leaves a trace rather
      // than quietly ignoring the arguments.
      if (startDate != null || endDate != null) {
        return Either.left(const ValidationFailure(
            'getCompletionRate is a lifetime rate and does not accept a date range'));
      }
      return Either.right(habit.completionRate);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to get completion rate: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Map<DateTime, int>>> getCompletionHeatmap(String habitId,
      {int weeks = 12}) async {
    await _ensureLoaded();
    try {
      final endDate = AppClock.now();
      final startDate = endDate.subtract(Duration(days: weeks * 7));

      final completions = _completions
          .where((c) => c.habitId == habitId)
          .where((c) =>
              c.completedAt.isAfter(startDate.startOfDay) ||
              c.completedAt.isAtSameMomentAs(startDate.startOfDay))
          .where((c) =>
              c.completedAt.isBefore(endDate.endOfDay) ||
              c.completedAt.isAtSameMomentAs(endDate.endOfDay))
          .toList();

      final heatmap = <DateTime, int>{};
      for (final completion in completions) {
        final day = completion.completedAt.startOfDay;
        heatmap[day] = (heatmap[day] ?? 0) + completion.count;
      }
      return Either.right(heatmap);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to get heatmap: $e',
          originalError: e, stackTrace: st));
    }
  }
}
