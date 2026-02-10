import 'package:flutter/foundation.dart';
import 'base_fuick_service.dart';

class NativeEventService extends BaseFuickService {
  @override
  String get name => 'NativeEvent';

  // 用于 Flutter 端订阅的事件
  final Map<String, List<Function(dynamic)>> _listeners = {};

  NativeEventService() {
    // 注册供 JS 调用的 emit 方法
    registerMethod('emit', (args) {
      final List listArgs = args is List ? args : [args];
      if (listArgs.isNotEmpty && listArgs[0] is String) {
        final event = listArgs[0] as String;
        final data = listArgs.length > 1 ? listArgs[1] : null;

        // 触发 Flutter 端监听器
        _dispatchToFlutter(event, data);
        return true;
      }
      return false;
    });
  }

  // Flutter 端 API: 监听事件
  VoidCallback on(String event, Function(dynamic) callback) {
    if (!_listeners.containsKey(event)) {
      _listeners[event] = [];
    }
    _listeners[event]!.add(callback);
    return () => off(event, callback);
  }

  // Flutter 端 API: 移除监听
  void off(String event, Function(dynamic) callback) {
    _listeners[event]?.remove(callback);
    if (_listeners[event]?.isEmpty ?? false) {
      _listeners.remove(event);
    }
  }

  // Flutter 端 API: 发送事件给 JS
  void emit(String event, dynamic data) {
    // 调用 JS 端暴露的 NativeEvent.receive 方法
    // 我们约定通过 ctx.invoke('NativeEvent', 'receive', ...)

    // 检查 BaseFuickService 的实现，看看是否有 context 访问权限
    if (!isDisposed) {
      try {
        ctx.invoke('NativeEvent', 'receive', [event, data]);
      } catch (e) {
        debugPrint('Error emitting event to JS: $e');
      }
    }
  }

  // 内部方法：分发事件给 Flutter 监听器
  void _dispatchToFlutter(String event, dynamic data) {
    final callbacks = _listeners[event];
    if (callbacks != null) {
      for (final callback in List.of(callbacks)) {
        try {
          callback(data);
        } catch (e) {
          debugPrint('Error in NativeEvent listener for event $event: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    _listeners.clear();
    super.dispose();
  }
}
