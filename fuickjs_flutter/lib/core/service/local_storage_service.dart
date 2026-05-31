import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../logger.dart';
import 'base_fuick_service.dart';

class LocalStorageService extends BaseFuickService {
  @override
  String get name => 'LocalStorage';

  SharedPreferences? _prefs;
  Completer<void>? _initCompleter;

  LocalStorageService() {
    registerAsyncMethod('getItem', (args) async {
      final prefs = await _ensureInitialized();
      final String? key;
      if (args is Map) {
        key = args['key']?.toString();
      } else if (args is List && args.isNotEmpty) {
        key = args[0]?.toString();
      } else {
        key = args?.toString();
      }
      if (key == null) return null;
      return prefs.get(key);
    });

    registerAsyncMethod('setItem', (args) async {
      final prefs = await _ensureInitialized();
      final String? key;
      final dynamic value;
      if (args is Map) {
        key = args['key']?.toString();
        value = args['value'];
      } else if (args is List && args.length >= 2) {
        key = args[0]?.toString();
        value = args[1];
      } else {
        return false;
      }
      if (key == null) return false;

      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(key, value);
      } else {
        await prefs.setString(key, value.toString());
      }
      return true;
    });

    registerAsyncMethod('removeItem', (args) async {
      final prefs = await _ensureInitialized();
      final String? key;
      if (args is Map) {
        key = args['key']?.toString();
      } else if (args is List && args.isNotEmpty) {
        key = args[0]?.toString();
      } else {
        key = args?.toString();
      }
      if (key == null) return false;
      await prefs.remove(key);
      return true;
    });

    registerAsyncMethod('clear', (args) async {
      final prefs = await _ensureInitialized();
      await prefs.clear();
      return true;
    });

    // JS 侧 microtask 合批后单次调用：一次 _ensureInitialized + 顺序写入，
    // 避免 N 个 setItem 各自 await Completer。
    registerAsyncMethod('setBatch', (args) async {
      final prefs = await _ensureInitialized();
      List entries;
      if (args is List && args.isNotEmpty && args[0] is List) {
        entries = args[0] as List;
      } else if (args is List) {
        entries = args;
      } else {
        return false;
      }
      for (final entry in entries) {
        if (entry is! List || entry.length < 2) continue;
        final key = entry[0]?.toString();
        final value = entry[1];
        if (key == null) continue;
        if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is String) {
          await prefs.setString(key, value);
        } else if (value is List<String>) {
          await prefs.setStringList(key, value);
        } else {
          await prefs.setString(key, value.toString());
        }
      }
      return true;
    });
  }

  Future<SharedPreferences> _ensureInitialized() async {
    final cached = _prefs;
    if (cached != null) return cached;
    final inflight = _initCompleter;
    if (inflight != null) {
      await inflight.future;
      return _prefs!;
    }
    final completer = Completer<void>();
    _initCompleter = completer;
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      completer.complete();
      return prefs;
    } catch (e) {
      logger.e('[LocalStorage] Error initializing: $e');
      completer.completeError(e);
      // 失败后清空 completer，允许下一次调用重试，避免被永久 cached 的错误挡住。
      _initCompleter = null;
      rethrow;
    } finally {
      // 成功路径上 completer 已 complete；保留 _initCompleter 不为下次重置避免竞态丢失成功状态。
      if (completer.isCompleted && _prefs != null) {
        // 保持 _initCompleter 已完成状态，后续调用直接走 _prefs != null 快路径。
      }
    }
  }
}