import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/habit_controller.dart';
import '../../data/repositories/habit_repository_impl.dart';
import '../../../../core/database/database.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_completion.dart';

final habitControllerProvider =
    StateNotifierProvider<HabitController, HabitState>((ref) {
  final database = ref.watch(databaseServiceProvider);
  final repository = HabitRepositoryImpl(database);
  return HabitController(repository);
});

final habitsProvider = Provider<List<Habit>>((ref) {
  return ref.watch(habitControllerProvider).habits;
});

final todaysCompletionsProvider = Provider<List<HabitCompletion>>((ref) {
  return ref.watch(habitControllerProvider).todaysCompletions;
});

/// Habits due on the day the controller is currently showing. Must read the
/// state (not the notifier): watching `.notifier` never re-notifies, so this
/// would freeze at the value computed for the very first build.
final dueHabitsProvider = Provider<List<Habit>>((ref) {
  final state = ref.watch(habitControllerProvider);
  return HabitController.dueHabitsFor(state.habits, _targetDate(state));
});

final todaysProgressProvider = Provider<double>((ref) {
  final state = ref.watch(habitControllerProvider);
  return HabitController.progressFor(
    habits: state.habits,
    completions: state.todaysCompletions,
    date: _targetDate(state),
  );
});

/// The day the loaded completion list belongs to: the user-picked date, or
/// today while none has been picked.
DateTime _targetDate(HabitState state) => state.selectedDate ?? DateTime.now();
