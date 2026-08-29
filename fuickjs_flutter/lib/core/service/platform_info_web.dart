import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';

/// Web 端平台标识来源：`dart:io Platform` 在 Web 编不过，改走 Flutter 的
/// [defaultTargetPlatform]（浏览器 userAgent 推断）与 [PlatformDispatcher]。
class PlatformInfo {
  const PlatformInfo._();

  /// [TargetPlatform] 的 `name` 小写后正好与 `Platform.operatingSystem` 的取值
  /// 对齐（android / ios / macos / windows / linux / fuchsia），且新增枚举成员时
  /// 不会像穷举 switch 那样编译失败。
  static String get osName => defaultTargetPlatform.name.toLowerCase();

  /// 浏览器没有可靠的系统版本来源（UA 解析不稳定，且 UA-CH 需要异步权限），
  /// 统一返回 'unknown'。业务侧如需分支请用 [osName] / [isIOS] 等。
  static String get osVersion => 'unknown';

  static String get localeName =>
      PlatformDispatcher.instance.locale.toLanguageTag();

  static bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

  static bool get isWindows => defaultTargetPlatform == TargetPlatform.windows;

  static bool get isLinux => defaultTargetPlatform == TargetPlatform.linux;

  static bool get isFuchsia => defaultTargetPlatform == TargetPlatform.fuchsia;
}
