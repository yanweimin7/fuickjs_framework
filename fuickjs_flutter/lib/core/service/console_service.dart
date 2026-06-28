import '../logger.dart';
import 'sync_fuick_service.dart';

/// JS console.{log,warn,error,info,debug} 桥接服务。
///
/// 跑在 worker isolate 白名单中 —— 保留 `registerMethod` 同步注册能力，
/// 让 console.log 这种高频热路径不必走 trampoline 转主 isolate。
/// 详见 [SyncFuickService] 注释。
///
/// 职责单一：将 JS 侧的日志消息转发到 Dart [logger]。
/// Sourcemap 堆栈还原已迁移至 [ErrorReportService]，本服务不再做堆栈解析。
class ConsoleService extends SyncFuickService {
  @override
  String get name => 'Console';

  ConsoleService() {
    registerMethod('console', (args) {
      final m = args is Map ? args : {};
      final level = m['level'] ?? 'log';
      final message = (m['message'] ?? '').toString();

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
