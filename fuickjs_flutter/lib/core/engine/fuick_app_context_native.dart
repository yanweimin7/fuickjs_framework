import 'dart:convert';
import 'dart:io';

import 'package:fjs_engine/core/js_bridge.dart';
import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../../offline/offline.dart';
import '../container/fuick_app_controller.dart';
import '../logger.dart';
import '../service/error_report_service.dart';
import '../version.dart';
import 'bundle_compiler.dart';
import 'jscontext_delegate.dart';
import 'prewarm_page_config.dart';
import 'worker.dart';

class FuickAppContext {
  final String appName;

  final bool useAotCode;
  final String? debugBusinessCode;
  final Map<String, dynamic>? sourceMap;
  final String? cachedBundleRoot;

  /// Web 专用 bundle URL；native 分支忽略（保留签名以与 web 分支对齐）。
  final String? bundleUrl;

  /// Web 专用 Worker 入口 URL；native 分支忽略（保留签名以与 web 分支对齐）。
  /// native 的 JS 本就跑在独立 isolate 上，不需要这个开关。
  final String? workerUrl;

  /// native 的 JS 恒在独立 isolate 执行，这个 web 概念在此恒为 false。
  bool get isWorkerActive => false;

  /// native 无 Web Worker 概念，恒为 null。
  String? get workerFallbackReason => null;

  /// init 完成后需要预渲染的页面列表
  List<PrewarmPageConfig>? _pendingPrewarmPages;

  /// 渲染层依赖窄接口 [JsBridge]；引擎层能力（eval / bytecode / ...）经 [_engine]
  /// 窄化访问（native 分支 ctx 恒为 [IQuickJsContext]）。
  late JsBridge ctx;
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
    this.bundleUrl,
    this.workerUrl,
  });

  /// native 分支下 [ctx] 恒为 [IQuickJsContext]，窄化后暴露引擎能力给本类内部使用。
  IQuickJsContext get _engine => ctx as IQuickJsContext;

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
  ///
  /// Offline.promoteAndGetRoot 内部会 await whenInitialized，init 进行中也会
  /// 等待而非静默回退内置；仅在 init 从未成功过时才返回 null（走内置 assets）。
  Future<String?> _resolveBundleRoot() async {
    try {
      final root = await Offline.promoteAndGetRoot(appName);
      return root;
    } catch (e) {
      logger.w('resolve bundle root failed: $e');
    }
    return null;
  }

  /// 注入 globalThis.__FUICK_BUNDLE__ = { name, version, sha256, root, frameworkVersion }
  /// （eval 业务代码之前）。
  ///
  /// version/sha256 来自 registry 的 active Package 元数据；内置 assets 或
  /// debug payload 场景无对应包时为 null。查询失败不阻断加载（仅降级为 null）。
  /// frameworkVersion 为框架层（Flutter）版本，供业务侧做运行时兼容性判断。
  Future<void> _injectBundleGlobals(String? root) async {
    String? version;
    String? sha256;
    try {
      final pkg = await Offline.getActivePackage(appName);
      version = pkg?.version;
      sha256 = pkg?.sha256;
    } catch (e) {
      logger.w('resolve bundle meta failed: $e');
    }
    final info = jsonEncode({
      'name': appName,
      'version': version,
      'sha256': sha256,
      'root': root,
      'frameworkVersion': fuickjsFrameworkVersion,
    });
    await _engine.eval('globalThis.__FUICK_BUNDLE__ = $info;',
        returnValue: false);
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

  /// 将 sourcemap 注入 main isolate 侧的 ErrorReportService，供其做堆栈还原。
  /// ErrorReportService 跑在 main isolate（不在 isolate 的 allowedServices 中），
  /// 通过 getService 直接访问，无需跨 isolate 通信。
  Future<void> _forwardSourceMap() async {
    if (sourceMap == null) return;
    final errorService =
        appController.serviceBinder.getService<ErrorReportService>();
    errorService?.setSourceMap(sourceMap);
    logger.d('[Debug] Sourcemap injected to ErrorReportService');
  }

  Future<void> _loadBundle() async {
    final stopwatch = Stopwatch()..start();
    try {
      if (debugBusinessCode != null) {
        await _injectBundleGlobals(_activeBundleRoot);
        // 有 sourcemap 时先发到 isolate，eval 后的 ErrorReport.report 就能直接解析
        await _forwardSourceMap();
        await _engine.eval(debugBusinessCode!, returnValue: false);
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
      final engineVersion = await _engine.bytecodeVersion;
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
      await _engine.evalBinaryFileFromPath(qjc.path, returnValue: false);
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
        await _engine.evalBinary(bc, returnValue: false);
        return;
      } catch (_) {}
    }
    final source =
        await rootBundle.loadString('assets/js/$bundleName.js', cache: false);
    logger.d('[Performance] load bundle js for $bundleName');
    await _engine.eval(source, returnValue: false);
    BundleCompiler.compileIfNeeded(
      ctx: _engine,
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
    await _engine.evalFileFromPath(js.path, returnValue: false);
    final sourceText = await js.readAsString();
    BundleCompiler.compileIfNeeded(
      ctx: _engine,
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
