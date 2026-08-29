import 'dart:io';

/// native 端平台标识来源：直接用 `dart:io Platform`。
///
/// 刻意不用 `defaultTargetPlatform`：
///  - `Platform.operatingSystem` 能返回 `ohos` 等 `TargetPlatform` 枚举里没有的
///    平台（fjs_engine 的 plugin platforms 含 ohos），换成枚举会丢信息；
///  - `Platform.operatingSystemVersion` 是唯一能拿到真实系统版本的来源，
///    `navigator.userAgent` 的拼装依赖它。
class PlatformInfo {
  const PlatformInfo._();

  static String get osName => Platform.operatingSystem;

  static String get osVersion => Platform.operatingSystemVersion;

  static String get localeName => Platform.localeName;

  static bool get isAndroid => Platform.isAndroid;

  static bool get isIOS => Platform.isIOS;

  static bool get isMacOS => Platform.isMacOS;

  static bool get isWindows => Platform.isWindows;

  static bool get isLinux => Platform.isLinux;

  static bool get isFuchsia => Platform.isFuchsia;
}
