// 平台条件入口：FuickAppContext。
//
// Web 走 js_interop 桥（无 isolate/FFI/offline），native 走 QuickJS/JSC isolate。
// 两者暴露同一公开 API（构造函数 / ctx / appController / isReady / init /
// prewarmPage / activeBundleRoot / dispose），且 isReady 与 bundle 加载失败的
// 处理策略一致：isReady 表示"桥/引擎就绪"，bundle 结果由
// appController.isBundleLoaded 表达，加载失败只记日志不外抛。
export 'fuick_app_context_web.dart'
    if (dart.library.io) 'fuick_app_context_native.dart';
