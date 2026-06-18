import 'dart:io';

import 'package:path/path.dart' as p;

import '../../util/logger.dart';
import '../entities/package.dart';
import '../repositories/package_repository.dart';
import '../value_objects/package_registry.dart';

class CleanService {
  final PackageRepository _repository;

  CleanService(this._repository);

  /// 启动兜底 GC：收敛到 registry 引用集（active ∪ staged ∪ history）。
  Future<void> cleanExpired(PackageRegistry registry, String env) async {
    await cleanUnreferenced(registry);
    await cleanOtherEnvDirs(env);
    await cleanOldDownloads();
  }

  /// 删除 packages/ 下不在 registry 引用集内的所有目录。
  Future<void> cleanUnreferenced(PackageRegistry registry) async {
    final packagesDir = Directory(_repository.packagesRootDir);
    if (!await packagesDir.exists()) return;

    final retainedDirs = registry.retained
        .map((pkg) => p.normalize(_repository.getPackageDir(pkg)))
        .toSet();

    await for (final pkgNameDir in packagesDir.list()) {
      if (pkgNameDir is! Directory) continue;
      await for (final versionDir in pkgNameDir.list()) {
        if (versionDir is! Directory) continue;
        final normalized = p.normalize(versionDir.path);
        if (!retainedDirs.contains(normalized)) {
          await _deleteDir(versionDir);
        }
      }
    }
  }

  /// 低磁盘驱逐：按优先级释放空间。
  /// 顺序：旧 download → history LRU（最旧优先，可删到 0）。
  /// 返回被删除的 history 包，供上层从 registry 中移除。
  Future<List<Package>> evictForSpace(
    PackageRegistry registry, {
    required bool Function() hasEnoughSpace,
  }) async {
    if (hasEnoughSpace()) return const [];

    await cleanOldDownloads(maxAgeDays: 0);
    if (hasEnoughSpace()) return const [];

    // history 按进入顺序（registry 内 index 0 为最新）从最旧开始删。
    final evicted = <Package>[];
    final history = List<Package>.from(registry.history).reversed.toList();
    for (final pkg in history) {
      await _repository.deletePackage(pkg);
      evicted.add(pkg);
      if (hasEnoughSpace()) break;
    }
    if (evicted.isNotEmpty) {
      logger(() => 'Evicted ${evicted.length} history packages for space');
    }
    return evicted;
  }

  Future<void> cleanOtherEnvDirs(String env) async {
    final rootDir = Directory(_repository.offlineRootDir);
    if (!await rootDir.exists()) return;

    await for (final envDir in rootDir.list()) {
      if (envDir is Directory && p.basename(envDir.path) != env) {
        await _deleteDir(envDir);
      }
    }
  }

  Future<void> cleanOldDownloads({int maxAgeDays = 10}) async {
    final downloadDir = Directory(_repository.getDownloadDir());
    if (!await downloadDir.exists()) return;

    await for (final file in downloadDir.list()) {
      try {
        final stat = file.statSync();
        final age = DateTime.now().difference(stat.modified);
        if (age.inDays >= maxAgeDays) {
          await file.delete(recursive: true);
          logger(() => 'Cleaned old download: ${file.path}');
        }
      } catch (e) {
        logger(() => 'Failed to clean download ${file.path}: $e');
      }
    }
  }

  Future<void> _deleteDir(FileSystemEntity dir) async {
    try {
      await dir.delete(recursive: true);
      logger(() => 'Cleaned: ${dir.path}');
    } catch (e) {
      logger(() => 'Failed to clean ${dir.path}: $e');
    }
  }
}
