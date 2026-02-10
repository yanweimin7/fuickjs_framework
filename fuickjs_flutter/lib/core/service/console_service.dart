import 'package:flutter/foundation.dart';
import 'base_fuick_service.dart';

class ConsoleService extends BaseFuickService {
  @override
  String get name => 'Console';

  ConsoleService() {
    registerMethod('console', (args) {
      final m = args is Map ? args : {};
      final level = m['level'] ?? 'log';
      final message = m['message'] ?? '';
      debugPrint('[JS $level] $message');
      return null;
    });
  }
}
