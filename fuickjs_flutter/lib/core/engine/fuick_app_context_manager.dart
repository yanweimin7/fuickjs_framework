import 'package:flutter/foundation.dart';

import 'fuick_app_context.dart';

class FuickAppContextManager {
  static final FuickAppContextManager _instance =
      FuickAppContextManager._internal();

  factory FuickAppContextManager() => _instance;

  FuickAppContextManager._internal();

  final Map<String, FuickAppContext> _contexts = {};
  final Map<String, int> _refCounts = {};

  /// 获取指定 id 的上下文
  FuickAppContext? getContext(String id) {
    return _contexts[id];
  }

  /// 注册上下文
  void registerContext(String id, FuickAppContext context) {
    if (_contexts.containsKey(id)) {
      debugPrint(
          'FuickAppContextManager: Context with id $id already exists. Overwriting.');
    }
    _contexts[id] = context;
    _refCounts.putIfAbsent(id, () => 0);
    _retainContext(id);
  }

  /// 增加引用计数
  void _retainContext(String id) {
    if (_contexts.containsKey(id)) {
      _refCounts[id] = (_refCounts[id] ?? 0) + 1;
      debugPrint(
          'FuickAppContextManager: Retained context $id. RefCount: ${_refCounts[id]}');
    }
  }

  /// 减少引用计数，归零时销毁
  void releaseContext(String id) {
    if (_contexts.containsKey(id)) {
      final currentCount = _refCounts[id] ?? 0;
      if (currentCount > 0) {
        _refCounts[id] = currentCount - 1;
        debugPrint(
            'FuickAppContextManager: Released context $id. RefCount: ${_refCounts[id]}');

        if (_refCounts[id] == 0) {
          destroyContext(id);
        }
      }
    }
  }

  /// 移除上下文
  void removeContext(String id) {
    _contexts.remove(id);
    _refCounts.remove(id);
    // context?.dispose(); // Manager 是否负责销毁？通常由调用者决定，或者提供 destroyContext 方法
  }

  /// 销毁并移除上下文
  void destroyContext(String id) {
    debugPrint('FuickAppContextManager: Destroying context $id');
    final context = _contexts.remove(id);
    _refCounts.remove(id);
    context?.dispose();
  }

  /// 检查是否存在
  bool hasContext(String id) {
    return _contexts.containsKey(id);
  }
}
