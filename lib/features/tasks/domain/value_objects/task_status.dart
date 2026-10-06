/// Lifecycle status for a task.
///
/// Deliberately separate from the goal/project `ItemStatus`: a task is worked
/// on, so it has a
/// `doing` state a goal or project never needs, and it does not move through
/// the same `active -> completed` vocabulary. Keeping the two enums apart means
/// neither can drift into accepting a state that only makes sense for the other.
enum TaskStatus {
  todo('todo'),
  doing('doing'),
  done('done'),
  archived('archived');

  const TaskStatus(this.storageValue);

  /// The exact string written to storage.
  final String storageValue;

  /// Parses a persisted value.
  ///
  /// A missing (null) or unrecognised value falls back to [todo] rather than
  /// [archived]: a record from an older build, or one whose status field was
  /// corrupted, should still appear in the user's list instead of silently
  /// disappearing.
  static TaskStatus fromStorage(Object? value) {
    for (final status in TaskStatus.values) {
      if (status.storageValue == value) return status;
    }
    return TaskStatus.todo;
  }
}
