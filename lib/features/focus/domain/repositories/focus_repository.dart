import '../../domain/entities/focus_session.dart';
import '../../../../core/errors/failures.dart';

abstract class FocusRepository {
  Future<Result<FocusSession?>> getActiveSession();
  Future<Result<FocusSession>> createSession(FocusSession session);
  Future<Result<FocusSession>> updateSession(FocusSession session);
  Future<Result<void>> deleteSession(String id);
  Future<Result<List<FocusSession>>> getSessions({
    DateTime? startDate,
    DateTime? endDate,
    String? habitId,
    int? limit,
  });
  Future<Result<int>> getTotalFocusMinutes(
      {DateTime? startDate, DateTime? endDate});
  Future<Result<Map<DateTime, int>>> getFocusHeatmap({int weeks = 12});
  Future<Result<Map<String, int>>> getFocusByCategory(
      {DateTime? startDate, DateTime? endDate});
}
