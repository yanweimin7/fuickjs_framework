import 'dart:async';

import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:fuickjs_flutter/core/engine/fuick_js_proxy.dart';

import '../container/fuick_app_controller.dart';
import '../logger.dart';
import '../utils/extensions.dart';
import 'base_fuick_service.dart';

class TimerService extends BaseFuickService {
  @override
  String get name => 'Timer';

  final Map<int, Timer> timers = {};

  late FuickJsProxy proxy;

  @override
  void init(IQuickJsContext context, FuickAppController? appController) {
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
        logger.w('TimerService: createTimer($id) — cancelled existing timer with same id.');
      }

      final delay = asIntOrNull(m['delay']) ?? 0;
      final isInterval = (m['isInterval'] ?? false) as bool;
      logger.d('TimerService: createTimer(id=$id, delay=${delay}ms, isInterval=$isInterval), '
          'activeTimers=${timers.length}');

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
          logger.d('TimerService: Timeout timer $id fired, remainingTimers=${timers.length}');
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
        logger.d('TimerService: deleteTimer($id) — cancelled and removed. '
            'remainingTimers=${timers.length}');
      } else {
        logger.w('TimerService: deleteTimer($id) — timer not found. '
            'activeIds=${timers.keys.toList()}, remainingTimers=${timers.length}');
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
