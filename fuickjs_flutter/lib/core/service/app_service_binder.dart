import 'dart:async';

import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:flutter/cupertino.dart';

import '../container/fuick_app_controller.dart';
import '../logger.dart';
import 'base_fuick_service.dart';
import 'native_services.dart';

class AppServiceBinder {
  List<BaseFuickService> _services = [];
  Map<String, SyncMethodHandler> _handlers = {};
  Map<String, AsyncMethodHandler> _asyncHandlers = {};

  void init(
    IQuickJsContext ctx,
    FuickAppController? controller, {
    List<Type>? allowedServices,
    FutureOr<dynamic> Function(String, dynamic)? fallbackSync,
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
      for (var entry in e.syncMethods.entries) {
        _handlers['${e.name}.${entry.key}'] = entry.value;
      }
      for (var entry in e.asyncMethods.entries) {
        _asyncHandlers['${e.name}.${entry.key}'] = entry.value;
      }
    }

    ctx.onCallNative = (method, args) {
      if (_handlers.containsKey(method)) {
        try {
          return _handlers[method]!(args);
        } catch (e, s) {
          logger.e("failed to callNative $method $e , $s");
        }
      } else if (_asyncHandlers.containsKey(method)) {
        logger.w(
          '[Service] Warning: Method "$method" is registered as async but called synchronously. '
          'Consider using dartCallNativeAsync or registerMethod instead.',
        );
        try {
          return _asyncHandlers[method]!(args);
        } catch (e, s) {
          logger.e("failed to callNative(async fallback) $method $e , $s");
        }
      }
      return fallbackSync?.call(method, args);
    };

    ctx.onCallNativeAsync = (method, args) async {
      final asyncH = _asyncHandlers[method];
      if (asyncH != null) {
        try { return await asyncH(args); } catch (e, s) {
          logger.e("failed to callNativeAsync $method $e , $s");
          rethrow;
        }
      }
      final syncH = _handlers[method];
      if (syncH != null) {
        try { return syncH(args); } catch (e, s) {
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
