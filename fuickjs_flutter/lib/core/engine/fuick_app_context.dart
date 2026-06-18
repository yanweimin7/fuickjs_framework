import 'dart:convert';

import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:flutter/cupertino.dart';

import '../../offline/offline.dart';
import '../container/fuick_app_controller.dart';
import '../logger.dart';
import 'bundle_compiler.dart';
import 'bundle_preloader.dart';
import 'jscontext_delegate.dart';
import 'worker.dart';

/// 预渲染页面描述
class PrewarmPageConfig {
  final String path;
  final Map<String, dynamic> params;

  const PrewarmPageConfig(this.path, [this.params = const {}]);
}

class FuickAppContext {
  final String appName;

  final bool useAotCode;
  final String? debugBusinessCode;
  final Map<String, dynamic>? sourceMap;
  final String? cachedBundleRoot;

  /// init 完成后需要预渲染的页面列表
  List<PrewarmPageConfig>? _pendingPrewarmPages;

  late IQuickJsContext ctx;
  late FuickAppController appController;
  final ValueNotifier<bool> isReady = ValueNotifier<bool>(false);

  /// isolate 侧 contextId，用于向 isolate 发送 sourcemap 等数据。
  String? _contextId;

  FuickAppContext({
    required this.appName,
    this.useAotCode = false,
    this.debugBusinessCode,
    this.sourceMap,
    this.cachedBundleRoot,
  });

  Future<void>? _initFuture;

  Future<void> init() {
    final inflight = _initFuture;
    if (inflight != null) return inflight;
    final future = _doInit();
    _initFuture = future;
    // 失败时清空 _initFuture，允许调用方重试；不在 _doInit 内部清，是为了避免
    // 同一时间窗内并发 init() 重复触发引擎初始化。
    future.catchError((e) {
      _initFuture = null;
    });
    return future;
  }

  /// 预渲染页面（可在 init 完成前调用，会排队等 bundle 加载完后执行）
  void prewarmPage(String path, [Map<String, dynamic> params = const {}]) {
    if (_bundleLoaded) {
      appController.prewarmPage(path, params);
    } else {
      _pendingPrewarmPages ??= [];
      _pendingPrewarmPages!.add(PrewarmPageConfig(path, params));
    }
  }

  bool _bundleLoaded = false;

  /// 当前加载的 bundle 包根目录（动态包；null 表示走内置 assets/js）。
  String? _activeBundleRoot;
  String? get activeBundleRoot => _activeBundleRoot;

  Future<void> _doInit() async {
    final stopwatch = Stopwatch()..start();

    final rootFuture = _resolveBundleRoot();
    rootFuture.then((root) {
      _activeBundleRoot = root ?? cachedBundleRoot;
      if (root != null) {
        BundlePreloader()
            .prewarm(appName, useAot: useAotCode, packageRoot: root);
      }
    });

    try {
      await _initContext(stopwatch);
      isReady.value = true;
      final root = await rootFuture;
      _activeBundleRoot = root ?? cachedBundleRoot;
      await _loadBundle();
    } catch (e, s) {
      logger.e('FuickAppContext init failed: $e\n$s');
      isReady.value = false;
      rethrow;
    }
  }

  /// 解析 bundle 包根目录：触发"下次打开"提升与内置懒解压。
  Future<String?> _resolveBundleRoot() async {
    try {
      if (Offline.initialized) {
        return await Offline.promoteAndGetRoot(appName);
      }
    } catch (e) {
      logger.e('resolve bundle root failed: $e');
    }
    return null;
  }

  /// 注入 globalThis.__FUICK_BUNDLE__（eval 业务代码之前）。
  Future<void> _injectBundleGlobals(String? root) async {
    final info = jsonEncode({'name': appName, 'root': root});
    await ctx.eval('globalThis.__FUICK_BUNDLE__ = $info;', returnValue: false);
  }

  Future<void> _initContext(Stopwatch stopwatch) async {
    _contextId = '${appName}_${DateTime.now().microsecondsSinceEpoch}';
    await IsolateWorker.instance.ensureInitialized();
    logger.d(
        '[Performance] isolate init cost: ${stopwatch.elapsedMilliseconds}ms');
    final delegate = JsContextDelegate(_contextId!);
    await delegate.init();
    logger.d(
        '[Performance] JsContextDelegate.init cost: ${stopwatch.elapsedMilliseconds}ms');
    ctx = delegate;
    appController = FuickAppController(ctx);
  }

  /// 将 sourcemap 发送到 isolate 侧，供 ConsoleService 做堆栈解析。
  Future<void> _forwardSourceMap() async {
    if (sourceMap == null || _contextId == null) return;
    try {
      await IsolateWorker.instance
          .sendRequest(_contextId!, 'setSourceMap', sourceMap);
      logger.d('[Debug] Sourcemap forwarded to isolate');
    } catch (e) {
      logger.e('[Debug] Failed to forward sourcemap: $e');
    }
  }

  Future<void> _loadBundle() async {
    final stopwatch = Stopwatch()..start();
    try {
      if (debugBusinessCode != null) {
        await _injectBundleGlobals(_activeBundleRoot);
        // 有 sourcemap 时先发到 isolate，eval 后的 console.error 就能直接解析
        await _forwardSourceMap();
        await ctx.eval(debugBusinessCode!, returnValue: false);
        logger.d(
          '[Debug] Successfully loaded business bundle from debug payload',
        );
      } else {
        await _loadSingleBundle(appName, _activeBundleRoot);
      }
      logger.d(
        '[Performance] load bundle cost: ${stopwatch.elapsedMilliseconds}ms',
      );

      appController.isBundleLoaded.value = true;
      _bundleLoaded = true;

      // bundle 加载完成，执行排队的页面预渲染
      final pages = _pendingPrewarmPages;
      _pendingPrewarmPages = null;
      if (pages != null) {
        for (final page in pages) {
          appController.prewarmPage(page.path, page.params);
        }
      }
    } catch (e, s) {
      logger.e('加载 bundle 失败: $e\n$s');
    }
  }

  Future<void> _loadSingleBundle(String bundleName, String? root) async {
    await _injectBundleGlobals(root);
    // consume() 等待 IO 完成后立即释放 BundlePreloader 内的引用
    final content = await BundlePreloader()
        .consume(bundleName, useAot: useAotCode, packageRoot: root);
    if (content.bytecode != null) {
    logger.d('[Performance] load bundle bytes for $bundleName');
      await ctx.evalBinary(content.bytecode!, returnValue: false);
    } else if (content.source != null) {
      logger.d('[Performance] load bundle js for $bundleName');
      await ctx.eval(content.source!, returnValue: false);
      // 后台编译 JS → 字节码，下次启动直接加载 qjc（fire-and-forget）
      BundleCompiler.compileIfNeeded(
        ctx: ctx,
        source: content.source!,
        packageDir: root,
      );
    }
  }

  void dispose() {
    appController.dispose();
  }
}
