import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/date_utils.dart';

part 'journal_entry.freezed.dart';

@freezed
abstract class JournalEntry with _$JournalEntry {
  const factory JournalEntry({
    required String id,
    required String type,
    required DateTime date,
    required Map<String, String> responses,
    int? moodRating,
    int? energyRating,
    List<String>? tags,
    String? gratitudeNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _JournalEntry;

  const JournalEntry._();

  factory JournalEntry.createMorning({
    required DateTime date,
    required Map<String, String> responses,
    int? moodRating,
    int? energyRating,
    List<String>? tags,
    String? gratitudeNote,
  }) {
    final now = DateTime.now();
    return JournalEntry(
      id: 'entry_${now.millisecondsSinceEpoch}',
      type: 'Morning',
      date: date.startOfDay,
      responses: responses,
      moodRating: moodRating,
      energyRating: energyRating,
      tags: tags,
      gratitudeNote: gratitudeNote,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory JournalEntry.createEvening({
    required DateTime date,
    required Map<String, String> responses,
    int? moodRating,
    int? energyRating,
    List<String>? tags,
    String? gratitudeNote,
  }) {
    final now = DateTime.now();
    return JournalEntry(
      id: 'entry_${now.millisecondsSinceEpoch}',
      type: 'Evening',
      date: date.startOfDay,
      responses: responses,
      moodRating: moodRating,
      energyRating: energyRating,
      tags: tags,
      gratitudeNote: gratitudeNote,
      createdAt: now,
      updatedAt: now,
    );
  }

  String getResponse(String prompt) => responses[prompt] ?? '';

  bool get hasContent {
    return responses.values.any((v) => v.trim().isNotEmpty) ||
        (gratitudeNote?.trim().isNotEmpty ?? false);
  }

  int get wordCount {
    int count = 0;
    for (final response in responses.values) {
      count += response.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    }
    if (gratitudeNote != null) {
      count += gratitudeNote!
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
    }
    return count;
  }

  JournalEntry copyWithResponse(String prompt, String response) {
    final newResponses = Map<String, String>.from(responses);
    if (response.trim().isEmpty) {
      newResponses.remove(prompt);
    } else {
      newResponses[prompt] = response;
    }
    return copyWith(responses: newResponses, updatedAt: DateTime.now());
  }

  JournalEntry copyWithMood(int? mood) {
    return copyWith(moodRating: mood, updatedAt: DateTime.now());
  }

  JournalEntry copyWithEnergy(int? energy) {
    return copyWith(energyRating: energy, updatedAt: DateTime.now());
  }

  JournalEntry copyWithTags(List<String>? tags) {
    return copyWith(tags: tags, updatedAt: DateTime.now());
  }

  JournalEntry copyWithGratitude(String? note) {
    return copyWith(gratitudeNote: note, updatedAt: DateTime.now());
  }
}
