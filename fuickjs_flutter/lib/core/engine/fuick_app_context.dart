import 'dart:convert';
import 'dart:io';

import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../../offline/offline.dart';
import '../container/fuick_app_controller.dart';
import '../logger.dart';
import '../service/error_report_service.dart';
import 'bundle_compiler.dart';
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

  /// 在 main isolate 设置 sourcemap，供 ErrorReportService 做堆栈解析。
  /// ErrorReportService 跑在 main isolate（不在 isolate 的 allowedServices 里），
  /// JS 调用 ErrorReport.report 时通过 fallbackSync 转发到 main isolate 执行。
  void _forwardSourceMap() {
    if (sourceMap == null) return;
    try {
      appController
          ?.getService<ErrorReportService>()
          ?.setSourceMap(sourceMap);
      logger.d('[Debug] Sourcemap set on main isolate');
    } catch (e) {
      logger.e('[Debug] Failed to set sourcemap: $e');
    }
  }

  Future<void> _loadBundle() async {
    final stopwatch = Stopwatch()..start();
    try {
      if (debugBusinessCode != null) {
        await _injectBundleGlobals(_activeBundleRoot);
        // 有 sourcemap 时先设置到 main isolate，eval 后的 ErrorReport.report 就能直接解析
        _forwardSourceMap();
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

  /// 加载 bundle 的统一入口：fs 路径走 *FileFromPath（零拷贝），
  /// assets 路径走 rootBundle 内置读取。
  Future<void> _loadSingleBundle(String bundleName, String? root) async {
    await _injectBundleGlobals(root);
    if (root != null && root.isNotEmpty) {
      await _loadFromPackageDir(bundleName, root);
    } else {
      await _loadFromAssets(bundleName);
    }
  }

  /// 动态包目录加载：先 peek qjc 头判版本，匹配则走 *FileFromPath
  /// 让 C 层直接 fopen 读取，避免 Dart 堆持有多 MB 字节码。
  Future<void> _loadFromPackageDir(String bundleName, String root) async {
    final qjc = File(p.join(root, 'bundle.qjc'));
    if (await qjc.exists()) {
      final peeked = await _peekBcVersionOfFile(qjc);
      final engineVersion = await ctx.bytecodeVersion;
      if (peeked != null && peeked != engineVersion) {
        logger.w(
          '[BundleLoader] bytecode version mismatch: file=$peeked engine=$engineVersion — root=$root',
        );
        // 隔离旧 qjc：rename 让下一次 IO 自然 fall through 到 .js
        try {
          await qjc.rename(p.join(root, 'bundle.qjc.stale'));
          logger.d('[BundleLoader] renamed stale bundle.qjc → .stale at $root');
        } catch (err) {
          logger
              .w('[BundleLoader] failed to quarantine stale bundle.qjc: $err');
        }
        await _evalJsAt(bundleName, root);
        return;
      }
      logger.d('[Performance] load bundle bytes (fromPath) for $bundleName');
      await ctx.evalBinaryFileFromPath(qjc.path, returnValue: false);
      return;
    }
    await _evalJsAt(bundleName, root);
  }

  /// 内置 assets 加载（无 packageRoot 时）。
  Future<void> _loadFromAssets(String bundleName) async {
    if (useAotCode) {
      try {
        final byteData = await rootBundle.load('assets/js/$bundleName.qjc');
        final bc = byteData.buffer
            .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
        logger.d('[Performance] load bundle bytes for $bundleName');
        await ctx.evalBinary(bc, returnValue: false);
        return;
      } catch (_) {}
    }
    final source =
        await rootBundle.loadString('assets/js/$bundleName.js', cache: false);
    logger.d('[Performance] load bundle js for $bundleName');
    await ctx.eval(source, returnValue: false);
    BundleCompiler.compileIfNeeded(
      ctx: ctx,
      source: source,
      packageDir: null,
    );
  }

  /// 加载 fs 上的 .js：C 层直接 fopen 读取。
  /// 后台编译需要 source 文本，fs 路径下读一次（频率低，可接受）。
  Future<void> _evalJsAt(String bundleName, String root) async {
    final js = File(p.join(root, 'bundle.js'));
    if (!await js.exists()) {
      throw StateError(
        'No JS source fallback for $bundleName at $root after '
        'quarantining stale bytecode.',
      );
    }
    logger.d('[Performance] load bundle js (fromPath) for $bundleName');
    await ctx.evalFileFromPath(js.path, returnValue: false);
    final sourceText = await js.readAsString();
    BundleCompiler.compileIfNeeded(
      ctx: ctx,
      source: sourceText,
      packageDir: root,
    );
  }

  /// 读取 qjc 首字节作为 BC_VERSION 预判。
  static Future<int?> _peekBcVersionOfFile(File f) async {
    final raf = await f.open();
    try {
      final first = await raf.read(1);
      return first.isNotEmpty ? first[0] : null;
    } finally {
      await raf.close();
    }
  }

  void dispose() {
    appController.dispose();
  }
}
