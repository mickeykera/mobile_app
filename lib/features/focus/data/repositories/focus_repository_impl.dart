import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_clock.dart';
import '../../domain/entities/focus_session.dart';
import '../../domain/repositories/focus_repository.dart';
import '../../../progress/domain/services/progress_service.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/database/database.dart';
import '../../../../core/extensions/date_extensions.dart';

class FocusRepositoryImpl implements FocusRepository {
  final DatabaseService _database;
  final List<FocusSession> _sessions = [];

  /// Shared with the other repositories so the category buckets have one
  /// definition; it is a pure calculator, so a default instance is enough.
  final ProgressService _progress;

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

  FocusRepositoryImpl(this._database, [ProgressService? progress])
      : _progress = progress ?? const ProgressService();

  Future<void> _ensureLoaded() => _loading ??= _loadFromPrefs();

  Future<void> _loadFromPrefs() async {
    final sessionsJson = _database.getJsonList('focus_sessions') ?? [];
    for (final json in sessionsJson) {
      _sessions.add(_sessionFromJson(json));
    }
  }

  Future<void> _saveSessions() async {
    await _database.setJsonList(
        'focus_sessions', _sessions.map(_sessionToJson).toList());
  }

  FocusSession _sessionFromJson(Map<String, dynamic> json) {
    return FocusSession(
      id: json['id'] as String,
      mode: json['mode'] as String,
      workDurationMinutes: json['workDurationMinutes'] as int,
      breakDurationMinutes: json['breakDurationMinutes'] as int,
      longBreakDurationMinutes: json['longBreakDurationMinutes'] as int,
      sessionsBeforeLongBreak: json['sessionsBeforeLongBreak'] as int,
      completedSessions: json['completedSessions'] as int,
      totalWorkMinutes: json['totalWorkMinutes'] as int,
      totalBreakMinutes: json['totalBreakMinutes'] as int,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'] as String)
          : null,
      pausedAt: json['pausedAt'] != null
          ? DateTime.parse(json['pausedAt'] as String)
          : null,
      accumulatedWorkTime: json['accumulatedWorkTime'] != null
          ? Duration(milliseconds: json['accumulatedWorkTime'] as int)
          : null,
      accumulatedBreakTime: json['accumulatedBreakTime'] != null
          ? Duration(milliseconds: json['accumulatedBreakTime'] as int)
          : null,
      habitId: json['habitId'] as String?,
      projectName: json['projectName'] as String?,
      taskId: json['taskId'] as String?,
      projectId: json['projectId'] as String?,
      outcome: json['outcome'] as String?,
      focusRating: json['focusRating'] as int?,
      reflectionNotes: json['reflectionNotes'] as String?,
      isActive: json['isActive'] as bool,
      isPaused: json['isPaused'] as bool,
      isBreak: json['isBreak'] as bool,
    );
  }

  Map<String, dynamic> _sessionToJson(FocusSession session) {
    return {
      'id': session.id,
      'mode': session.mode,
      'workDurationMinutes': session.workDurationMinutes,
      'breakDurationMinutes': session.breakDurationMinutes,
      'longBreakDurationMinutes': session.longBreakDurationMinutes,
      'sessionsBeforeLongBreak': session.sessionsBeforeLongBreak,
      'completedSessions': session.completedSessions,
      'totalWorkMinutes': session.totalWorkMinutes,
      'totalBreakMinutes': session.totalBreakMinutes,
      'startedAt': session.startedAt.toIso8601String(),
      'endedAt': session.endedAt?.toIso8601String(),
      'pausedAt': session.pausedAt?.toIso8601String(),
      'accumulatedWorkTime': session.accumulatedWorkTime?.inMilliseconds,
      'accumulatedBreakTime': session.accumulatedBreakTime?.inMilliseconds,
      'habitId': session.habitId,
      'projectName': session.projectName,
      'taskId': session.taskId,
      'projectId': session.projectId,
      'outcome': session.outcome,
      'focusRating': session.focusRating,
      'reflectionNotes': session.reflectionNotes,
      'isActive': session.isActive,
      'isPaused': session.isPaused,
      'isBreak': session.isBreak,
    };
  }

  @override
  Future<Result<FocusSession?>> getActiveSession() async {
    await _ensureLoaded();
    try {
      final session = _sessions.where((s) => s.isActive).firstOrNull;
      return Either.right(session);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to fetch active session: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<FocusSession>> createSession(FocusSession session) async {
    await _ensureLoaded();
    try {
      _sessions.add(session);
      await _saveSessions();
      return Either.right(session);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to create session: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<FocusSession>> updateSession(FocusSession session) async {
    await _ensureLoaded();
    try {
      final index = _sessions.indexWhere((s) => s.id == session.id);
      if (index >= 0) {
        _sessions[index] = session;
        await _saveSessions();
      }
      return Either.right(session);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to update session: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> deleteSession(String id) async {
    await _ensureLoaded();
    try {
      _sessions.removeWhere((s) => s.id == id);
      await _saveSessions();
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to delete session: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<List<FocusSession>>> getSessions({
    DateTime? startDate,
    DateTime? endDate,
    String? habitId,
    int? limit,
  }) async {
    await _ensureLoaded();
    try {
      var sessions = _sessions.where((s) {
        if (startDate != null && s.startedAt.isBefore(startDate.startOfDay)) {
          return false;
        }
        if (endDate != null && s.startedAt.isAfter(endDate.endOfDay)) {
          return false;
        }
        if (habitId != null && s.habitId != habitId) return false;
        return true;
      }).toList();

      sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));

      if (limit != null) {
        sessions = sessions.take(limit).toList();
      }

      return Either.right(sessions);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to fetch sessions: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<int>> getTotalFocusMinutes(
      {DateTime? startDate, DateTime? endDate}) async {
    await _ensureLoaded();
    try {
      var sessions = _sessions.where((s) {
        if (startDate != null && s.startedAt.isBefore(startDate.startOfDay)) {
          return false;
        }
        if (endDate != null && s.startedAt.isAfter(endDate.endOfDay)) {
          return false;
        }
        return true;
      }).toList();

      final totalMinutes =
          sessions.fold<int>(0, (sum, s) => sum + s.totalWorkMinutes);
      return Either.right(totalMinutes);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to get total focus minutes: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Map<DateTime, int>>> getFocusHeatmap({int weeks = 12}) async {
    await _ensureLoaded();
    try {
      final endDate = AppClock.now();
      final startDate = endDate.subtract(Duration(days: weeks * 7));

      final sessions = _sessions
          .where((s) =>
              s.startedAt.isAfter(startDate.startOfDay) ||
              s.startedAt.isAtSameMomentAs(startDate.startOfDay))
          .where((s) =>
              s.startedAt.isBefore(endDate.endOfDay) ||
              s.startedAt.isAtSameMomentAs(endDate.endOfDay))
          .toList();

      final heatmap = <DateTime, int>{};
      for (final session in sessions) {
        final day = session.startedAt.startOfDay;
        heatmap[day] = (heatmap[day] ?? 0) + session.totalWorkMinutes;
      }
      return Either.right(heatmap);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to get focus heatmap: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Map<String, int>>> getFocusByCategory(
      {DateTime? startDate, DateTime? endDate}) async {
    await _ensureLoaded();
    try {
      var sessions = _sessions.where((s) {
        if (startDate != null && s.startedAt.isBefore(startDate.startOfDay)) {
          return false;
        }
        if (endDate != null && s.startedAt.isAfter(endDate.endOfDay)) {
          return false;
        }
        return true;
      }).toList();

      final byCategory = _progress.focusBreakdown(sessions).byCategory;
      return Either.right(byCategory);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to get focus by category: $e',
          originalError: e, stackTrace: st));
    }
  }
}

final focusRepositoryProvider = Provider<FocusRepository>((ref) {
  final database = ref.watch(databaseServiceProvider);
  return FocusRepositoryImpl(database, ref.watch(progressServiceProvider));
});
