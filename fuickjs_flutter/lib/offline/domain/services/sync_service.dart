import '../entities/package.dart';
import '../value_objects/sync_result.dart';
import '../../util/logger.dart';

class SyncService {
  SyncService();

  SyncResult sync({
    required List<Package> remote,
    required List<Package> internal,
    required List<Package> active,
  }) {
    final added = <Package>[];
    final updated = <Package>[];
    final removed = <Package>[];

    final effectivePackages = <String, Package>{};

    for (final pkg in remote) {
      effectivePackages[pkg.name] = pkg;
    }

    for (final pkg in internal) {
      final existing = effectivePackages[pkg.name];
      if (existing != null && existing.isSameVersion(pkg)) {
        effectivePackages[pkg.name] = pkg;
      }
    }

    for (final pkg in effectivePackages.values) {
      final activePkg = active.where((a) => a.name == pkg.name).firstOrNull;

      if (activePkg == null) {
        added.add(pkg);
      } else if (!activePkg.isSameVersion(pkg)) {
        updated.add(pkg);
      }
    }

    for (final activePkg in active) {
      final exists = effectivePackages.values.any((p) =>
          p.name == activePkg.name && p.versionShasumName == activePkg.versionShasumName);
      if (!exists) {
        removed.add(activePkg);
      }
    }

    final result = SyncResult(
      added: added,
      updated: updated,
      removed: removed,
    );

    if (result.hasChanges) {
      logger(() => 'Sync: added=${result.added.length}, updated=${result.updated.length}, removed=${result.removed.length}');
    }

    return result;
  }
}
