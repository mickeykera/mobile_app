import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';

part 'habit_completion.freezed.dart';

/// A single logged completion.
///
/// Historically this could only describe a habit, so it required [habitId].
/// Tasks complete too, and rather than fork a parallel log the row was widened:
/// [itemId]/[itemType] name the work item generically while [habitId] stays for
/// the habit-scoped queries and for rows written before the widening. Reads
/// tolerate the old shape - a row with only [habitId] is read back as
/// `itemType: 'habit'` with [itemId] defaulted to it.
@freezed
abstract class HabitCompletion with _$HabitCompletion {
  const factory HabitCompletion({
    required String id,
    String? habitId,
    String? itemId,
    String? itemType,
    required DateTime completedAt,
    required int count,
    Duration? duration,
    String? note,
    int? moodRating,
    int? energyRating,
  }) = _HabitCompletion;

  const HabitCompletion._();

  /// The work item this completion belongs to.
  ///
  /// [itemId] is the canonical link; legacy rows stored only [habitId], so this
  /// falls back to it.
  String? get ownerId => itemId ?? habitId;

  /// Whether this completion is for a habit rather than a task.
  ///
  /// Legacy rows carry no [itemType] and are habit completions by definition,
  /// which is why the null case is decided by whether [habitId] is set.
  bool get isHabitCompletion =>
      itemType == 'habit' || (itemType == null && habitId != null);

  factory HabitCompletion.create({
    String? habitId,
    String? itemId,
    String? itemType,
    int count = 1,
    Duration? duration,
    String? note,
    int? moodRating,
    int? energyRating,
  }) {
    return HabitCompletion(
      id: IdGenerator.generateCompletionId(),
      habitId: habitId,
      itemId: itemId ?? habitId,
      itemType: itemType ?? (habitId != null ? 'habit' : null),
      completedAt: AppClock.now(),
      count: count,
      duration: duration,
      note: note,
      moodRating: moodRating,
      energyRating: energyRating,
    );
  }
}
