/// fuickjs 框架（Flutter 层）版本号。
///
/// ⚠️ 与 `pubspec.yaml` 的 `version` 字段保持一致，发版时同步更新。
/// Dart 无法在运行时读取自身 pubspec 版本，故以常量作为运行时单一数据源。
///
/// 引擎在 eval 业务代码前注入到 `globalThis.__FUICK_BUNDLE__.frameworkVersion`，
/// 供业务侧做运行时兼容性判断与埋点上报。
const String fuickjsFrameworkVersion = '0.1.0';
