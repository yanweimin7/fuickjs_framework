import 'package:flutter/material.dart';

import 'base_fuick_service.dart';

class ToastService extends BaseFuickService {
  @override
  String get name => 'Toast';

  ToastService() {
    registerAsyncMethod('show', (args) async {
      final String message;
      final int duration;

      if (args is Map) {
        message = args['message']?.toString() ?? '';
        final d = args['duration'];
        // duration 单位：JS 侧传秒（Taro.showToast duration 是毫秒，我们转成秒后传过来）
        // 兼容：>100 当毫秒处理，<=100 当秒处理
        if (d is num) {
          duration = d > 100 ? d.toInt() : (d * 1000).toInt();
        } else {
          duration = 2000;
        }
      } else {
        final List listArgs = args is List ? args : [args];
        if (listArgs.isEmpty) return false;
        message = listArgs[0].toString();
        duration = listArgs.length > 1 ? (listArgs[1] as num).toInt() : 2000;
      }

      if (controller != null) {
        final contexts = controller!.navigation.pageContexts;
        if (contexts.isNotEmpty) {
          final context = contexts.last;
          if (context.mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(message),
              duration: Duration(milliseconds: duration),
            ));
            return true;
          }
        }
      }
      return false;
    });

    registerAsyncMethod('hide', (args) async {
      if (controller != null) {
        final contexts = controller!.navigation.pageContexts;
        if (contexts.isNotEmpty) {
          final context = contexts.last;
          if (context.mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            return true;
          }
        }
      }
      return false;
    });
  }
}
