import 'dart:convert';
import 'dart:io';

import '../../domain/entities/package.dart';
import '../../domain/repositories/package_repository.dart';
import '../../domain/value_objects/package_registry.dart';
import '../datasources/file_storage.dart';

class LocalPackageRepository implements PackageRepository {
  final FileStorage _fileStorage;

  LocalPackageRepository(this._fileStorage);

  @override
  Future<void> init() async {
    await _fileStorage.init();
  }

  @override
  Future<PackageRegistry> loadRegistry() async {
    try {
      final json = await _fileStorage.readRegistry();
      if (json.isEmpty) return const PackageRegistry();
      final map = jsonDecode(json) as Map<String, dynamic>;
      return PackageRegistry.fromJson(map);
    } catch (_) {
      return const PackageRegistry();
    }
  }

  @override
  Future<void> saveRegistry(PackageRegistry registry) async {
    await _fileStorage.writeRegistry(jsonEncode(registry.toJson()));
  }

  @override
  String getPackageDir(Package package) => _fileStorage.getPackageDir(package);

  @override
  String getStagingDir(Package package) => _fileStorage.getStagingDir(package);

  @override
  String getDownloadDir() => _fileStorage.downloadDir;

  @override
  String getPackageFlagFile(Package package) =>
      _fileStorage.getPackageFlagFile(package);

  @override
  String get packagesRootDir => _fileStorage.packagesDir;

  @override
  String get offlineRootDir => _fileStorage.rootDir;

  @override
  String builtinBundleZipAsset(String name) =>
      _fileStorage.builtinBundleZipAsset(name);

  @override
  Future<bool> validatePackage(Package package) async {
    final flagFile = File(getPackageFlagFile(package));
    return flagFile.exists();
  }

  @override
  Future<void> deletePackage(Package package) async {
    final dir = Directory(getPackageDir(package));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @override
  Future<void> deleteStaging(Package package) async {
    final dir = Directory(getStagingDir(package));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @override
  Future<void> promoteStaging(Package package) async {
    final stagingDir = Directory(getStagingDir(package));
    final pkgDir = Directory(getPackageDir(package));

    if (await pkgDir.exists()) {
      await pkgDir.delete(recursive: true);
    }
    if (!await pkgDir.parent.exists()) {
      await pkgDir.parent.create(recursive: true);
    }
    // 原子 rename（同一文件系统）。
    await stagingDir.rename(pkgDir.path);

    final flag = File(getPackageFlagFile(package));
    await flag.create(recursive: true);
  }
}
