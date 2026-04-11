import 'dart:convert';

import 'package:flutter/services.dart';

import 'config/offline_config.dart';
import 'data/datasources/file_storage.dart';
import 'data/repositories/local_package_repository.dart';
import 'domain/entities/package.dart';
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

  static Future<void> init(OfflineConfig cfg) async {
    config = cfg;

    // 1. 初始化文件存储
    fileStorage = FileStorage();
    await fileStorage.init();
    fileStorage.setConfig(config);

    // 2. 初始化仓库
    packageRepository = LocalPackageRepository(fileStorage);
    await packageRepository.init();

    // 3. 初始化包服务（加载并验证 active packages）
    packageService = PackageService(packageRepository);
    await packageService.init();
    // 4. 初始化其他服务
    syncService = SyncService();
    downloadService = DownloadService(packageRepository);
    downloadService.setInternalChecker(packageService.isInternal);
    cleanService = CleanService(packageRepository);

    // 6. 加载内置包配置
    await _loadInternalPackages();

    // 7. 获取远程包并同步
    await _fetchRemotePackages();

    // 8. 清理过期包（在同步完成后执行，避免误删）
    await cleanService.cleanExpired(packageService.activePackages);
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
      logger(() => 'Failed to load internal packages: $e');
    }
  }

  static Future<void> _fetchRemotePackages() async {
    try {
      final result = await config.offlinePackagesGetter();
      if (result == null) return;

      await fileStorage.writeRemotePackages(jsonEncode(result));

      final list = result['packages'] as List<dynamic>? ?? [];
      final packages =
          list.map((e) => Package.fromJson(e as Map<String, dynamic>)).toList();

      packageService.setRemotePackages(packages);

      // 同步：比较远程/内置包与当前活跃包
      final syncResult = syncService.sync(
        remote: packages,
        internal: packageService.internalPackages,
        active: packageService.activePackages,
      );

      // 停用已移除的包
      if (syncResult.removed.isNotEmpty) {
        await packageService.deactivatePackages(syncResult.removed);
      }

      // 准备新增/更新的包（下载或解压）
      final allPackages = [...syncResult.added, ...syncResult.updated];
      final readyPackages = <Package>[];

      for (final pkg in allPackages) {
        final readyPkg = await downloadService.preparePackage(pkg);
        if (readyPkg != null) {
          readyPackages.add(readyPkg);
        }
      }

      // 激活就绪的包
      if (readyPackages.isNotEmpty) {
        await packageService.activatePackages(readyPackages);
      }
    } catch (e) {
      logger(() => 'Failed to fetch remote packages: $e');
    }
  }

  static Future<void> refresh() async {
    await _fetchRemotePackages();
  }
}
