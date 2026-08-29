import 'package:fjs_engine/core/js_bridge.dart';

import '../container/fuick_app_controller.dart';
import '../logger.dart';
import 'base_fuick_service.dart';
import 'native_services.dart';
import 'sync_fuick_service.dart';

class AppServiceBinder {
  List<BaseFuickService> _services = [];
  Map<String, SyncMethodHandler> _handlers = {};
  Map<String, AsyncMethodHandler> _asyncHandlers = {};

  /// Dart 端注册的 sync handler 名（用于错误信息,避免写出"只允许白名单 sync"
  /// 这类写死的旧文案,改为动态从实际注册情况生成）。
  List<String> _registeredSyncNames = const [];

  /// Dart 端注册的 async handler 名（用于错误信息）。
  List<String> _registeredAsyncNames = const [];

  void init(
    JsBridge ctx,
    FuickAppController? controller, {
    List<Type>? allowedServices,
    Future<dynamic> Function(String, dynamic)? fallbackAsync,

    /// sync 路径（dartCallNative）未命中 sync handler 时,是否自动转 async 路径
    /// (await async handler 后返回结果)。默认 false 保持历史严格语义;worker
    /// isolate 场景应设为 true,让业务 service(只能注册 async)的"sync 调用"
    /// 不再硬崩,而是经 trampoline 转发到主 isolate 拿到结果。
    bool allowSyncToAsyncFallback = false,
  }) {
    _services = NativeServiceManager()
        .serviceBuilders
        .map((builder) => builder())
        .where((service) {
      if (allowedServices == null) return true;
      return allowedServices.contains(service.runtimeType);
    }).map((service) {
      service.init(ctx, controller);
      return service;
    }).toList();

    _handlers = {};
    _asyncHandlers = {};

    for (var e in _services) {
      // 同步方法只在 [SyncFuickService] 子类上 —— 即 worker isolate 白名单
      // （Timer / Console / FileSystem）。其他业务 service 只能挂异步方法。
      if (e is SyncFuickService) {
        for (var entry in e.syncMethods.entries) {
          _handlers['${e.name}.${entry.key}'] = entry.value;
        }
      }
      for (var entry in e.asyncMethods.entries) {
        _asyncHandlers['${e.name}.${entry.key}'] = entry.value;
      }
    }
    _registeredSyncNames = _handlers.keys.toList()..sort();
    _registeredAsyncNames = _asyncHandlers.keys.toList()..sort();

    // sync 路径(dartCallNative):
    // - 命中 sync handler → 直接同步执行,零开销。
    // - 未命中 sync handler:
    //   a) allowSyncToAsyncFallback=true(worker isolate)→ 优先转 async 路径:
    //      先尝试在当前 isolate 命中 async handler(白名单内 service 的 async
    //      method),仍未命中则走 fallbackAsync 转发到主 isolate,await 完返回。
    //   b) allowSyncToAsyncFallback=false(主 isolate)→ 抛错。
    //      - 命中 async handler(业务 service)→ 抛"registered as async"。
    //      - 完全没注册 → 抛"no handler registered"。
    //
    // allowSyncToAsyncFallback 路径下 sync 调用方会被 QuickJS 阻塞
    // 等 await 完(worker isolate 等主 isolate 转发的耗时),这是为兼容"JS
    // 端混用 sync/async"必须付出的代价。原本设计期望 JS 端用
    // dartCallNativeAsync,但 bundle 代码在跑 JS 端不能改,所以兜底。
    ctx.onCallNative = (method, args) {
      final syncH = _handlers[method];
      if (syncH != null) {
        try {
          return syncH(args);
        } catch (e, s) {
          logger.e("failed to callNative $method $e , $s");
          rethrow;
        }
      }
      // 未命中 sync handler,根据 allowSyncToAsyncFallback 决定行为。
      if (allowSyncToAsyncFallback) {
        // 智能转发: 同步路径未命中时,先查本 isolate async handler,
        // 再走 fallbackAsync (worker isolate 场景下转发到主 isolate)。
        // 整个 sync 调用会被 QuickJS 阻塞等结果。
        final asyncH = _asyncHandlers[method];
        if (asyncH != null) {
          try {
            return asyncH(args);
          } catch (e, s) {
            logger.e("failed to callNative(sync→async) $method $e , $s");
            rethrow;
          }
        }
        if (fallbackAsync != null) {
          try {
            return fallbackAsync(method, args);
          } catch (e, s) {
            logger.e("failed to callNative(sync→fallback) $method $e , $s");
            rethrow;
          }
        }
        // 都没有 → 抛"no handler registered"（worker isolate 同样）。
        throw StateError(
          'dartCallNative("$method") is not allowed: no handler registered. '
          'Registered sync handlers: [${_registeredSyncNames.join(", ")}]. '
          'Registered async handlers: [${_registeredAsyncNames.join(", ")}].',
        );
      }
      // 主 isolate 严格策略: 区分"业务 service 注册了 async"和"完全没注册"。
      final asyncH = _asyncHandlers[method];
      if (asyncH != null) {
        throw StateError(
          'dartCallNative("$method") is not allowed: method is registered as async. '
          'Use dartCallNativeAsync("$method", args) instead.',
        );
      }
      throw StateError(
        'dartCallNative("$method") is not allowed: no handler registered.',
      );
    };

    ctx.onCallNativeAsync = (method, args) async {
      final asyncH = _asyncHandlers[method];
      if (asyncH != null) {
        try {
          return await asyncH(args);
        } catch (e, s) {
          logger.e("failed to callNativeAsync $method $e , $s");
          rethrow;
        }
      }
      // TS 异步调用命中 Dart 同步方法（含 sync 返回 Future 的情况）。
      final syncH = _handlers[method];
      if (syncH != null) {
        try {
          return await Future.sync(() => syncH(args));
        } catch (e, s) {
          logger.e("failed to callNativeAsync(sync) $method $e , $s");
          rethrow;
        }
      }
      return fallbackAsync?.call(method, args);
    };
  }

  T? getService<T extends BaseFuickService>() {
    for (final service in _services) {
      if (service is T) return service;
    }
    return null;
  }

  void dispose() {
    _handlers = {};
    _asyncHandlers = {};
    for (final service in _services) {
      service.dispose();
    }
    _services = [];
  }
}
