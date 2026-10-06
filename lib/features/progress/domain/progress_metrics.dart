import 'package:freezed_annotation/freezed_annotation.dart';

part 'progress_metrics.freezed.dart';

/// Focus time rolled up over a set of sessions.
///
/// The single definition of how sessions add up to "how much time went in",
/// so the analytics totals and the per-category split can never disagree.
@freezed
abstract class FocusBreakdown with _$FocusBreakdown {
  const factory FocusBreakdown({
    @Default(0) int totalMinutes,
    @Default({}) Map<String, int> byCategory,
  }) = _FocusBreakdown;
}

/// How far a project has actually got.
///
/// Two independent measures, deliberately not folded into one number: the task
/// ratio answers "is the work list shrinking", the focus minutes answer "is
/// this getting any real time". Either can move without the other, and a single
/// blended score would hide that.
@freezed
abstract class ProjectProgress with _$ProjectProgress {
  const factory ProjectProgress({
    @Default(0) int doneTaskCount,
    @Default(0) int totalTaskCount,
    @Default(0) int recurringTaskCount,
    @Default(0) int habitCount,
    @Default(0) int habitCompletionCount,
    @Default(0) int focusMinutes,
    @Default(0.0) double completionRatio,
  }) = _ProjectProgress;

  const ProjectProgress._();

  /// Whether there is any finite task for [completionRatio] to describe.
  bool get hasFiniteTasks => totalTaskCount > 0;
}

/// A goal's progress, rolled up from the projects and tasks that serve it.
@freezed
abstract class GoalProgress with _$GoalProgress {
  const factory GoalProgress({
    @Default(0) int projectCount,
    @Default(0) int completedProjectCount,
    @Default(0) int doneTaskCount,
    @Default(0) int totalTaskCount,
    @Default(0) int focusMinutes,
    @Default(0.0) double completionRatio,
  }) = _GoalProgress;

  const GoalProgress._();

  /// Whether there is any finite task for [completionRatio] to describe.
  bool get hasFiniteTasks => totalTaskCount > 0;
}
