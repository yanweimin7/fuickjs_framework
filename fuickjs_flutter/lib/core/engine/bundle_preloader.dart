import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

import '../logger.dart';

/// 负责提前触发 bundle 的 IO 加载，避免在 engine 初始化完成后再等待磁盘读取。
/// 不缓存 bundle 内容——加载完成后内容由调用方持有，本类立即释放引用。
class BundlePreloader {
  static final BundlePreloader _instance = BundlePreloader._internal();

  factory BundlePreloader() => _instance;

  BundlePreloader._internal();

  /// key: bundleName, value: 正在飞行中的加载 Future（完成后移除）
  final Map<String, Future<_BundleContent>> _pendingLoads = {};

  /// 提前启动 bundle 的 IO 加载。可在 engine 初始化前调用，与 engine init 并行。
  /// 幂等：同一 bundleName 同时调用多次只触发一次 IO。
  Future<void> prewarm(String bundleName, {required bool useAot}) {
    _getOrStartLoad(bundleName, useAot: useAot);
    return Future.value();
  }

  /// 取出加载结果（内容一次性消费，之后本类不再持有引用）。
  /// 若尚未调用过 prewarm，则在此直接加载。
  Future<_BundleContent> consume(String bundleName, {required bool useAot}) {
    return _getOrStartLoad(bundleName, useAot: useAot).then((content) {
      _pendingLoads.remove(bundleName); // 消费后移除，让 GC 回收内容
      return content;
    });
  }

  Future<_BundleContent> _getOrStartLoad(
      String bundleName, {required bool useAot}) {
    return _pendingLoads.putIfAbsent(
      bundleName,
      () => _loadContent(bundleName, useAot: useAot),
    );
  }

  Future<_BundleContent> _loadContent(
      String bundleName, {required bool useAot}) async {
    if (useAot) {
      try {
        final byteData = await rootBundle.load('assets/js/$bundleName.qjc');
        logger.d('[BundlePreloader] Loaded bytecode for $bundleName');
        return _BundleContent.bytecode(byteData.buffer.asUint8List());
      } catch (_) {
        // fallback to source
      }
    }
    final source =
        await rootBundle.loadString('assets/js/$bundleName.js', cache: false);
    logger.d('[BundlePreloader] Loaded source for $bundleName');
    return _BundleContent.source(source);
  }
}

class _BundleContent {
  final Uint8List? bytecode;
  final String? source;

  const _BundleContent.bytecode(this.bytecode) : source = null;
  const _BundleContent.source(this.source) : bytecode = null;
}
