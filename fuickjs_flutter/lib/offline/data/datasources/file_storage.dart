import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/entities/package.dart';
import '../../config/offline_config.dart';

class FileStorage {
  String _applicationDirectory = '';
  late OfflineConfig _config;

  Future<void> init() async {
    _applicationDirectory =
        (await getApplicationDocumentsDirectory()).absolute.path;
  }

  void setConfig(OfflineConfig config) {
    _config = config;
  }

  String get rootDir => '$_applicationDirectory/offline';

  String get baseDir => '$rootDir/${_config.envGetter()}';

  String get packagesDir => '$baseDir/packages';

  String get downloadDir => '$baseDir/download';

  String get activePackagesFile => '$baseDir/active.json';

  String get remotePackagesFile => '$baseDir/latest.json';

  String get internalPackagesFile => 'assets/h5/packages.json';

  String getPackageDir(Package package) =>
      '$packagesDir/${package.name}/${package.versionShasumName}';

  String getPackageFlagFile(Package package) =>
      '${getPackageDir(package)}/.offline_valid.flag';

  Future<String> readActivePackages() async {
    return _readFile(activePackagesFile);
  }

  Future<void> writeActivePackages(String content) async {
    await _writeFile(activePackagesFile, content);
  }

  Future<String> readRemotePackages() async {
    return _readFile(remotePackagesFile);
  }

  Future<void> writeRemotePackages(String content) async {
    await _writeFile(remotePackagesFile, content);
  }

  Future<String> _readFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return file.readAsString();
    }
    return '';
  }

  Future<void> _writeFile(String path, String content) async {
    final file = File(path);
    if (!(await file.parent.exists())) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(content);
  }
}
