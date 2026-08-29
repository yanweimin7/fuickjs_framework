import 'dart:async';

import 'package:fjs_engine/core/js_bridge.dart';
import 'package:fuickjs_flutter/core/engine/fuick_js_proxy.dart';

import '../container/fuick_app_controller.dart';
import '../logger.dart';
import '../utils/extensions.dart';
import 'sync_fuick_service.dart';

/// 跑在 worker isolate 白名单中的 service —— 保留 `registerMethod` 同步注册能力。
/// 详见 [SyncFuickService] 注释。
class TimerService extends SyncFuickService {
  @override
  String get name => 'Timer';

  final Map<int, Timer> timers = {};

  late FuickJsProxy proxy;

  @override
  void init(JsBridge context, FuickAppController? appController) {
    super.init(context, appController);
    proxy = FuickJsProxy(context);
  }

  TimerService() {
    registerMethod('createTimer', (args) {
      final m = args is Map ? args : {};
      final id = asInt(m['id']);

      // 先尝试取消已存在的同名定时器，防止重复
      final existing = timers.remove(id);
      if (existing != null) {
        existing.cancel();
      }

      final delay = asIntOrNull(m['delay']) ?? 0;
      final isInterval = (m['isInterval'] ?? false) as bool;
    
      if (isInterval) {
        timers[id] = Timer.periodic(Duration(milliseconds: delay), (
          timer,
        ) async {
          if (isDisposed) {
            logger.w('TimerService: Interval timer $id fired but service is disposed, cancelling.');
            timer.cancel();
            return;
          }
          try {
            // 在 Isolate 模式下 controller 为空，直接通过 ctx 调用
            // controller?.jsProxy.handleTimer(id);
            proxy.handleTimer(id);
          } catch (e) {
            logger.e('TimerService: Error calling handleTimer for interval $id: $e, cancelling timer.');
            timer.cancel();
            timers.remove(id);
          }
        });
      } else {
        timers[id] = Timer(Duration(milliseconds: delay), () async {
          if (isDisposed) {
            logger.w('TimerService: Timeout timer $id fired but service is disposed, skipping.');
            return;
          }
          timers.remove(id);
          try {
            // 在 Isolate 模式下 controller 为空，直接通过 ctx 调用
            // controller?.jsProxy.handleTimer(id);
            proxy.handleTimer(id);
          } catch (e) {
            logger.e('TimerService: Error calling handleTimer for timeout $id: $e');
          }
        });
      }
      return null;
    });

    registerMethod('deleteTimer', (args) {
      final m = args is Map ? args : {};
      final id = asInt(m['id']);
      final removed = timers.remove(id);
      if (removed != null) {
        removed.cancel();
      }
      return null;
    });
  }

  @override
  void dispose() {
    final count = timers.length;
    for (final timer in timers.values) {
      timer.cancel();
    }
    timers.clear();
    logger.w('TimerService: dispose() — cancelled $count active timers.');
    super.dispose();
  }
}
