import '../logger.dart';
import 'base_fuick_service.dart';

class ConsoleService extends BaseFuickService {
  @override
  String get name => 'Console';

  ConsoleService() {
    registerMethod('console', (args) {
      print('wine console $args');
      final m = args is Map ? args : {};
      final level = m['level'] ?? 'log';
      final message = m['message'] ?? '';

      switch (level) {
        case 'error':
          logger.e('[JS] $message');
          break;
        case 'warn':
          logger.w('[JS] $message');
          break;
        case 'info':
          logger.i('[JS] $message');
          break;
        case 'debug':
          logger.d('[JS] $message');
          break;
        default:
          logger.i('[JS $level] $message');
      }
      return null;
    });
  }
}
