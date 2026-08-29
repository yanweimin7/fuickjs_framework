import 'package:fjs_engine/core/js_bridge.dart';
import 'package:fjs_engine/core/web/host_js_context.dart';
import 'package:fjs_engine/core/web/web_js_host.dart';
import 'package:fjs_engine/core/web/worker_js_bridge.dart';
import 'package:flutter/cupertino.dart';

import '../container/fuick_app_controller.dart';
import '../logger.dart';
import 'prewarm_page_config.dart';

/// Web 端 [FuickAppContext]：无 isolate、无 FFI、无 offline 分发。
///
/// - 桥有两种实现，都满足 [WebJsHost]：
///   [HostJsContext]（主线程，`<script src>`）与 `WorkerJsBridge`（Worker，
///   `importScripts`）。渲染链（[FuickAppController] / `AppServiceBinder` /
///   parsers）依赖窄接口 [JsBridge]，两种模式下**完全相同**。
/// - bundle 遵循传统 Web 发布方式（静态文件 + HTTP 缓存），无离线包体系。
class FuickAppContext {
  final String appName;

  final bool useAotCode;
  final String? debugBusinessCode;
  final Map<String, dynamic>? sourceMap;
  final String? cachedBundleRoot;

  /// Web 端 bundle 的 URL（相对或绝对）。主线程模式经 `<script src>` 加载，
  /// Worker 模式由 Worker 内 `importScripts` 加载。
  final String? bundleUrl;

  /// Worker 入口脚本 URL（fuickjs 的 `dist/worker/entry.js` 部署产物）。
  ///
  /// **这就是 Worker 模式的开关**：非空即尝试把 React + DSL 生成放进 Web Worker，
  /// 失败则自动回退主线程；留空则始终走主线程。不额外提供 mode 枚举，是因为
  /// 「有没有 Worker 脚本可用」本身就是唯一有意义的判据。
  final String? workerUrl;

  /// Worker 启动 + bundle 加载的握手超时，超时即回退主线程。
  static const Duration _workerStartupTimeout = Duration(seconds: 15);

  List<PrewarmPageConfig>? _pendingPrewarmPages;

  late JsBridge ctx;
  late FuickAppController appController;
  final ValueNotifier<bool> isReady = ValueNotifier<bool>(false);

  /// DSL 生产是否真的跑在 Worker 里。传了 [workerUrl] 也可能因浏览器不支持、
  /// 脚本 404、CSP 拦截或握手超时而回退，宿主埋点应读这个值而不是 [workerUrl]。
  /// 在 [init] 完成前无意义。
  bool get isWorkerActive => _workerActive;
  bool _workerActive = false;

  /// 若 [isWorkerActive] 为 false 且传了 [workerUrl]，记录回退原因（便于排查：
  /// 浏览器无 Worker / CSP / 脚本 404 / 握手超时）。没传 [workerUrl] 时为空。
  String? get workerFallbackReason => _workerFallbackReason;
  String? _workerFallbackReason;

  late WebJsHost _host;
  bool _bundleLoaded = false;

  /// 与 native 分支对齐的公开面。Web 没有离线包解压目录（bundle 走
  /// `<script src>` + HTTP 缓存），因此恒为 null。
  String? get activeBundleRoot => null;

  FuickAppContext({
    required this.appName,
    this.useAotCode = false,
    this.debugBusinessCode,
    this.sourceMap,
    this.cachedBundleRoot,
    this.bundleUrl,
    this.workerUrl,
  });

  Future<void>? _initFuture;

  Future<void> init() {
    final inflight = _initFuture;
    if (inflight != null) return inflight;
    final future = _doInit();
    _initFuture = future;
    future.catchError((e) {
      _initFuture = null;
    });
    return future;
  }

  void prewarmPage(String path, [Map<String, dynamic> params = const {}]) {
    if (_bundleLoaded) {
      appController.prewarmPage(path, params);
    } else {
      _pendingPrewarmPages ??= [];
      _pendingPrewarmPages!.add(PrewarmPageConfig(path, params));
    }
  }

  /// 选择桥实现。Worker 路径上的任何一种失败都回退主线程，绝不让整个 app 起不来
  /// —— Worker 只是性能优化，不是功能依赖。
  Future<WebJsHost> _createHost() async {
    final entryUrl = workerUrl;
    if (entryUrl == null || entryUrl.isEmpty) {
      return HostJsContext();
    }
    if (!WorkerJsBridge.isSupported) {
      _workerFallbackReason = 'no Worker constructor in this browser';
      logger.w('FuickAppContext(web): this browser has no Worker constructor; '
          'falling back to the main thread.');
      return HostJsContext();
    }

    try {
      final bridge = await WorkerJsBridge.spawn(
        workerUrl: entryUrl,
        bundleUrl: bundleUrl ?? '',
        timeout: _workerStartupTimeout,
      );
      _workerActive = true;
      logger.d('FuickAppContext(web): DSL production runs in a Web Worker.');
      return bridge;
    } catch (e, s) {
      // 覆盖：Worker 构造抛错（CSP worker-src / file:// origin）、入口脚本 404、
      // bundle importScripts 失败、握手超时。一律降级，不外抛。
      _workerFallbackReason = 'worker startup failed: $e';
      logger.w('FuickAppContext(web): worker startup failed, falling back to '
          'the main thread: $e\n$s');
      return HostJsContext();
    }
  }

  Future<void> _doInit() async {
    _host = await _createHost();
    ctx = _host;
    // 顺序关键：先建 controller（其构造触发 AppServiceBinder.init，把
    // dartCallNative / dartCallNativeAsync 注册到 globalThis），再加载 bundle，
    // 保证 bundle 里的 initApp() 能立即用到这两个桥。
    //
    // Worker 模式下 bundle 已在 _createHost 的握手阶段加载完（Worker 内
    // importScripts），此处顺序看似倒置：bundle 顶层若发起 Native 调用，会先落到
    // WorkerJsBridge 的缓冲区，等这行挂上回调后按原序补发，JS 侧只是 Promise
    // 晚一点 resolve。
    appController = FuickAppController(ctx);

    try {
      // 与 native 对齐：桥就绪即 isReady（native 是引擎 init 完就置 true），
      // bundle 加载是后续阶段，其结果由 appController.isBundleLoaded 表达
      // —— FuickPageView 监听的是后者，不是 isReady。
      isReady.value = true;
      await _loadBundle();
    } catch (e, s) {
      logger.e('FuickAppContext(web) init failed: $e\n$s');
      isReady.value = false;
      rethrow;
    }
  }

  /// 与 native 的 `_loadBundle` 保持同一错误策略：失败只记日志、不外抛。
  /// 否则 `init()` 会 reject，而 `FuickAppView.initState` 里的 `_initContext()`
  /// 没有 catch，会变成未捕获异步异常 + 永久 loading。加载失败时
  /// `isBundleLoaded` 保持 false，页面停在 loading 态，语义与 native 一致。
  Future<void> _loadBundle() async {
    final stopwatch = Stopwatch()..start();
    try {
      final url = bundleUrl;
      if (url == null || url.isEmpty) {
        if (debugBusinessCode != null) {
          // Web 端不引入 eval；debug 源码注入是 native 调试专用能力。
          logger
              .e('FuickAppContext(web): debugBusinessCode (source eval) is not '
                  'supported on web; provide bundleUrl to load the bundle via '
                  '<script src>.');
          return;
        }
        // 合法用法：宿主已在 index.html 里用静态 <script> 引入 bundle，
        // 此时 globalThis.fuickjs 早已就绪，直接置 isBundleLoaded 即可。
        // 若宿主其实什么都没引，首次 render 会在 invoke 时报
        // 'object "fuickjs" not found on globalThis'。
        logger.w('FuickAppContext(web): no bundleUrl provided; assuming the '
            'bundle is already loaded by the host page (static <script>).');
      }

      // 主线程模式挂 <script src>；Worker 模式在握手阶段已 importScripts，
      // 这里是幂等 no-op。
      await _host.loadBundle(url ?? '');

      logger.d('[Performance] load bundle (web, '
          '${_workerActive ? 'worker' : 'main-thread'}) cost: '
          '${stopwatch.elapsedMilliseconds}ms');
      appController.isBundleLoaded.value = true;
      _bundleLoaded = true;

      final pages = _pendingPrewarmPages;
      _pendingPrewarmPages = null;
      if (pages != null) {
        for (final page in pages) {
          appController.prewarmPage(page.path, page.params);
        }
      }
    } catch (e, s) {
      logger.e('加载 bundle 失败 (web): $e\n$s');
    }
  }

  void dispose() {
    appController.dispose();
  }
}
