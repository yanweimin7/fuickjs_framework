import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../logger.dart';
import 'base_fuick_service.dart';

class LocalStorageService extends BaseFuickService {
  @override
  String get name => 'LocalStorage';

  File? _file;
  Map<String, dynamic> _cache = {};
  bool _initialized = false;

  LocalStorageService() {
    registerAsyncMethod('getItem', (args) async {
      await _ensureInitialized();
      final key =
          args is List && args.isNotEmpty ? args[0]?.toString() : args?.toString();
      if (key == null) return null;
      return _cache[key];
    });

    registerAsyncMethod('setItem', (args) async {
      await _ensureInitialized();
      if (args is List && args.length >= 2) {
        final key = args[0]?.toString();
        if (key == null) return false;
        final value = args[1];
        _cache[key] = value;
        await _flush();
        return true;
      }
      return false;
    });

    registerAsyncMethod('removeItem', (args) async {
      await _ensureInitialized();
      final key =
          args is List && args.isNotEmpty ? args[0]?.toString() : args?.toString();
      if (key == null) return false;
      if (_cache.containsKey(key)) {
        _cache.remove(key);
        await _flush();
        return true;
      }
      return false;
    });

    registerAsyncMethod('clear', (args) async {
      await _ensureInitialized();
      _cache.clear();
      await _flush();
      return true;
    });
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/fuick_storage.json');
      if (await _file!.exists()) {
        final content = await _file!.readAsString();
        if (content.isNotEmpty) {
          _cache = jsonDecode(content) as Map<String, dynamic>;
        }
      }
    } catch (e) {
      logger.e('Error initializing storage: $e');
    } finally {
      _initialized = true;
    }
  }

  Future<void> _flush() async {
    if (_file == null) return;
    try {
      await _file!.writeAsString(jsonEncode(_cache));
    } catch (e) {
      logger.e('Error writing storage: $e');
    }
  }
}
