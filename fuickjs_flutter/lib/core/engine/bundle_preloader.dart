import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../logger.dart';

/// 负责提前触发 bundle 的 IO 加载，避免在 engine 初始化完成后再等待磁盘读取。
/// 支持从动态包目录（packageRoot）加载，未提供或缺失时回退到 assets/js。
/// 不缓存 bundle 内容——加载完成后内容由调用方持有，本类立即释放引用。
class BundlePreloader {
  static final BundlePreloader _instance = BundlePreloader._internal();

  factory BundlePreloader() => _instance;

  BundlePreloader._internal();

  /// key: `<bundleName>@<root>`，value: 飞行中的加载 Future。
  final Map<String, Future<BundleContent>> _pendingLoads = {};

  String _key(String name, String? root) => '$name@${root ?? ''}';

  /// 提前启动 bundle 的 IO 加载，可与 engine init 并行。幂等。
  Future<void> prewarm(String bundleName,
      {required bool useAot, String? packageRoot}) {
    _getOrStartLoad(bundleName, useAot: useAot, packageRoot: packageRoot);
    return Future.value();
  }

  /// 取出加载结果（一次性消费）。若未 prewarm 则在此加载。
  Future<BundleContent> consume(String bundleName,
      {required bool useAot, String? packageRoot}) {
    final key = _key(bundleName, packageRoot);
    return _getOrStartLoad(bundleName, useAot: useAot, packageRoot: packageRoot)
        .then((content) {
      _pendingLoads.remove(key);
      return content;
    });
  }

  /// 失效指定 bundle 的飞行中缓存（回滚/切换包时调用）。
  void invalidate(String bundleName, {String? packageRoot}) {
    _pendingLoads.remove(_key(bundleName, packageRoot));
  }

  Future<BundleContent> _getOrStartLoad(String bundleName,
      {required bool useAot, String? packageRoot}) {
    return _pendingLoads.putIfAbsent(
      _key(bundleName, packageRoot),
      () => _loadContent(bundleName, useAot: useAot, packageRoot: packageRoot),
    );
  }

  Future<BundleContent> _loadContent(String bundleName,
      {required bool useAot, String? packageRoot}) async {
    // 1. 优先从动态包目录加载。
    if (packageRoot != null && packageRoot.isNotEmpty) {
      final fromPkg = await _loadFromDir(bundleName, packageRoot, useAot);
      if (fromPkg != null) return fromPkg;
      logger.d('[BundlePreloader] packageRoot miss, fallback assets for $bundleName');
    }

    // 2. 回退到内置 assets/js。
    if (useAot) {
      try {
        final byteData = await rootBundle.load('assets/js/$bundleName.qjc');
        return BundleContent.bytecode(byteData.buffer.asUint8List());
      } catch (_) {}
    }
    final source =
        await rootBundle.loadString('assets/js/$bundleName.js', cache: false);
    return BundleContent.source(source);
  }

  Future<BundleContent?> _loadFromDir(
      String bundleName, String root, bool useAot) async {
    // zip 内代码文件固定为 bundle.qjc / bundle.js（与包 name 无关）。
    // 动态包目录下的 qjc 可能是后台编译产出的缓存，始终优先使用。
    final qjc = File(p.join(root, 'bundle.qjc'));
    if (await qjc.exists()) {
      return BundleContent.bytecode(await qjc.readAsBytes());
    }
    final js = File(p.join(root, 'bundle.js'));
    if (await js.exists()) {
      return BundleContent.source(await js.readAsString());
    }
    return null;
  }
}

class BundleContent {
  final Uint8List? bytecode;
  final String? source;

  const BundleContent.bytecode(this.bytecode) : source = null;
  const BundleContent.source(this.source) : bytecode = null;
}
