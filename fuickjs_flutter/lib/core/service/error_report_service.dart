import '../logger.dart';
import '../utils/source_map_resolver.dart';
import 'base_fuick_service.dart';
import 'js_error_bus.dart';

/// 专用错误上报服务。
///
/// **跑在 main isolate**(不在 worker isolate 的 allowedServices 中)。
/// JS 调用应使用 `dartCallNativeAsync` —— 用 `dartCallNative` 同步调用会被
/// binder 拦截并抛 `dartCallNative("ErrorReport.report") is not allowed:
/// method is registered as async` 之类的错。
///
/// 职责:
/// 1. 用 [SourceMapResolver] 还原堆栈并打印日志
/// 2. 通过 [JsErrorBus] 广播错误,供 [RedBoxOverlay] 显示红屏
class ErrorReportService extends BaseFuickService {
  @override
  String get name => 'ErrorReport';

  SourceMapResolver? _resolver;

  ErrorReportService() {
    registerAsyncMethod('report', (args) async {
      final m = args is Map ? args : <String, dynamic>{};
      final message = m['message']?.toString() ?? '';
      final stack = m['stack']?.toString();
      final source = m['source']?.toString() ?? 'unknown';
      final detail = m['detail'];

      final resolvedStack = _resolver?.resolveStack(stack) ?? stack;

      // 1. 日志打印

      logger.e('Message: $message');
      if (resolvedStack != null && resolvedStack.isNotEmpty) {
        logger.e('Stack:\n$resolvedStack');
      }
      if (detail != null) {
        logger.e('Detail: $detail');
      }

      // 2. 广播到 JsErrorBus，触发红屏
      final ts = m['timestamp'];
      JsErrorBus.instance.report(JsErrorInfo(
        message: message,
        stack: resolvedStack,
        source: source,
        detail: detail,
        timestamp: ts is int
            ? ts
            : (ts is num ? ts.toInt() : DateTime.now().millisecondsSinceEpoch),
      ));
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
