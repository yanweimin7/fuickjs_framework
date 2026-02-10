import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:flutter/cupertino.dart';

import '../container/fuick_app_controller.dart';
import 'base_fuick_service.dart';
import 'native_services.dart';

class AppServiceBinder {
  final Map<IQuickJsContext, List<BaseFuickService>> _services = {};
  final Map<IQuickJsContext, Map<String, SyncMethodHandler>> _handlers = {};
  final Map<IQuickJsContext, Map<String, AsyncMethodHandler>> _asyncHandlers =
      {};

  void init(
    IQuickJsContext ctx,
    FuickAppController? controller, {
    List<Type>? allowedServices,
  }) {
    final services = NativeServiceManager()
        .serviceBuilders
        .map((builder) => builder())
        .where((service) {
      if (allowedServices == null) return true;
      return allowedServices.contains(service.runtimeType);
    }).map((service) {
      service.init(ctx, controller);
      return service;
    }).toList();

    _services[ctx] = services;

    final handlers = <String, SyncMethodHandler>{};
    final asyncHandlers = <String, AsyncMethodHandler>{};

    for (var e in services) {
      for (var entry in e.syncMethods.entries) {
        handlers['${e.name}.${entry.key}'] = entry.value;
      }
      for (var entry in e.asyncMethods.entries) {
        asyncHandlers['${e.name}.${entry.key}'] = entry.value;
      }
    }

    _handlers[ctx] = handlers;
    _asyncHandlers[ctx] = asyncHandlers;

    ctx.onCallNative = (method, args) {
      try {
        return handleNativeCall(ctx, method, args);
      } catch (e, s) {
        debugPrint("failed to callNative $method $e , $s");
      }
      return null;
    };

    ctx.onCallNativeAsync = (method, args) async {
      try {
        return await handleNativeCallAsync(ctx, method, args);
      } catch (e, s) {
        debugPrint("failed to callNativeAsync $method $e , $s");
        rethrow;
      }
    };
  }

  dynamic handleNativeCall(IQuickJsContext ctx, String method, dynamic args) {
    final h = _handlers[ctx]?[method];
    if (h != null) {
      return h(args);
    }
    return null;
  }

  Future<dynamic> handleNativeCallAsync(
    IQuickJsContext ctx,
    String method,
    dynamic args,
  ) async {
    final h = _asyncHandlers[ctx]?[method];
    if (h != null) {
      return await h(args);
    }
    // Fallback to sync handler if async handler not found
    final syncH = _handlers[ctx]?[method];
    if (syncH != null) {
      return syncH(args);
    }
    return null;
  }

  bool canHandle(IQuickJsContext ctx, String method) {
    return _handlers[ctx]?.containsKey(method) ?? false;
  }

  T? getService<T extends BaseFuickService>(IQuickJsContext ctx) {
    final services = _services[ctx];
    if (services != null) {
      for (final service in services) {
        if (service is T) {
          return service;
        }
      }
    }
    return null;
  }

  void dispose(IQuickJsContext ctx) {
    _handlers.remove(ctx);
    _asyncHandlers.remove(ctx);
    final services = _services.remove(ctx);
    if (services != null) {
      for (final service in services) {
        service.dispose();
      }
    }
  }
}
