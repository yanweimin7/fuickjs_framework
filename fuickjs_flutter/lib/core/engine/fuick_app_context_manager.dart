import '../logger.dart';
import 'fuick_app_context.dart';

export 'fuick_app_context.dart' show PrewarmPageConfig;

class FuickAppContextManager {
  static final FuickAppContextManager _instance =
      FuickAppContextManager._internal();

  factory FuickAppContextManager() => _instance;

  FuickAppContextManager._internal();

  final Map<String, FuickAppContext> _contexts = {};
  final Map<String, int> _refCounts = {};

  /// 已标记待销毁的 context id，不可被复用
  final Set<String> _pendingDestroy = {};

  /// 获取指定 id 的上下文（待销毁的不返回）
  FuickAppContext? getContext(String id) {
    if (_pendingDestroy.contains(id)) return null;
    return _contexts[id];
  }

  /// 注册上下文
  void registerContext(String id, FuickAppContext context) {
    // 如果旧的正在待销毁，立即销毁旧的，换成新的
    if (_pendingDestroy.contains(id)) {
      destroyContext(id);
      logger.d(
          'FuickAppContextManager: Replaced pending-destroy context $id with new one.');
    }
    if (_contexts.containsKey(id)) {
      logger.w(
          'FuickAppContextManager: Context with id $id already exists. Overwriting.');
    }
    _contexts[id] = context;
    _refCounts.putIfAbsent(id, () => 0);
    retainContext(id);
  }

  /// 增加引用计数
  void retainContext(String id) {
    if (_contexts.containsKey(id)) {
      _refCounts[id] = (_refCounts[id] ?? 0) + 1;
      logger.d(
          'FuickAppContextManager: Retained context $id. RefCount: ${_refCounts[id]}');
    }
  }

  /// 减少引用计数，归零时延迟 5s 销毁，给 JS 端留清理时间
  void releaseContext(String id) {
    if (_contexts.containsKey(id)) {
      final currentCount = _refCounts[id] ?? 0;
      if (currentCount > 0) {
        _refCounts[id] = currentCount - 1;
        logger.d(
            'FuickAppContextManager: Released context $id. RefCount: ${_refCounts[id]}');

        if (_refCounts[id] == 0) {
          _pendingDestroy.add(id);
          logger.d(
              'FuickAppContextManager: Context $id marked pending destroy, will dispose in 5s.');
          Future.delayed(const Duration(seconds: 5), () {
            // 仍在待销毁列表中，说明没被 registerContext 重新复活
            if (_pendingDestroy.remove(id)) {
              destroyContext(id);
            }
          });
        }
      }
    }
  }

  /// 移除上下文
  void removeContext(String id) {
    _contexts.remove(id);
    _refCounts.remove(id);
    _pendingDestroy.remove(id);
  }

  /// 销毁并移除上下文
  void destroyContext(String id) {
    logger.d('FuickAppContextManager: Destroying context $id');
    final context = _contexts.remove(id);
    _refCounts.remove(id);
    _pendingDestroy.remove(id);
    context?.dispose();
  }

  /// 检查是否存在（待销毁的不算）
  bool hasContext(String id) {
    if (_pendingDestroy.contains(id)) return false;
    return _contexts.containsKey(id);
  }

  /// 预热：一次调用完成 engine init + bundle 加载 + 页面预渲染。
  /// 可在 main() 或 splash 页调用，无需任何前置依赖。
  ///
  /// ```dart
  /// FuickAppContextManager().prewarm(
  ///   'my_app',
  ///   useAotCode: true,
  ///   pages: [
  ///     PrewarmPageConfig('/home'),
  ///     PrewarmPageConfig('/detail', {'id': '123'}),
  ///   ],
  /// );
  /// ```
  Future<void> prewarm(
    String appName, {
    bool useAotCode = false,
    List<PrewarmPageConfig> pages = const [],
  }) {
    final existing = _contexts[appName];
    if (existing != null && !_pendingDestroy.contains(appName)) {
      // 已存在且未待销毁，只追加页面预渲染
      for (final page in pages) {
        existing.prewarmPage(page.path, page.params);
      }
      return existing.init();
    }

    final context = FuickAppContext(appName: appName, useAotCode: useAotCode);
    // 先把页面排队，bundle 加载完后自动执行
    for (final page in pages) {
      context.prewarmPage(page.path, page.params);
    }
    _contexts[appName] = context;
    _refCounts[appName] = 0;
    return context.init();
  }
}
