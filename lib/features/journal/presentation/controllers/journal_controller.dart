import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/journal_entry.dart';
import '../../data/repositories/journal_repository_impl.dart';
import '../../domain/repositories/journal_repository.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';

part 'journal_controller.freezed.dart';

@freezed
abstract class JournalState with _$JournalState {
  const factory JournalState({
    JournalEntry? morningEntry,
    JournalEntry? eveningEntry,
    @Default([]) List<JournalEntry> recentEntries,
    @Default(false) bool isLoading,
    @Default(false) bool isSaving,
    String? error,
    DateTime? selectedDate,
    @Default('Morning') String selectedType,
  }) = _JournalState;
}

class JournalController extends StateNotifier<JournalState> {
  final JournalRepository _repository;

  JournalController(this._repository) : super(const JournalState()) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    state = state.copyWith(isLoading: true, error: null);
    final today = DateTime.now();

    await _loadEntriesForDate(today);
    final recentResult = await _repository.getEntries(limit: 20);
    // The provider can be disposed while the load is in flight (navigation,
    // hot restart); writing state afterwards throws `Bad state`.
    if (!mounted) return;

    if (recentResult.isLeft) {
      state = state.copyWith(
          isLoading: false, error: recentResult.left!.userMessage);
    } else {
      state =
          state.copyWith(isLoading: false, recentEntries: recentResult.right!);
    }
  }

  Future<void> _loadEntriesForDate(DateTime date) async {
    final morningResult = await _repository.getEntryForDate(date, 'Morning');
    final eveningResult = await _repository.getEntryForDate(date, 'Evening');
    if (!mounted) return;

    if (morningResult.isLeft) {
      state = state.copyWith(error: morningResult.left!.userMessage);
    } else {
      // A day can legitimately have no entry: `right` is then null.
      state =
          state.copyWith(morningEntry: morningResult.right, selectedDate: date);
    }

    if (eveningResult.isLeft) {
      state = state.copyWith(error: eveningResult.left!.userMessage);
    } else {
      state = state.copyWith(eveningEntry: eveningResult.right);
    }
  }

  Future<void> refresh() async {
    await _loadInitialData();
  }

  void setSelectedDate(DateTime date) {
    if (state.selectedDate == date) return;
    state = state.copyWith(selectedDate: date, selectedType: 'Morning');
    _loadEntriesForDate(date);
  }

  void setSelectedType(String type) {
    state = state.copyWith(selectedType: type);
  }

  JournalEntry? getCurrentEntry() {
    return state.selectedType == 'Morning'
        ? state.morningEntry
        : state.eveningEntry;
  }

  /// Moves [saved] to the front of the recent list, replacing the stale copy
  /// of the same entry if there is one.
  List<JournalEntry> _upsertRecent(JournalEntry saved) {
    return [
      saved,
      ...state.recentEntries.where((candidate) => candidate.id != saved.id),
    ];
  }

  Future<Result<JournalEntry>> saveEntry({
    required Map<String, String> responses,
    int? moodRating,
    int? energyRating,
    List<String>? tags,
    String? gratitudeNote,
  }) async {
    state = state.copyWith(isSaving: true, error: null);

    final date = state.selectedDate ?? DateTime.now();
    final type = state.selectedType;
    final currentEntry = getCurrentEntry();

    JournalEntry entry;
    if (currentEntry != null) {
      entry = currentEntry.copyWith(
        responses: responses,
        moodRating: moodRating,
        energyRating: energyRating,
        tags: tags,
        gratitudeNote: gratitudeNote,
        updatedAt: DateTime.now(),
      );
    } else if (type == 'Morning') {
      entry = JournalEntry.createMorning(
        date: date,
        responses: responses,
        moodRating: moodRating,
        energyRating: energyRating,
        tags: tags,
        gratitudeNote: gratitudeNote,
      );
    } else {
      entry = JournalEntry.createEvening(
        date: date,
        responses: responses,
        moodRating: moodRating,
        energyRating: energyRating,
        tags: tags,
        gratitudeNote: gratitudeNote,
      );
    }

    final result = currentEntry != null
        ? await _repository.updateEntry(entry)
        : await _repository.createEntry(entry);

    if (result.isLeft) {
      state = state.copyWith(isSaving: false, error: result.left!.userMessage);
      return result;
    }

    final saved = result.right!;
    // Update the loaded entries and the recent list in place. Reloading
    // everything here would flip `isLoading` and flash a spinner over the
    // entry the user just wrote.
    state = state.copyWith(
      isSaving: false,
      morningEntry: type == 'Morning' ? saved : state.morningEntry,
      eveningEntry: type == 'Morning' ? state.eveningEntry : saved,
      recentEntries: _upsertRecent(saved),
    );

    return result;
  }

  Future<Result<void>> deleteCurrentEntry() async {
    final entry = getCurrentEntry();
    if (entry == null) {
      return Either.left(const NotFoundFailure('No entry to delete'));
    }

    final result = await _repository.deleteEntry(entry.id);

    if (result.isLeft) {
      state = state.copyWith(error: result.left!.userMessage);
    } else {
      if (state.selectedType == 'Morning') {
        state = state.copyWith(morningEntry: null);
      } else {
        state = state.copyWith(eveningEntry: null);
      }
      // Drop it from the recent list in place instead of reloading: a reload
      // shows the full-screen spinner and briefly wipes the entries the user
      // is looking at.
      state = state.copyWith(
        recentEntries: state.recentEntries
            .where((candidate) => candidate.id != entry.id)
            .toList(),
      );
    }

    return result;
  }

  List<String> getPromptsForType(String type) {
    // Single source of truth: the same list is rendered by the entry sheet, so
    // a second copy here could drift from what the user actually sees.
    return type == AppConstants.reflectionMorning
        ? AppConstants.morningPrompts
        : AppConstants.eveningPrompts;
  }

  bool get hasMorningEntry => state.morningEntry?.hasContent ?? false;
  bool get hasEveningEntry => state.eveningEntry?.hasContent ?? false;
}

final journalControllerProvider =
    StateNotifierProvider<JournalController, JournalState>((ref) {
  final repository = ref.watch(journalRepositoryProvider);
  return JournalController(repository);
});

final morningEntryProvider = Provider<JournalEntry?>((ref) {
  return ref.watch(journalControllerProvider).morningEntry;
});

final eveningEntryProvider = Provider<JournalEntry?>((ref) {
  return ref.watch(journalControllerProvider).eveningEntry;
});

final recentEntriesProvider = Provider<List<JournalEntry>>((ref) {
  return ref.watch(journalControllerProvider).recentEntries;
});
