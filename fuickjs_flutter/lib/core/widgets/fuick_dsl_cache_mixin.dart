import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'fuick_command_listener_mixin.dart';

abstract class FuickDslWidget implements FuickWidget {
  dynamic get cacheKey;
  int? get itemCount;
}

mixin FuickDslCacheMixin<T extends FuickDslWidget>
    on State<T>, FuickCommandListenerMixin<T> {
  final Map<int, dynamic> _dslCache = {};

  dynamic get cacheKey;
  int? get itemCount;

  dynamic getCachedDsl(int index) => _dslCache[index];
  void setCachedDsl(int index, dynamic dsl) => _dslCache[index] = dsl;

  void forceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void clearCache() {
    setState(() {
      _dslCache.clear();
    });
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    handleCacheUpdate(oldWidget.cacheKey, oldWidget.itemCount);
  }

  @override
  void onCommand(String method, dynamic args) {
    if (_handleDslCommand(method, args)) {
      return;
    }
    // Allow subclasses to handle additional commands
    onCustomCommand(method, args);
  }

  bool _handleDslCommand(String method, dynamic args) {
    if (!mounted) return false;

    if (method == 'updateItem') {
      final int index = asInt(args['index']);
      final dynamic dsl = args['dsl'];
      if (dsl != null) {
        setCachedDsl(index, dsl);
        forceUpdate();
        return true;
      }
    } else if (method == 'updateItems') {
      final dynamic items = args is List ? args : args['items'];
      if (items is List) {
        bool changed = false;
        for (final item in items) {
          if (item is Map) {
            final int index = asInt(item['index']);
            final dynamic dsl = item['dsl'];
            if (dsl != null) {
              _dslCache[index] = dsl;
              changed = true;
            }
          }
        }
        if (changed) {
          forceUpdate();
        }
        return true;
      }
    } else if (method == 'refresh' || method == 'reloadData') {
      clearCache();
      return true;
    }
    return false;
  }

  void onCustomCommand(String method, dynamic args) {}

  void handleCacheUpdate(dynamic oldCacheKey, int? oldItemCount) {
    if (cacheKey != oldCacheKey || itemCount != oldItemCount) {
      clearCache();
    }
  }
}
