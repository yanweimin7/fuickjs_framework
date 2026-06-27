import 'dart:async';

/// JS 错误信息（从 isolate 传回主 isolate）。
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
/// isolate 里的 [ErrorReportService] 通过 mainSendPort 把错误发回主 isolate，
/// 主 isolate 的 [IsolateWorker] 收到后调用 [report] 广播。
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
