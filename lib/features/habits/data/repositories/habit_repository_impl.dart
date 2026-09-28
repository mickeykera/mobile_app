import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  bool _loaded = false;

  HabitRepositoryImpl(this._database);

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    await _loadFromPrefs();
    _loaded = true;
  }

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
      timeOfDay: json['timeOfDay'] as String,
      targetCount: json['targetCount'] as int,
      targetDuration: Duration(minutes: json['targetDurationMinutes'] as int),
      cue: json['cue'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      sortOrder: json['sortOrder'] as int,
      isArchived: json['isArchived'] as bool,
      streakFreezesUsed: json['streakFreezesUsed'] as int,
      lastCompletedAt: json['lastCompletedAt'] != null
          ? DateTime.parse(json['lastCompletedAt'] as String)
          : null,
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
      'currentStreak': habit.currentStreak,
      'longestStreak': habit.longestStreak,
      'totalCompletions': habit.totalCompletions,
    };
  }

  HabitCompletion _completionFromJson(Map<String, dynamic> json) {
    return HabitCompletion(
      id: json['id'] as String,
      habitId: json['habitId'] as String,
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
          habit.copyWith(isArchived: true, updatedAt: DateTime.now());
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
          habit.copyWith(isArchived: false, updatedAt: DateTime.now());
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
              habit.copyWith(sortOrder: i, updatedAt: DateTime.now());
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
      final endDate = DateTime.now();
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

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  final database = ref.watch(databaseServiceProvider);
  return HabitRepositoryImpl(database);
});
