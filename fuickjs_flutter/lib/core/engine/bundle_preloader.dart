import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';

import '../logger.dart';

class BundlePreloader {
  static final BundlePreloader _instance = BundlePreloader._internal();

  factory BundlePreloader() => _instance;

  BundlePreloader._internal();

  final Map<String, Uint8List> _byteCodeCache = {};
  final Map<String, String> _sourceCodeCache = {};
  final Map<String, Future<void>> _pendingLoads = {};

  /// Preload a bundle by name.
  /// It tries to load .qjc (bytecode) first, then .js (source code).
  Future<void> preloadBundle(String bundleName, {required bool useAot}) async {
    if (_byteCodeCache.containsKey(bundleName) ||
        _sourceCodeCache.containsKey(bundleName)) {
      return;
    }

    if (_pendingLoads.containsKey(bundleName)) {
      return _pendingLoads[bundleName];
    }

    final completer = Completer<void>();
    _pendingLoads[bundleName] = completer.future;

    try {
      await _loadBundleContent(bundleName,useAot: useAot);
      completer.complete();
    } catch (e) {
      completer.completeError(e);
    } finally {
      _pendingLoads.remove(bundleName);
    }
  }

  Future<void> _loadBundleContent(String bundleName,  {required bool useAot}) async {
    if(useAot) {
      // Try loading bytecode first
      try {
        final byteData = await rootBundle.load('assets/js/$bundleName.qjc');
        _byteCodeCache[bundleName] = byteData.buffer.asUint8List();
        logger.d('[BundlePreloader] Loaded bytecode for $bundleName');
        return;
      } catch (e) {
        // Ignore error and fall back to source code
      }
    }

    // Fallback to source code
    try {
      final source = await rootBundle.loadString('assets/js/$bundleName.js',cache: false);
      _sourceCodeCache[bundleName] = source;
      logger.d('[BundlePreloader] Loaded source code for $bundleName');
    } catch (e) {
      logger.e('[BundlePreloader] Failed to load bundle $bundleName: $e');
      throw e;
    }
  }

  /// Get cached bytecode if available
  Uint8List? getByteCode(String bundleName) {
    return _byteCodeCache[bundleName];
  }

  /// Get cached source code if available
  String? getSourceCode(String bundleName) {
    return _sourceCodeCache[bundleName];
  }

  /// Check if a bundle is cached
  bool isCached(String bundleName) {
    return _byteCodeCache.containsKey(bundleName) ||
        _sourceCodeCache.containsKey(bundleName);
  }

  /// Clear all caches
  void clear() {
    _byteCodeCache.clear();
    _sourceCodeCache.clear();
  }
}
