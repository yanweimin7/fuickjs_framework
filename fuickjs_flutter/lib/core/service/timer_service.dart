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
      timers.remove(id)?.cancel();

      final delay = asIntOrNull(m['delay']) ?? 0;
      final isInterval = (m['isInterval'] ?? false) as bool;

      if (isInterval) {
        timers[id] = Timer.periodic(Duration(milliseconds: delay), (
          timer,
        ) async {
          if (isDisposed) {
            timer.cancel();
            return;
          }
          try {
            // 在 Isolate 模式下 controller 为空，直接通过 ctx 调用
            // controller?.jsProxy.handleTimer(id);
            proxy.handleTimer(id);
          } catch (e) {
            timer.cancel();
            timers.remove(id);
          }
        });
      } else {
        timers[id] = Timer(Duration(milliseconds: delay), () async {
          if (isDisposed) return;
          timers.remove(id);
          try {
            // 在 Isolate 模式下 controller 为空，直接通过 ctx 调用
            // controller?.jsProxy.handleTimer(id);
            proxy.handleTimer(id);
          } catch (e) {
            logger.e('Error calling handleTimer: $e');
          }
        });
      }
      return null;
    });

    registerMethod('deleteTimer', (args) {
      final m = args is Map ? args : {};
      final id = asInt(m['id']);
      timers.remove(id)?.cancel();
      return null;
    });
  }

  @override
  void dispose() {
    for (final timer in timers.values) {
      timer.cancel();
    }
    timers.clear();
    super.dispose();
  }
}
