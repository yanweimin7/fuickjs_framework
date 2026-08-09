import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'config/offline_config.dart';
import 'data/datasources/file_storage.dart';
import 'data/repositories/local_package_repository.dart';
import 'domain/entities/package.dart';
import 'domain/services/bundle_verifier.dart';
import 'domain/services/bundle_verify_isolate.dart';
import 'domain/services/clean_service.dart';
import 'domain/services/download_service.dart';
import 'domain/services/package_service.dart';
import 'domain/services/remote_packages_verifier.dart';
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
  static late RemotePackagesVerifier remotePackagesVerifier;
  static late BundleVerifyIsolate verifyIsolate;

  static bool _initialized = false;

  /// init 进行中的 Future，供并发调用方 join（避免重复 init），也供
  /// promoteAndGetRoot / getActivePackageRoot / refresh 在 _initialized 尚未
  /// 置位时等待而非直接返回 null（line 82 注释本意即"会等 _initialized"）。
  ///
  /// 若 init 从未被调用则为 null；whenInitialized 会降级为已完成的 Future。
  static Future<void>? _initFuture;

  /// 等待初始化完成。init 进行中则 join 同一 Future；init 从未调用则返回
  /// 已完成的 Future（调用方仍需检查 _initialized 判断 init 是否成功过）。
  static Future<void> get whenInitialized => _initFuture ?? Future.value();

  static Future<void> init(OfflineConfig cfg) {
    if (_initialized) return Future.value();
    if (_initFuture != null) return _initFuture!; // 并发调用 join 同一 init
    final f = _initBody(cfg);
    _initFuture = f;
    f.catchError((_) {
      _initFuture = null; // init 失败允许重试
    });
    return f;
  }

  static Future<void> _initBody(OfflineConfig cfg) async {
    config = cfg;

    // P0-6 启动期硬约束：未配置公钥直接拒绝（避免后续 BundleVerifier 构造失败）。
    if (config.signaturePublicKeysB64.isEmpty) {
      throw StateError(
        'OfflineConfig.signaturePublicKeysB64 is required and cannot be empty. '
        'P0-1/P0-6: Ed25519 signature verification is mandatory.',
      );
    }

    fileStorage = FileStorage();
    await fileStorage.init();
    fileStorage.setConfig(config);

    packageRepository = LocalPackageRepository(fileStorage);
    await packageRepository.init();

    verifier = BundleVerifier(publicKeysB64: config.signaturePublicKeysB64);
    remotePackagesVerifier = RemotePackagesVerifier(verifier);

    // 启动验签 isolate（主 isolate 立即返回，可并行做其他启动工作）。
    verifyIsolate = await BundleVerifyIsolate.create(
      config.signaturePublicKeysB64,
    );

    packageService = PackageService(
      packageRepository,
      retainVersions: config.retainVersions,
      verifyIsolate: verifyIsolate,
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

    // 启动兜底 GC：cleanUnreferenced 在 _initialized 之前同步执行。
    // 此时 promoteAndGetRoot 会等 _initialized，不会有用户并发操作 packages/，
    // 从架构上消除 cleanUnreferenced 与 promoteStaging 的竞态（不再需要锁保护）。
    try {
      await cleanService.cleanUnreferenced(packageService.registry);
    } catch (e) {
      logger(() => 'Startup cleanUnreferenced failed: $e');
    }

    _initialized = true;

    // 远程同步 + 下载缓存清理后台进行，不阻塞启动。
    unawaited(_syncAndClean());
  }

  /// 后台：远程同步 + 下载缓存清理。异常自吞，不影响已就绪的引擎加载。
  ///
  /// cleanUnreferenced 已在 init 阶段同步完成（无并发），这里不再扫 packages/。
  static Future<void> _syncAndClean() async {
    try {
      await _fetchRemotePackages();
      // 以下两项不涉及 packages/，可安全在后台执行。
      await cleanService.cleanOtherEnvDirs(config.envGetter());
      await cleanService.cleanOldDownloads(maxAgeDays: 3);
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
      final packages =
          list.map((e) => Package.fromJson(e as Map<String, dynamic>)).toList();
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
        // P0-5（latest.json Ed25519 验签）暂未启用：直接信任 host 的
        // offlinePackagesGetter 返回值，由 host 自行保证 latest.json 可信
        // （HTTPS / 内置证书 / 后端鉴权等任选）。
        // RemotePackagesVerifier class + 单元测试 + sign-latest.js 工具保留，
        // 未来需要时只需打开下方注释即可启用。
        //
        // final Map<String, dynamic> rawMap = Map<String, dynamic>.from(result);
        // final verified =
        //     await remotePackagesVerifier.verify(rawMap) ?? <String, dynamic>{};
        // if (verified.isEmpty) {
        //   logger(() =>
        //       '[P0-5] Remote latest.json rejected; falling back to internal');
        //   remotePackages = packageService.internalPackages;
        // } else {
        //   await fileStorage.writeRemotePackages(jsonEncode({
        //     ...verified,
        //     '_sig': rawMap['_sig'],
        //     '_kid': rawMap['_kid'],
        //   }));
        //   final list = verified['packages'] as List<dynamic>? ?? const [];
        //   remotePackages = list
        //       .map((e) => Package.fromJson(e as Map<String, dynamic>))
        //       .toList();
        // }
        final rawMap = Map<String, dynamic>.from(result);
        // 保留 _sig/_kid 一并落盘，方便未来启用 verify 时无缝升级。
        await fileStorage.writeRemotePackages(jsonEncode(rawMap));
        final list = rawMap['packages'] as List<dynamic>? ?? const [];
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
    await whenInitialized;
    if (!_initialized) return;
    await _fetchRemotePackages();
  }

  // ── 引擎集成公开 API ──

  /// 当前 active 包根目录（不触发提升）；无则 null。
  static Future<String?> getActivePackageRoot(String name) async {
    await whenInitialized;
    if (!_initialized) return null;
    final active = packageService.getActivePackage(name);
    if (active == null) return null;
    return _dirIfExists(active);
  }

  /// 下次打开生效：提升 staged → active，并确保目标包已解压；返回 root（无则 null）。
  ///
  /// P0-3 on-open：返回 dir 前在子 isolate 做最后一道验签。
  /// 失败 → 删包 + 兜底内置。调用方在拿到 dir 后**直接加载 JS**，安全依赖于此
  /// 验签已通过（await 是同步语义，JS 不会先于验签跑起来）。
  static Future<String?> promoteAndGetRoot(String name) async {
    await whenInitialized;
    if (!_initialized) return null;

    var active = await packageService.promoteStaged(name);
    active ??= packageService.getActivePackage(name);

    // 无 active/staged → 解压内置包兜底（首启、被清理、远程未就绪等皆同一处理）。
    active ??= await _ensureBuiltinActive(name);
    if (active == null) return null;

    final dir = await _dirIfExists(active);
    if (dir == null) {
      // active 目录意外缺失 → 兜底重建内置。
      final rebuilt = await _ensureBuiltinActive(name);
      return rebuilt != null ? _dirIfExists(rebuilt) : null;
    }

    // P0-3 on-open 验签（子 isolate 跑，主 isolate 事件循环不阻塞）。
    final verified = await packageService.verifyOnOpen(active, dir);
    if (verified == null) {
      // 验签失败 → 退到内置包兜底。
      logger(() => '[P0-3 on-open] Exit bundle "$name", fallback to builtin');
      final rebuilt = await _ensureBuiltinActive(name);
      if (rebuilt == null) return null;
      // 兜底包同样要走 on-open 验签,保持"返回 dir 前必验签"的不变量。
      // 内置包理论上可信(APK assets),但若 staging 被替换或解压异常,
      // 这一道闸能挡住。失败则彻底返回 null,由调用方走默认 RN bundle。
      final rebuiltDir = await _dirIfExists(rebuilt);
      if (rebuiltDir == null) return null;
      final reVerified = await packageService.verifyOnOpen(rebuilt, rebuiltDir);
      if (reVerified == null) {
        logger(() => '[P0-3 on-open] Builtin fallback also failed: $name');
        return null;
      }
      return rebuiltDir;
    }
    return dir;
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
    final dir = Directory(packageRepository.getPackageDir(pkg));
    if (await dir.exists()) return dir.path;
    return null;
  }
}
