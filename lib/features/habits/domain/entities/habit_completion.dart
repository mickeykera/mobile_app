import 'package:freezed_annotation/freezed_annotation.dart';

part 'habit_completion.freezed.dart';

@freezed
abstract class HabitCompletion with _$HabitCompletion {
  const factory HabitCompletion({
    required String id,
    required String habitId,
    required DateTime completedAt,
    required int count,
    Duration? duration,
    String? note,
    int? moodRating,
    int? energyRating,
  }) = _HabitCompletion;

  const HabitCompletion._();

  factory HabitCompletion.create({
    required String habitId,
    int count = 1,
    Duration? duration,
    String? note,
    int? moodRating,
    int? energyRating,
  }) {
    return HabitCompletion(
      id: 'completion_${DateTime.now().millisecondsSinceEpoch}',
      habitId: habitId,
      completedAt: DateTime.now(),
      count: count,
      duration: duration,
      note: note,
      moodRating: moodRating,
      energyRating: energyRating,
    );
  }
}
