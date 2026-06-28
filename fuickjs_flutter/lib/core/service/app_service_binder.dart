import 'package:fjs_engine/core/jscontext_interface.dart';

import '../container/fuick_app_controller.dart';
import '../logger.dart';
import 'base_fuick_service.dart';
import 'native_services.dart';
import 'sync_fuick_service.dart';

class AppServiceBinder {
  List<BaseFuickService> _services = [];
  Map<String, SyncMethodHandler> _handlers = {};
  Map<String, AsyncMethodHandler> _asyncHandlers = {};

  void init(
    IQuickJsContext ctx,
    FuickAppController? controller, {
    List<Type>? allowedServices,
    Future<dynamic> Function(String, dynamic)? fallbackAsync,
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

    // 严格策略: dartCallNative (sync) 只能命中 Dart 端 registerMethod 注册的同步方法。
    // 命中异步方法 / 未注册方法 都要立即抛错,绝不允许静默返回 Future ——
    // 在 worker isolate 这会经 trampoline 走主 isolate 拿到 Promise 对象,
    // JS 侧继续当普通对象用会出 viewInsets == undefined 之类的隐蔽 bug。
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
      final asyncH = _asyncHandlers[method];
      if (asyncH != null) {
        throw StateError(
          'dartCallNative("$method") is not allowed: method is registered as async. '
          'Use dartCallNativeAsync("$method", args) instead.',
        );
      }
      final hint = allowedServices == null
          ? ''
          : ' Worker isolate only exposes ${_services.map((s) => s.name).join(", ")} '
              'via dartCallNative (sync). Use dartCallNativeAsync to call main-isolate services.';
      throw StateError(
        'dartCallNative("$method") is not allowed: no handler registered.$hint',
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
