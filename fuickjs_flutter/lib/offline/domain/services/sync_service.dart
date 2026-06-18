import '../../util/logger.dart';
import '../../util/version_utils.dart';
import '../entities/package.dart';
import '../value_objects/sync_result.dart';

class SyncService {
  SyncService();

  /// 比较远程/内置与当前 active，产出 added/updated/removed。
  /// [appVersion] 用于 minAppVersion 兼容性过滤。
  SyncResult sync({
    required List<Package> remote,
    required List<Package> internal,
    required List<Package> active,
    required String appVersion,
  }) {
    final added = <Package>[];
    final updated = <Package>[];
    final removed = <Package>[];

    final effective = <String, Package>{};
    for (final pkg in remote) {
      effective[pkg.name] = pkg;
    }
    // 远程与内置版本一致时使用内置。
    for (final pkg in internal) {
      final existing = effective[pkg.name];
      if (existing != null && existing.isSameVersion(pkg)) {
        effective[pkg.name] = pkg;
      }
    }

    for (final pkg in effective.values) {
      // minAppVersion 不满足 → 跳过。
      if (!VersionUtils.isAppVersionSatisfied(appVersion, pkg.minAppVersion)) {
        logger(() =>
            'Skip ${pkg.name} ${pkg.version}: minAppVersion ${pkg.minAppVersion} > app $appVersion');
        continue;
      }

      final activePkg = active.where((a) => a.name == pkg.name).firstOrNull;
      if (activePkg == null) {
        added.add(pkg);
      } else if (!activePkg.isSameVersion(pkg)) {
        updated.add(pkg);
      }
    }

    // 远程已删、本地还在 → 移除。
    for (final activePkg in active) {
      if (!effective.containsKey(activePkg.name)) {
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
          'Sync: added=${added.length}, updated=${updated.length}, removed=${removed.length}');
    }
    return result;
  }
}
