import 'dart:convert';
import 'dart:io';

import '../../domain/entities/package.dart';
import '../../domain/repositories/package_repository.dart';
import '../datasources/file_storage.dart';

class LocalPackageRepository implements PackageRepository {
  static const String _activePackagesKey = 'active_packages';

  final FileStorage _fileStorage;

  LocalPackageRepository(this._fileStorage);

  @override
  Future<void> init() async {
    await _fileStorage.init();
  }

  @override
  Future<List<Package>> loadActivePackages() async {
    try {
      final json = await _fileStorage.readActivePackages();
      if (json.isEmpty) return [];

      final map = jsonDecode(json) as Map<String, dynamic>;
      final list = map[_activePackagesKey] as List<dynamic>? ?? [];
      return list
          .map((e) => Package.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> saveActivePackages(List<Package> packages) async {
    final list = packages.map((e) => e.toJson()).toList();
    final map = {_activePackagesKey: list};
    await _fileStorage.writeActivePackages(jsonEncode(map));
  }

  @override
  String getPackageDir(Package package) {
    return _fileStorage.getPackageDir(package);
  }

  @override
  String getDownloadDir() {
    return _fileStorage.downloadDir;
  }

  @override
  String getPackageFlagFile(Package package) {
    return _fileStorage.getPackageFlagFile(package);
  }

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
}
