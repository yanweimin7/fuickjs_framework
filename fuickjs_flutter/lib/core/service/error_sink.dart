import 'js_error_bus.dart';

/// 错误上报出口（sink）。
///
/// 框架已能捕获 JS 运行时错误并用 sourcemap 还原堆栈（见 [ErrorReportService]），
/// 但默认只打印日志 + 触发红屏，**错误在设备上被丢弃，不会回收到后端**。
///
/// 宿主 App 实现本接口、并在启动时通过 [ErrorSinks.register] 注册，即可把线上错误
/// 聚合到 Sentry / Bugly / 自建平台：
///
/// ```dart
/// class SentryErrorSink implements ErrorSink {
///   @override
///   void report(JsErrorInfo info) {
///     Sentry.captureException(info.message, stackTrace: info.stack);
///   }
/// }
///
/// void main() {
///   ErrorSinks.register(SentryErrorSink());
/// }
/// ```
///
/// [report] 应是非阻塞的（内部自行异步上报），抛错会被 [ErrorSinks.reportAll] 吞掉，
/// 不影响红屏与主流。
abstract class ErrorSink {
  void report(JsErrorInfo info);
}

/// 全局错误 sink 注册表。
///
/// [ErrorReportService] 在 sourcemap 还原后会调用 [reportAll]，把同一份
/// [JsErrorInfo] 同时推送给所有已注册的 sink（红屏走 [JsErrorBus]，互不影响）。
class ErrorSinks {
  static final List<ErrorSink> _sinks = <ErrorSink>[];

  /// 注册一个上报出口。重复注册会被加入多次，调用方自行保证单例。
  static void register(ErrorSink sink) => _sinks.add(sink);

  /// 移除（测试或动态卸载插件时用）。
  static void unregister(ErrorSink sink) => _sinks.remove(sink);

  /// 当前已注册的 sink（只读快照，供调试/测试断言）。
  static List<ErrorSink> get registered => List<ErrorSink>.of(_sinks);

  /// 把错误推送给所有 sink。任意 sink 抛错被隔离吞掉，
  /// 避免单个坏 sink 阻断其它 sink 与红屏流程。
  static void reportAll(JsErrorInfo info) {
    for (final sink in List<ErrorSink>.of(_sinks)) {
      try {
        sink.report(info);
      } catch (_) {
        // 单个 sink 失败不应影响其余 sink 与红屏。
      }
    }
  }
}
