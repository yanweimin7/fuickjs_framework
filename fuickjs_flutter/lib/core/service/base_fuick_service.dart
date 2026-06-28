import 'package:fjs_engine/core/jscontext_interface.dart';

import '../container/fuick_app_controller.dart';
import '../logger.dart';

typedef SyncMethodHandler = dynamic Function(dynamic args);
typedef AsyncMethodHandler = Future<dynamic> Function(dynamic args);

/// 基础 service —— 只允许注册异步方法。
///
/// 同步桥（`dartCallNative`）只能在 worker isolate 命中真正的同步 handler，
/// 而 worker isolate 只白名单暴露给 `TimerService` / `ConsoleService` /
/// `FileSystemService` 这 3 个跑在 worker 中的 service。
/// 因此同步注册能力 `registerMethod` 不放在这里 —— 见 [SyncFuickService]。
abstract class BaseFuickService {
  String get name;
  final Map<String, AsyncMethodHandler> asyncMethods = {};

  late IQuickJsContext ctx;
  FuickAppController? controller;
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  void init(IQuickJsContext context, FuickAppController? appController) {
    ctx = context;
    controller = appController;
    _isDisposed = false;
  }

  void registerAsyncMethod(String method, AsyncMethodHandler handler) {
    if (asyncMethods.containsKey(method)) {
      logger.w(
        '[Service] $name.registerAsyncMethod: method "$method" already registered, overwriting old handler.',
      );
    }
    asyncMethods[method] = (args) async {
      if (_isDisposed) {
        logger.w(
          '[Service] Warning: Calling async method $method on disposed service',
        );
        return null;
      }
      return await handler(args);
    };
  }

  void dispose() {
    _isDisposed = true;
    asyncMethods.clear();
  }
}
