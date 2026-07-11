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
    if (_pendingDestroy.contains(id)) {
      // logger.w(
      //     'FuickAppContextManager: getContext($id) — context is in _pendingDestroy, returning null. '
      //     'PendingDestroy: $_pendingDestroy, RefCounts: $_refCounts');
      return null;
    }
    final ctx = _contexts[id];
    // logger.d('FuickAppContextManager: getContext($id) — found: ${ctx != null}, '
    //     'refCount: ${_refCounts[id]}, pendingDestroy: $_pendingDestroy');
    return ctx;
  }

  /// 注册上下文
  void registerContext(String id, FuickAppContext context) {
    logger.d('FuickAppContextManager: registerContext($id) — '
        'pendingDestroy: $_pendingDestroy, existing: ${_contexts.containsKey(id)}, '
        'currentRefCount: ${_refCounts[id]}');
    // 如果旧的正在待销毁，立即销毁旧的，换成新的
    if (_pendingDestroy.contains(id)) {
      // logger.w(
      //     'FuickAppContextManager: registerContext($id) — old context is in _pendingDestroy, destroying it now.');
      destroyContext(id);
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
          'FuickAppContextManager: Retained context $id. RefCount: ${_refCounts[id]}, '
          'pendingDestroy: $_pendingDestroy');
    } else {
      logger
          .w('FuickAppContextManager: retainContext($id) — context not found! '
              'Available: ${_contexts.keys.toList()}, refCounts: $_refCounts');
    }
  }

  /// 减少引用计数，归零时延迟 5s 销毁，给 JS 端留清理时间
  void releaseContext(String id) {
    if (_contexts.containsKey(id)) {
      final currentCount = _refCounts[id] ?? 0;
      if (currentCount > 0) {
        _refCounts[id] = currentCount - 1;
        logger.d(
            'FuickAppContextManager: Released context $id. RefCount: ${_refCounts[id]}, '
            'pendingDestroy: $_pendingDestroy');

        if (_refCounts[id] == 0) {
          _pendingDestroy.add(id);
          logger.w(
              'FuickAppContextManager: Context $id refCount reached 0, marked pending destroy. '
              'Will dispose in 2s if not retained. All contexts: ${_contexts.keys.toList()}, '
              'All refCounts: $_refCounts');
          Future.delayed(const Duration(seconds: 2), () {
            // 仍在待销毁列表中，说明没被 registerContext 重新复活
            if (_pendingDestroy.remove(id)) {
              logger.w(
                  'FuickAppContextManager: 5s elapsed, destroying context $id. '
                  'Remaining contexts: ${_contexts.keys.toList()}');
              destroyContext(id);
            } else {
              logger.d(
                  'FuickAppContextManager: 5s elapsed for $id, but it was already removed from _pendingDestroy '
                  '(likely re-registered or manually destroyed). No action.');
            }
          });
        }
      } else {
        logger.w(
            'FuickAppContextManager: releaseContext($id) — refCount already 0! '
            'This may indicate a double-release. refCounts: $_refCounts');
      }
    } else {
      logger
          .w('FuickAppContextManager: releaseContext($id) — context not found! '
              'Available: ${_contexts.keys.toList()}, refCounts: $_refCounts');
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
    logger.w('FuickAppContextManager: Destroying context $id. '
        'Remaining contexts: ${_contexts.keys.toList()}, refCounts: $_refCounts, '
        'pendingDestroy: $_pendingDestroy');
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
    final isPendingDestroy = _pendingDestroy.contains(appName);
    logger.d('FuickAppContextManager: prewarm($appName) — '
        'existing: ${existing != null}, isPendingDestroy: $isPendingDestroy, '
        'pages: ${pages.map((p) => p.path).toList()}, '
        'allContexts: ${_contexts.keys.toList()}, refCounts: $_refCounts');

    if (existing != null && !isPendingDestroy) {
      // 已存在且未待销毁，只追加页面预渲染
      logger.d(
          'FuickAppContextManager: prewarm($appName) — reusing existing context, appending pages.');
      for (final page in pages) {
        existing.prewarmPage(page.path, page.params);
      }
      return existing.init();
    }

    logger.d('FuickAppContextManager: prewarm($appName) — creating new context '
        '(existing was ${existing != null ? 'pending-destroy' : 'null'}).');
    final context = FuickAppContext(appName: appName, useAotCode: useAotCode);
    // 先把页面排队，bundle 加载完后自动执行
    for (final page in pages) {
      context.prewarmPage(page.path, page.params);
    }
    // 走 registerContext 统一处理：若旧的在 _pendingDestroy 中会立即销毁，
    // 并正确设置引用计数，避免 5s 延迟回调误销毁新 context
    registerContext(appName, context);
    return context.init();
  }
}
