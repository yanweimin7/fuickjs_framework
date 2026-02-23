import 'package:flutter/material.dart';

import 'base_fuick_service.dart';

class ToastService extends BaseFuickService {
  @override
  String get name => 'Toast';

  ToastService() {
    registerMethod('show', (args) {
      final List listArgs = args is List ? args : [args];
      if (listArgs.isEmpty) return false;

      final message = listArgs[0].toString();
      final duration =
          listArgs.length > 1 ? (listArgs[1] as num).toInt() : 2000; // ms

      if (controller != null) {
        final contexts = controller!.navigation.pageContexts;
        if (contexts.isNotEmpty) {
          final context = contexts.last;
          if (context.mounted) {
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
  }
}
