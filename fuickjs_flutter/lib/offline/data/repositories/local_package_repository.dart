import 'dart:convert';
import 'dart:io';

import 'package:fuickjs_flutter/offline/domain/entities/package.dart';
import 'package:fuickjs_flutter/offline/domain/repositories/package_repository.dart';
import 'package:fuickjs_flutter/offline/domain/value_objects/package_registry.dart';

import '../datasources/file_storage.dart';

/// 本地 registry + 包目录管理。
///
/// 安全策略说明（v2）：原 P0-4 registry.json HMAC 完整性校验已删除。
/// 原因：HMAC 密钥必须编译进 APK，攻击者反编译后可重算 sig，等于无保护。
/// 真正的安全由 P0-3（启动时重新验签 active bundle 目录）承担 —— 攻击者
/// 能改 registry 但改不了实际 bundle 文件，Ed25519 验签必失败。
class LocalPackageRepository implements PackageRepository {
  final FileStorage _fileStorage;

  LocalPackageRepository(this._fileStorage);

  @override
  Future<void> init() async {
    await _fileStorage.init();
  }

  @override
  Future<PackageRegistry> loadRegistry() async {
    final reg = File(_fileStorage.registryFile);
    if (!await reg.exists()) {
      return const PackageRegistry();
    }
    try {
      final content = await reg.readAsString();
      final map = jsonDecode(content) as Map<String, dynamic>;
      return PackageRegistry.fromJson(map);
    } catch (_) {
      return const PackageRegistry();
    }
  }

  @override
  Future<void> saveRegistry(PackageRegistry registry) async {
    final reg = File(_fileStorage.registryFile);
    await reg.parent.create(recursive: true);
    // 原子写：写到 .tmp 再 rename，避免半写状态。
    final tmp = File('${_fileStorage.registryFile}.tmp');
    await tmp.writeAsString(jsonEncode(registry.toJson()), flush: true);
    await tmp.rename(_fileStorage.registryFile);
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
