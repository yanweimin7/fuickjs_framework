import 'base_fuick_service.dart';
import '../logger.dart';

/// 同步版 service —— 同时支持 `registerMethod` 和 `registerAsyncMethod`。
///
/// ⚠️ **仅供白名单 worker service 使用**（`TimerService` / `ConsoleService` /
/// `FileSystemService`）。其他业务 service 必须继承 [BaseFuickService]，
/// 所有方法都用 `registerAsyncMethod` 注册 —— 否则在 worker isolate 中
/// JS 端 `dartCallNative` 会拿到一个 Dart 端 trampoline 转主 isolate
/// 返回的 Promise 对象，后续访问字段触发 `viewInsets == undefined` 之类的
/// 隐蔽 bug。
///
/// worker isolate binder 会显式按运行时类型白名单过滤 service：
/// 见 [IsolateManager] 中 `allowedServices` 参数。
abstract class SyncFuickService extends BaseFuickService {
  final Map<String, SyncMethodHandler> syncMethods = {};

  void registerMethod(String method, SyncMethodHandler handler) {
    if (syncMethods.containsKey(method)) {
      logger.w(
        '[Service] $name.registerMethod: method "$method" already registered, overwriting old handler.',
      );
    }
    syncMethods[method] = (args) {
      if (isDisposed) {
        logger.w(
          '[Service] Warning: Calling method $method on disposed service',
        );
        return null;
      }
      return handler(args);
    };
  }

  @override
  void dispose() {
    syncMethods.clear();
    super.dispose();
  }
}
