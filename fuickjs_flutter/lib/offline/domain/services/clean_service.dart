import 'dart:io';

import 'package:path/path.dart' as path;

import '../../offline.dart';
import '../../util/logger.dart';
import '../entities/package.dart';
import '../repositories/package_repository.dart';

class CleanService {
  final PackageRepository _repository;

  CleanService(this._repository);

  Future<void> cleanExpired(List<Package> activePackages) async {
    await cleanInactivePackages(activePackages);
    await cleanOtherEnvDirs();
    await cleanOldDownloads();
  }

  Future<void> cleanInactivePackages(List<Package> activePackages) async {
    final packagesDir = Directory(_repository.getPackageDir(
      const Package(name: '', version: '', shasum: ''),
    )).parent;

    if (!(await packagesDir.exists())) return;

    final toClean = <Directory>[];

    await for (final pkgDir in packagesDir.list()) {
      if (pkgDir is! Directory) continue;

      final packageName = path.basename(pkgDir.path);

      await for (final versionDir in pkgDir.list()) {
        if (versionDir is! Directory) continue;

        final versionName = path.basename(versionDir.path);

        final isActive = activePackages.any(
            (p) => p.name == packageName && p.versionShasumName == versionName);

        if (!isActive) {
          toClean.add(versionDir);
        }
      }
    }

    for (final dir in toClean) {
      try {
        await dir.delete(recursive: true);
        logger(() => 'Cleaned: ${dir.path}');
      } catch (e) {
        logger(() => 'Failed to clean ${dir.path}: $e');
      }
    }
  }

  Future<void> cleanOtherEnvDirs() async {
    final env = Offline.config.envGetter();
    final rootDir = Directory(
        '${Directory(_repository.getPackageDir(const Package(name: '', version: '', shasum: ''))).parent.parent.parent.path}/offline');

    if (!(await rootDir.exists())) return;

    await for (final envDir in rootDir.list()) {
      if (envDir is Directory && path.basename(envDir.path) != env) {
        try {
          await envDir.delete(recursive: true);
          logger(() => 'Cleaned env dir: ${envDir.path}');
        } catch (e) {
          logger(() => 'Failed to clean env dir ${envDir.path}: $e');
        }
      }
    }
  }

  Future<void> cleanOldDownloads() async {
    final downloadDir = Directory(_repository.getDownloadDir());
    if (!(await downloadDir.exists())) return;

    await for (final file in downloadDir.list()) {
      final stat = file.statSync();
      final age = DateTime.now().difference(stat.modified);

      if (age.inDays > 10) {
        try {
          await file.delete();
          logger(() => 'Cleaned old download: ${file.path}');
        } catch (e) {
          logger(() => 'Failed to clean download ${file.path}: $e');
        }
      }
    }
  }

  Future<void> deletePackage(Package package) async {
    await _repository.deletePackage(package);
    logger(() => 'Deleted package: ${package.name}');
  }
}
