import '../../domain/entities/journal_entry.dart';
import '../../../../core/errors/failures.dart';

abstract class JournalRepository {
  Future<Result<JournalEntry?>> getEntryForDate(DateTime date, String type);
  Future<Result<List<JournalEntry>>> getEntries({
    DateTime? startDate,
    DateTime? endDate,
    String? type,
    List<String>? tags,
    int? limit,
  });
  Future<Result<JournalEntry>> createEntry(JournalEntry entry);
  Future<Result<JournalEntry>> updateEntry(JournalEntry entry);
  Future<Result<void>> deleteEntry(String id);
  Future<Result<Map<DateTime, int>>> getEntryHeatmap({int weeks = 12});
  Future<Result<Map<String, int>>> getMoodDistribution(
      {DateTime? startDate, DateTime? endDate});
  Future<Result<Map<String, int>>> getEnergyDistribution(
      {DateTime? startDate, DateTime? endDate});
  Future<Result<List<String>>> getAllTags();
}
