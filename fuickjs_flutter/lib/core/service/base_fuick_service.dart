import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:flutter/foundation.dart';

import '../container/fuick_app_controller.dart';
import '../logger.dart';

typedef SyncMethodHandler = dynamic Function(dynamic args);
typedef AsyncMethodHandler = Future<dynamic> Function(dynamic args);

abstract class BaseFuickService {
  String get name;
  final Map<String, SyncMethodHandler> syncMethods = {};
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

  void registerMethod(String method, SyncMethodHandler handler) {
    syncMethods[method] = (args) {
      if (_isDisposed) {
        logger.w(
          '[Service] Warning: Calling method $method on disposed service',
        );
        return null;
      }
      return handler(args);
    };
  }

  void registerAsyncMethod(String method, AsyncMethodHandler handler) {
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
    syncMethods.clear();
    asyncMethods.clear();
  }
}
