import 'dart:async';

/// JS 错误信息。
class JsErrorInfo {
  final String message;
  final String? stack;
  final String source;
  final dynamic detail;
  final int timestamp;

  JsErrorInfo({
    required this.message,
    this.stack,
    required this.source,
    this.detail,
    required this.timestamp,
  });

  factory JsErrorInfo.fromMap(Map<String, dynamic> m) {
    final ts = m['timestamp'];
    return JsErrorInfo(
      message: m['message']?.toString() ?? '',
      stack: m['stack']?.toString(),
      source: m['source']?.toString() ?? 'unknown',
      detail: m['detail'],
      timestamp: ts is int
          ? ts
          : (ts is num ? ts.toInt() : DateTime.now().millisecondsSinceEpoch),
    );
  }

  Map<String, dynamic> toMap() => {
        'message': message,
        'stack': stack,
        'source': source,
        'detail': detail,
        'timestamp': timestamp,
      };
}

/// 全局 JS 错误总线。
///
/// 跑在 main isolate 的 [ErrorReportService] 收到 JS 错误后调用 [report] 广播。
/// [FuickAppView] 监听 [stream] 在 debug 模式下显示红屏。
class JsErrorBus {
  static final JsErrorBus instance = JsErrorBus._();

  JsErrorBus._();

  final StreamController<JsErrorInfo> _controller =
      StreamController<JsErrorInfo>.broadcast();

  Stream<JsErrorInfo> get stream => _controller.stream;

  void report(JsErrorInfo error) {
    _controller.add(error);
  }

  void dispose() {
    _controller.close();
  }
}
