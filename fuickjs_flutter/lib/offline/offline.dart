import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'config/offline_config.dart';
import 'data/datasources/file_storage.dart';
import 'data/repositories/local_package_repository.dart';
import 'domain/entities/package.dart';
import 'domain/services/bundle_verifier.dart';
import 'domain/services/clean_service.dart';
import 'domain/services/download_service.dart';
import 'domain/services/package_service.dart';
import 'domain/services/sync_service.dart';
import 'util/logger.dart';

class Offline {
  static late OfflineConfig config;

  static late FileStorage fileStorage;
  static late LocalPackageRepository packageRepository;
  static late PackageService packageService;
  static late SyncService syncService;
  static late DownloadService downloadService;
  static late CleanService cleanService;
  static late BundleVerifier verifier;

  static bool _initialized = false;
  static bool get initialized => _initialized;

  static Future<void> init(OfflineConfig cfg) async {
    if (_initialized) return;
    config = cfg;

    fileStorage = FileStorage();
    await fileStorage.init();
    fileStorage.setConfig(config);

    packageRepository = LocalPackageRepository(fileStorage);
    await packageRepository.init();

    verifier = BundleVerifier(publicKeysB64: config.signaturePublicKeysB64);

    packageService = PackageService(
      packageRepository,
      retainVersions: config.retainVersions,
    );
    await packageService.init();

    syncService = SyncService();
    downloadService = DownloadService(
      packageRepository,
      config: config,
      verifier: verifier,
    );
    downloadService.setInternalChecker(packageService.isInternal);
    cleanService = CleanService(packageRepository);

    await _loadInternalPackages();

    _initialized = true;

    // 远程同步与清理后台进行，不阻塞启动；首屏用内置/当前 active，新版下次打开切换。
    unawaited(_syncAndClean());
  }

  /// 后台：远程同步 + 启动兜底 GC。异常自吞，不影响已就绪的引擎加载。
  static Future<void> _syncAndClean() async {
    try {
      await _fetchRemotePackages();
      await cleanService.cleanExpired(
        packageService.registry,
        config.envGetter(),
      );
    } catch (e) {
      logger(() => 'Background sync/clean failed: $e');
    }
  }

  static Future<void> _loadInternalPackages() async {
    try {
      final json = await rootBundle.loadString(
        fileStorage.internalPackagesFile,
        cache: false,
      );
      final map = jsonDecode(json) as Map<String, dynamic>;
      final list = map['packages'] as List<dynamic>? ?? [];
      final packages = list
          .map((e) => Package.fromJson(e as Map<String, dynamic>))
          .toList();
      packageService.setInternalPackages(packages);
      logger(() => 'Internal packages loaded: ${packages.length}');
    } catch (e) {
      // 无内置包（thin-app 模式）属正常场景。
      logger(() => 'No internal packages: $e');
    }
  }

  static Future<void> _fetchRemotePackages() async {
    try {
      final result = await config.offlinePackagesGetter();

      final List<Package> remotePackages;
      if (result != null) {
        await fileStorage.writeRemotePackages(jsonEncode(result));
        final list = result['packages'] as List<dynamic>? ?? [];
        remotePackages = list
            .map((e) => Package.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // 无远程配置时，以内置包作为"远程"基准。
        // 若 active 的 sha256 与内置不一致，会触发重新解压。
        remotePackages = packageService.internalPackages;
      }
      packageService.setRemotePackages(remotePackages);

      final syncResult = syncService.sync(
        remote: remotePackages,
        internal: packageService.internalPackages,
        active: packageService.activePackages,
        appVersion: config.appVersion,
      );

      if (syncResult.removed.isNotEmpty) {
        await packageService.deactivatePackages(syncResult.removed);
      }

      final toPrepare = [...syncResult.added, ...syncResult.updated];
      final ready = <Package>[];
      for (final pkg in toPrepare) {
        // 先查 history / retained，本地已有则跳过下载。
        final reused = await packageService.reuseLocalAsStaged(pkg);
        if (reused != null) {
          ready.add(reused);
          continue;
        }
        final readyPkg = await downloadService.preparePackage(pkg);
        if (readyPkg != null) ready.add(readyPkg);
      }
      if (ready.isNotEmpty) {
        await packageService.applyReady(ready);
      }
    } catch (e) {
      logger(() => 'Failed to fetch remote packages: $e');
    }
  }

  static Future<void> refresh() async {
    if (!_initialized) return;
    await _fetchRemotePackages();
  }

  // ── 引擎集成公开 API ──

  /// 当前 active 包根目录（不触发提升）；无则 null。
  static Future<String?> getActivePackageRoot(String name) async {
    if (!_initialized) return null;
    final active = packageService.getActivePackage(name);
    if (active == null) return null;
    return _dirIfExists(active);
  }

  /// 下次打开生效：提升 staged → active，并确保目标包已解压；返回 root（无则 null）。
  static Future<String?> promoteAndGetRoot(String name) async {
    if (!_initialized) return null;

    var active = await packageService.promoteStaged(name);
    active ??= packageService.getActivePackage(name);

    // 无 active/staged → 解压内置包兜底（首启、被清理、远程未就绪等皆同一处理）。
    active ??= await _ensureBuiltinActive(name);
    if (active == null) return null;

    final dir = await _dirIfExists(active);
    if (dir != null) return dir;

    // active 目录意外缺失 → 兜底重建内置。
    final rebuilt = await _ensureBuiltinActive(name);
    return rebuilt != null ? _dirIfExists(rebuilt) : null;
  }

  static Future<Package?> _ensureBuiltinActive(String name) async {
    final builtin = packageService.internalPackages
        .where((p) => p.name == name)
        .firstOrNull;
    if (builtin == null) {
      logger(() => 'No builtin package for name=$name');
      return null;
    }

    logger(() => 'Ensure builtin active: ${builtin.versionShasumName}');
    final ready = await downloadService.preparePackage(builtin);
    if (ready == null) {
      logger(() => 'Builtin prepare failed: ${builtin.versionShasumName}');
      return null;
    }
    await packageService.applyReady([ready]);
    return packageService.promoteStaged(name);
  }

  static Future<String?> _dirIfExists(Package pkg) async {
    final dir = packageRepository.getPackageDir(pkg);
    if (await Directory(dir).exists()) return dir;
    return null;
  }
}
