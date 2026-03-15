import '../entities/package.dart';

class SyncResult {
  final List<Package> added;
  final List<Package> updated;
  final List<Package> removed;

  const SyncResult({
    this.added = const [],
    this.updated = const [],
    this.removed = const [],
  });

  bool get hasChanges =>
      added.isNotEmpty || updated.isNotEmpty || removed.isNotEmpty;

  int get totalChanges => added.length + updated.length + removed.length;

  SyncResult copyWith({
    List<Package>? added,
    List<Package>? updated,
    List<Package>? removed,
  }) {
    return SyncResult(
      added: added ?? this.added,
      updated: updated ?? this.updated,
      removed: removed ?? this.removed,
    );
  }
}
