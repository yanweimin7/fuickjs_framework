import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../config/offline_config.dart';
import '../../domain/entities/package.dart';

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

  String get rootDir => p.join(_applicationDirectory, 'offline');

  String get baseDir => p.join(rootDir, _config.envGetter());

  String get packagesDir => p.join(baseDir, 'packages');

  String get stagingDir => p.join(baseDir, 'staging');

  String get downloadDir => p.join(baseDir, 'download');

  /// 包状态机持久化文件。
  String get registryFile => p.join(baseDir, 'registry.json');

  /// 最近一次远程元数据快照。
  String get remotePackagesFile => p.join(baseDir, 'latest.json');

  /// 内置包配置（QuickJS bundle）。
  String get internalPackagesFile => 'assets/js/bundles.json';

  /// 内置 bundle zip 资源路径。
  String builtinBundleZipAsset(String name) => 'assets/js/$name.zip';

  String getPackageDir(Package package) =>
      p.join(packagesDir, package.name, package.versionShasumName);

  String getStagingDir(Package package) =>
      p.join(stagingDir, package.name, package.versionShasumName);

  String getPackageFlagFile(Package package) =>
      p.join(getPackageDir(package), '.offline_valid.flag');

  Future<String> readRegistry() async => _readFile(registryFile);

  Future<void> writeRegistry(String content) async {
    await _writeFile(registryFile, content);
  }

  Future<String> readRemotePackages() async => _readFile(remotePackagesFile);

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
    // 写临时文件再 rename，避免写一半被读到。
    final tmp = File('$path.tmp');
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(path);
  }
}
