import '../../util/logger.dart';
import '../entities/package.dart';
import '../value_objects/sync_result.dart';

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

    /// 如果远程包跟内置包一致（版本号和shasum都相同），则使用内置包
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

    /// 如果远程包已经删了，本地还在，则要删除本地生效的包
    for (final activePkg in active) {
      final exists = effectivePackages.containsKey(activePkg.name);
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
      logger(() =>
          'Sync: added=${result.added.length}, updated=${result.updated.length}, removed=${result.removed.length}');
    }

    return result;
  }
}
