import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// 全局配置。
///
/// 宿主在 `main()` 中通过 `FuickConfig().debug = false` 等设置影响框架运行时
/// 行为（日志级别、热重载、调试页等）。所有字段均带默认值，可不显式配置。
class FuickConfig {
  static final FuickConfig _instance = FuickConfig._internal();

  factory FuickConfig() => _instance;

  FuickConfig._internal();

  bool _debug = kDebugMode;

  /// 是否处于 debug 模式。
  ///
  /// 默认跟随 `kDebugMode`。设为 false 后：
  /// - 日志级别收紧到 [Level.warning]
  /// - 关闭热重载、调试页等仅用于调试的能力
  bool get debug => _debug;
  set debug(bool value) {
    _debug = value;
    if (!value) {
      logLevel = Level.warning;
      enableHotReload = false;
      enableDevPage = false;
    }
  }

  /// 日志级别。默认 [Level.debug]（debug 模式）或 [Level.warning]（release 模式）。
  Level logLevel = kDebugMode ? Level.debug : Level.warning;

  /// 是否启用 JS 热重载（开发期使用）。
  bool enableHotReload = kDebugMode;

  /// 是否注册调试控制台入口 [DevFuickAppPage]。
  bool enableDevPage = kDebugMode;

  /// 是否在 [FuickAppView] 上方叠加 Flutter Performance Overlay。
  bool enablePerformanceOverlay = false;

  /// 是否在 debug 模式下输出 JS↔Native 调用栈。
  bool verboseCommandLog = false;

  @override
  String toString() =>
      'FuickConfig(debug=$debug, logLevel=$logLevel, hotReload=$enableHotReload, '
      'devPage=$enableDevPage, perfOverlay=$enablePerformanceOverlay, '
      'verboseCmd=$verboseCommandLog)';
}
