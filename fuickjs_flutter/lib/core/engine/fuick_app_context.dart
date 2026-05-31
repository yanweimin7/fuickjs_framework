import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:flutter/cupertino.dart';

import '../container/fuick_app_controller.dart';
import '../logger.dart';
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

  /// init 完成后需要预渲染的页面列表
  List<PrewarmPageConfig>? _pendingPrewarmPages;

  late IQuickJsContext ctx;
  late FuickAppController appController;
  final ValueNotifier<bool> isReady = ValueNotifier<bool>(false);

  FuickAppContext({
    required this.appName,
    this.useAotCode = false,
    this.debugBusinessCode,
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

  Future<void> _doInit() async {
    final stopwatch = Stopwatch()..start();

    // Start bundle IO loading in parallel with engine initialization
    if (debugBusinessCode == null) {
      BundlePreloader().prewarm(appName, useAot: useAotCode);
    }

    try {
      await _initContext(stopwatch);
      isReady.value = true;
      await _loadBundle();
    } catch (e, s) {
      logger.e('FuickAppContext init failed: $e\n$s');
      isReady.value = false;
      rethrow;
    }
  }

  Future<void> _initContext(Stopwatch stopwatch) async {
    final contextId = '${appName}_${DateTime.now().microsecondsSinceEpoch}';
    await IsolateWorker.instance.ensureInitialized();
    logger.d('[Performance] isolate init cost: ${stopwatch.elapsedMilliseconds}ms');
    final delegate = JsContextDelegate(contextId);
    await delegate.init();
    logger.d('[Performance] JsContextDelegate.init cost: ${stopwatch.elapsedMilliseconds}ms');
    ctx = delegate;
    appController = FuickAppController(ctx);
  }

  Future<void> _loadBundle() async {
    final stopwatch = Stopwatch()..start();
    try {
      if (debugBusinessCode != null) {
        await ctx.eval(debugBusinessCode!, returnValue: false);
        logger.d(
          '[Debug] Successfully loaded business bundle from debug payload',
        );
      } else {
        await _loadSingleBundle(appName);
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

  Future<void> _loadSingleBundle(String bundleName) async {
    try {
      // consume() 等待 IO 完成后立即释放 BundlePreloader 内的引用
      final content =
          await BundlePreloader().consume(bundleName, useAot: useAotCode);
      if (content.bytecode != null) {
        await ctx.evalBinary(content.bytecode!, returnValue: false);
      } else if (content.source != null) {
        await ctx.eval(content.source!, returnValue: false);
      }
    } catch (e) {
      logger.e('加载 bundle $bundleName 失败: $e');
      rethrow;
    }
  }

  void dispose() {
    appController.dispose();
  }
}
