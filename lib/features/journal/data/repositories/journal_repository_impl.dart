import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/journal_entry.dart';
import '../../domain/repositories/journal_repository.dart';
import 'package:ascend/core/core.dart';

class JournalRepositoryImpl implements JournalRepository {
  final DatabaseService _database;
  final List<JournalEntry> _entries = [];
  bool _loaded = false;

  JournalRepositoryImpl(this._database);

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    await _loadFromPrefs();
    _loaded = true;
  }

  Future<void> _loadFromPrefs() async {
    final entriesJson = _database.getJsonList('journal_entries') ?? [];
    for (final json in entriesJson) {
      _entries.add(_entryFromJson(json));
    }
  }

  Future<void> _saveEntries() async {
    await _database.setJsonList(
        'journal_entries', _entries.map(_entryToJson).toList());
  }

  JournalEntry _entryFromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      type: json['type'] as String,
      date: DateTime.parse(json['date'] as String),
      responses: Map<String, String>.from(json['responses'] as Map),
      moodRating: json['moodRating'] as int?,
      energyRating: json['energyRating'] as int?,
      tags: (json['tags'] as List?)?.cast<String>(),
      gratitudeNote: json['gratitudeNote'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> _entryToJson(JournalEntry entry) {
    return {
      'id': entry.id,
      'type': entry.type,
      'date': entry.date.toIso8601String(),
      'responses': entry.responses,
      'moodRating': entry.moodRating,
      'energyRating': entry.energyRating,
      'tags': entry.tags,
      'gratitudeNote': entry.gratitudeNote,
      'createdAt': entry.createdAt?.toIso8601String(),
      'updatedAt': entry.updatedAt?.toIso8601String(),
    };
  }

  @override
  Future<Result<JournalEntry?>> getEntryForDate(
      DateTime date, String type) async {
    await _ensureLoaded();
    try {
      final entry = _entries
          .where(
              (e) => e.date.isAtSameMomentAs(date.startOfDay) && e.type == type)
          .firstOrNull;
      return Either.right(entry);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to fetch entry: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<List<JournalEntry>>> getEntries({
    DateTime? startDate,
    DateTime? endDate,
    String? type,
    List<String>? tags,
    int? limit,
  }) async {
    await _ensureLoaded();
    try {
      var entries = _entries.where((e) {
        if (startDate != null && e.date.isBefore(startDate.startOfDay)) {
          return false;
        }
        if (endDate != null && e.date.isAfter(endDate.endOfDay)) return false;
        if (type != null && e.type != type) return false;
        if (tags != null && tags.isNotEmpty) {
          if (e.tags == null || !e.tags!.any((t) => tags.contains(t))) {
            return false;
          }
        }
        return true;
      }).toList();

      entries.sort((a, b) => b.date.compareTo(a.date));

      if (limit != null) {
        entries = entries.take(limit).toList();
      }

      return Either.right(entries);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to fetch entries: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<JournalEntry>> createEntry(JournalEntry entry) async {
    await _ensureLoaded();
    try {
      _entries.add(entry);
      await _saveEntries();
      return Either.right(entry);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to create entry: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<JournalEntry>> updateEntry(JournalEntry entry) async {
    await _ensureLoaded();
    try {
      final index = _entries.indexWhere((e) => e.id == entry.id);
      if (index >= 0) {
        _entries[index] = entry;
        await _saveEntries();
      }
      return Either.right(entry);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to update entry: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> deleteEntry(String id) async {
    await _ensureLoaded();
    try {
      _entries.removeWhere((e) => e.id == id);
      await _saveEntries();
      return Either.right(null);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to delete entry: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Map<DateTime, int>>> getEntryHeatmap({int weeks = 12}) async {
    await _ensureLoaded();
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: weeks * 7));

      final entries = _entries
          .where((e) =>
              e.date.isAfter(startDate.startOfDay) ||
              e.date.isAtSameMomentAs(startDate.startOfDay))
          .where((e) =>
              e.date.isBefore(endDate.endOfDay) ||
              e.date.isAtSameMomentAs(endDate.endOfDay))
          .toList();

      final heatmap = <DateTime, int>{};
      for (final entry in entries) {
        final day = entry.date.startOfDay;
        heatmap[day] = (heatmap[day] ?? 0) + 1;
      }
      return Either.right(heatmap);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to get entry heatmap: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Map<String, int>>> getMoodDistribution(
      {DateTime? startDate, DateTime? endDate}) async {
    await _ensureLoaded();
    try {
      var entries = _entries.where((e) => e.moodRating != null).toList();

      if (startDate != null) {
        entries = entries
            .where((e) =>
                e.date.isAfter(startDate.startOfDay) ||
                e.date.isAtSameMomentAs(startDate.startOfDay))
            .toList();
      }
      if (endDate != null) {
        entries = entries
            .where((e) =>
                e.date.isBefore(endDate.endOfDay) ||
                e.date.isAtSameMomentAs(endDate.endOfDay))
            .toList();
      }

      final distribution = <String, int>{};
      final labels = ['Very Low', 'Low', 'Neutral', 'High', 'Very High'];
      for (final entry in entries) {
        if (entry.moodRating != null &&
            entry.moodRating! >= 1 &&
            entry.moodRating! <= 5) {
          final label = labels[entry.moodRating! - 1];
          distribution[label] = (distribution[label] ?? 0) + 1;
        }
      }
      return Either.right(distribution);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to get mood distribution: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Map<String, int>>> getEnergyDistribution(
      {DateTime? startDate, DateTime? endDate}) async {
    await _ensureLoaded();
    try {
      var entries = _entries.where((e) => e.energyRating != null).toList();

      if (startDate != null) {
        entries = entries
            .where((e) =>
                e.date.isAfter(startDate.startOfDay) ||
                e.date.isAtSameMomentAs(startDate.startOfDay))
            .toList();
      }
      if (endDate != null) {
        entries = entries
            .where((e) =>
                e.date.isBefore(endDate.endOfDay) ||
                e.date.isAtSameMomentAs(endDate.endOfDay))
            .toList();
      }

      final distribution = <String, int>{};
      final labels = ['Very Low', 'Low', 'Neutral', 'High', 'Very High'];
      for (final entry in entries) {
        if (entry.energyRating != null &&
            entry.energyRating! >= 1 &&
            entry.energyRating! <= 5) {
          final label = labels[entry.energyRating! - 1];
          distribution[label] = (distribution[label] ?? 0) + 1;
        }
      }
      return Either.right(distribution);
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to get energy distribution: $e',
          originalError: e, stackTrace: st));
    }
  }

  @override
  Future<Result<List<String>>> getAllTags() async {
    await _ensureLoaded();
    try {
      final tags = <String>{};
      for (final entry in _entries) {
        if (entry.tags != null) {
          tags.addAll(entry.tags!);
        }
      }
      return Either.right(tags.toList()..sort());
    } catch (e, st) {
      return Either.left(CacheFailure('Failed to get tags: $e',
          originalError: e, stackTrace: st));
    }
  }
}

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  final database = ref.watch(databaseServiceProvider);
  return JournalRepositoryImpl(database);
});
