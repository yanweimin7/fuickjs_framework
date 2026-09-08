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
  static BundleVerifyIsolate? verifyIsolate;

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

  /// 远程包列表首次就绪（`setRemotePackages` 已写入）的信号。
  ///
  /// `_syncAndClean` 是 fire-and-forget，冷启动首次 promoteAndGetRoot 通常早于
  /// 远程列表落地，而强制更新只看内存态 → 不等信号的话首启必然判成"无强制更新"。
  /// 只覆盖"列表就绪"，不含随后的下载。
  static Completer<void>? _remoteListReady;

  /// 按 name 合并进行中的强制更新：并发打开同一 bundle 时只征询一次用户、
  /// 只跑一遍下载与提升。
  static final Map<String, Future<void>> _forcedUpdateInflight = {};

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
    // 仅当开启代码层验签（enableSignatureVerify）时才强制要求公钥。
    if (config.enableSignatureVerify && config.signaturePublicKeysB64.isEmpty) {
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

    verifier = BundleVerifier(
      publicKeysB64: config.signaturePublicKeysB64,
      allowEmptyKeys: !config.enableSignatureVerify,
    );
    remotePackagesVerifier = RemotePackagesVerifier(verifier);

    // 启动验签 isolate（主 isolate 立即返回，可并行做其他启动工作）。
    // 关闭代码层验签时不创建 isolate，PackageService 对 verifyIsolate==null
    // 天然跳过后台重新验签与 on-open 验签。
    verifyIsolate = config.enableSignatureVerify
        ? await BundleVerifyIsolate.create(config.signaturePublicKeysB64)
        : null;

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
      enableSignatureVerify: config.enableSignatureVerify,
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
    _remoteListReady ??= Completer<void>();
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
      final packages = list
          .whereType<Map<String, dynamic>>()
          .map((e) => Package.tryFromJson(e))
          .whereType<Package>()
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
            .whereType<Map<String, dynamic>>()
            .map((e) => Package.tryFromJson(e))
            .whereType<Package>()
            .toList();
      } else {
        // `offlinePackagesGetter` 返回 null（无远程配置 / 网络失败但未抛异常）：
        // 优先回退上次成功落盘的 remote 缓存（latest.json），无缓存再兜底内置包。
        // 这样网络抖动时不会把上次已 active 的远程包误判为 removed 而删掉。
        remotePackages = await _loadCachedRemotePackages();
      }
      packageService.setRemotePackages(remotePackages);
      // 列表已落内存即可放行强制更新判定，不必等下面的下载/提升跑完。
      _signalRemoteListReady();

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
    } finally {
      // 失败也要放行等待方：拉不到远程就等同于"无强制更新"，不能把打开挂住。
      _signalRemoteListReady();
    }
  }

  /// 读取上次成功拉取并落盘的 remote 列表（latest.json）作为兜底。
  ///
  /// 网络失败 / `offlinePackagesGetter` 返回 null 时调用：优先用缓存，让 sync
  /// 不会把上次已 active 的远程包误判为 removed 删掉。无缓存（文件不存在、解析
  /// 失败、或 packages 为空）时退化为内置包列表。
  static Future<List<Package>> _loadCachedRemotePackages() async {
    try {
      final content = await fileStorage.readRemotePackages();
      if (content.isNotEmpty) {
        final map = jsonDecode(content) as Map<String, dynamic>;
        final list = map['packages'] as List<dynamic>? ?? const [];
        final cached = list
            .whereType<Map<String, dynamic>>()
            .map((e) => Package.tryFromJson(e))
            .whereType<Package>()
            .toList();
        if (cached.isNotEmpty) {
          logger(() => 'Reuse cached remote packages: ${cached.length}');
          return cached;
        }
      }
    } catch (e) {
      logger(() => 'Failed to read cached remote packages: $e');
    }
    return packageService.internalPackages;
  }

  static void _signalRemoteListReady() {
    final c = _remoteListReady;
    if (c != null && !c.isCompleted) c.complete();
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

  /// 当前 active 包元数据（不触发提升）；无则 null。
  ///
  /// 供引擎注入 bundle 标识（name/version/sha256）到 JS 侧。仅返回 registry
  /// 中的元数据，不做任何 IO/验签——验签已在 [promoteAndGetRoot] 打开路径完成。
  static Future<Package?> getActivePackage(String name) async {
    await whenInitialized;
    if (!_initialized) return null;
    return packageService.getActivePackage(name);
  }

  /// 按 bundle name 查询最近一次下载进度（0.0~1.0；1.0=完成，-1.0=失败/取消）。
  /// 未下载过返回 0。pull 语义，供接入方进度条首帧读取；实时更新建议配
  /// [OfflineConfig.onDownloadProgress] 回调（push）。
  static double getDownloadProgress(String name) {
    if (!_initialized) return 0;
    return downloadService.getProgressByName(name);
  }

  /// 下次打开生效：提升 staged → active，并确保目标包已解压；返回 root（无则 null）。
  ///
  /// P0-3 on-open：返回 dir 前在子 isolate 做最后一道验签。
  /// 失败 → 删包 + 兜底内置。调用方在拿到 dir 后**直接加载 JS**，安全依赖于此
  /// 验签已通过（await 是同步语义，JS 不会先于验签跑起来）。
  static Future<String?> promoteAndGetRoot(String name) async {
    await whenInitialized;
    if (!_initialized) {
      print('[Offline] NOT initialized, returning null for "$name"');
      return null;
    }

    print('[Offline] promoteAndGetRoot("$name") start');
    // 强制更新：remote 存在 mustBeUpdated 且 ≠ 当前 active 时，同步等待下载
    // 并强制用新版本；下载失败回退旧 active（不阻断加载）。
    await _ensureForcedUpdate(name);

    var active = await packageService.promoteStaged(name);
    print('[Offline] promoteStaged("$name") = ${active?.name}');
    active ??= packageService.getActivePackage(name);
    print('[Offline] getActivePackage("$name") = ${active?.name}');

    // 无 active/staged → 解压内置包兜底（首启、被清理、远程未就绪等皆同一处理）。
    if (active == null) {
      print('[Offline] No active package, trying _ensureBuiltinActive');
      active = await _ensureBuiltinActive(name);
      print('[Offline] _ensureBuiltinActive("$name") = ${active?.name}');
    }
    if (active == null) {
      print('[Offline] No active package found for "$name", returning null');
      return null;
    }

    final dir = await _dirIfExists(active);
    print('[Offline] _dirIfExists = $dir');
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

  /// mustBeUpdated 包：征询用户后（若配置了 [OfflineConfig.onForcedUpdateConfirm]）
  /// 同步下载并提升为 active。拒绝或下载/提升失败回退旧 active（不阻断）。
  ///
  /// 同 name 并发去重：两个页面同时打开同一 bundle 时共享同一个 Future，
  /// 确认回调只会被调用一次。
  static Future<void> _ensureForcedUpdate(String name) {
    final existing = _forcedUpdateInflight[name];
    if (existing != null) return existing;
    final f = _doEnsureForcedUpdate(name);
    _forcedUpdateInflight[name] = f;
    f.whenComplete(() => _forcedUpdateInflight.remove(name));
    return f;
  }

  /// 在 promoteAndGetRoot 打开 bundle 前调用，实现"强制更新"语义：remote 中
  /// 存在 mustBeUpdated=true 且版本 ≠ 当前 active 时，先征询用户，同意才下载。
  /// minAppVersion 由 preparePackage 内部兜底（不满足返回 null → 回退旧版）。
  ///
  /// 全程不抛：任何异常（确认回调抛错、提升失败等）都退化为"用旧 active"，
  /// 强制更新不能反过来把 bundle 打不开。
  static Future<void> _doEnsureForcedUpdate(String name) async {
    try {
      // 冷启动时远程列表可能还没落地，先短暂等待，否则必然判成"无强制更新"。
      await _awaitRemoteList();

      final forced = packageService.findForcedUpdateTarget(name);
      if (forced == null) return;

      // 征询用户：未配置确认回调视为同意（默认行为，与既有强制更新语义一致）。
      final confirm = config.onForcedUpdateConfirm;
      if (confirm != null) {
        final ok = await confirm(name, forced.version);
        if (!ok) {
          logger(() =>
              'Forced update declined by user for $name, use current active');
          return; // 拒绝 → 跳过本次强制更新，后续流程继续用本地 active。
        }
      }

      logger(() => 'Forced update for $name: ${forced.versionShasumName}');
      // in-flight 去重：若后台 sync 已在下载该包，直接 join 其 Future。
      // 超时只放弃等待，不取消下载：后台跑完照样 staged，下次打开生效。
      final Package? ready;
      try {
        ready = await downloadService
            .preparePackage(forced)
            .timeout(config.forcedUpdateTimeout);
      } on TimeoutException {
        logger(() => 'Forced update timed out for $name after '
            '${config.forcedUpdateTimeout.inSeconds}s, fallback to old active');
        return;
      }
      if (ready == null) {
        logger(() => 'Forced update failed for $name, fallback to old active');
        return;
      }
      await packageService.applyReady([ready]);
      // 失败（如 mustBeUpdated 非 remote 最新被 _isStagedPromotable 丢弃）时
      // 静默回退旧 active。
      await packageService.promoteStaged(name);
    } catch (e) {
      logger(() => 'Forced update error for $name: $e, use current active');
    }
  }

  /// 等远程列表就绪，最多 [OfflineConfig.forcedUpdateRemoteWait]。
  /// 超时 / 未启动同步 / 配置为零都直接返回，由调用方按"无强制更新"继续。
  static Future<void> _awaitRemoteList() async {
    final wait = config.forcedUpdateRemoteWait;
    if (wait <= Duration.zero) return;
    final c = _remoteListReady;
    if (c == null || c.isCompleted) return;
    try {
      await c.future.timeout(wait);
    } on TimeoutException {
      logger(() => 'Remote package list not ready in ${wait.inMilliseconds}ms, '
          'skip forced update check');
    }
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
