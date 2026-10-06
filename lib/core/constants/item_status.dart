/// Lifecycle status shared by goals and projects.
///
/// Both move through the same three states, so the storage spelling and the
/// parse fallback live here once instead of in each entity's codec. Tasks will
/// get their own status set later; this one is deliberately only for the
/// planning items that share `active -> completed -> archived`.
enum ItemStatus {
  active('active'),
  completed('completed'),
  archived('archived');

  const ItemStatus(this.storageValue);

  /// The exact string written to storage.
  final String storageValue;

  /// Parses a persisted value.
  ///
  /// A missing (null) or unrecognised value falls back to [active] rather than
  /// [archived]: a record from an older build, or one whose status field was
  /// corrupted, should still show up in the user's list instead of silently
  /// disappearing.
  static ItemStatus fromStorage(Object? value) {
    for (final status in ItemStatus.values) {
      if (status.storageValue == value) return status;
    }
    return ItemStatus.active;
  }
}
