import 'dart:isolate';

import '../logger.dart';
import '../utils/source_map_resolver.dart';
import 'base_fuick_service.dart';
import 'js_error_bus.dart';

/// 专用错误上报服务。
///
/// **跑在 isolate 里**（注册在 allowedServices），因为 isolate 里的同步
/// `dartCallNative` 不能走 `fallbackSync` 回 main isolate（会死锁：
/// main isolate 可能正在等待 isolate 的 invoke/runJobs 返回）。
///
/// 职责：
/// 1. 用 [SourceMapResolver] 还原堆栈并打印日志（isolate 里完成）
/// 2. 通过 [mainSendPort] **非阻塞**发送错误到 main isolate，
///    由 [JsErrorBus] 广播，供 [RedBoxOverlay] 显示红屏
class ErrorReportService extends BaseFuickService {
  @override
  String get name => 'ErrorReport';

  SourceMapResolver? _resolver;

  /// 由 [IsolateHandler] 注入，用于非阻塞发送错误到 main isolate。
  SendPort? mainSendPort;

  ErrorReportService() {
    registerMethod('report', (args) {
      final m = args is Map ? args : <String, dynamic>{};
      final message = m['message']?.toString() ?? '';
      final stack = m['stack']?.toString();
      final source = m['source']?.toString() ?? 'unknown';
      final detail = m['detail'];

      final resolvedStack = _resolver?.resolveStack(stack) ?? stack;

      // 1. 日志打印
      logger.e('=== JS Error [$source] ===');
      logger.e('Message: $message');
      if (resolvedStack != null && resolvedStack.isNotEmpty) {
        logger.e('Stack:\n$resolvedStack');
      }
      if (detail != null) {
        logger.e('Detail: $detail');
      }

      // 2. 非阻塞发送到 main isolate 触发红屏
      if (mainSendPort != null) {
        final ts = m['timestamp'];
        mainSendPort!.send({
          'type': 'jsError',
          'payload': {
            'message': message,
            'stack': resolvedStack,
            'source': source,
            'detail': detail,
            'timestamp': ts is int
                ? ts
                : (ts is num
                    ? ts.toInt()
                    : DateTime.now().millisecondsSinceEpoch),
          },
        });
      }
      return null;
    });
  }

  /// 在 eval 业务代码前调用，注入 sourcemap 以还原后续错误堆栈。
  void setSourceMap(Map<String, dynamic>? sourceMap) {
    _resolver = SourceMapResolver(sourceMap);
    if (_resolver?.hasMapping == true) {
      logger.d('[ErrorReportService] Sourcemap loaded');
    }
  }
}
