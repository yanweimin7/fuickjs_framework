import 'dart:io';

import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:path/path.dart' as p;

import '../logger.dart';
import 'engine.dart';

/// 后台将 JS 源码编译为 QuickJS 字节码并持久化到 bundle 目录。
///
/// 仅对 QuickJS 引擎生效（JSC 无便携字节码格式）。
/// 编译失败不阻塞业务，仅记录日志。
class BundleCompiler {
  static final Set<String> _pendingDirs = {};

  /// 若条件满足，将 [source] 编译为字节码并保存为 `<packageDir>/bundle.qjc`。
  ///
  /// 同一目录的重复调用会被忽略（防编译两次）。
  ///
  /// 跳过条件：
  /// - [packageDir] 为 null 或空
  /// - 引擎不支持字节码编译（JSC）
  /// - `bundle.qjc` 已存在
  /// - 同一目录正在编译中
  ///
  /// 此方法不 await，调用方不等待，让编译与首屏渲染并行。
  static Future<void> compileIfNeeded({
    required IQuickJsContext ctx,
    required String source,
    required String? packageDir,
  }) async {
    if (packageDir == null || packageDir.isEmpty) return;
    if (!EngineInit.supportsBytecodeCompilation) return;
    if (_pendingDirs.contains(packageDir)) return;

    final qjcPath = p.join(packageDir, 'bundle.qjc');
    if (await File(qjcPath).exists()) return;

    _pendingDirs.add(packageDir);
    // 延迟 2s 再编译，避免与首屏渲染争抢 CPU。
    await Future.delayed(const Duration(seconds: 2));

    try {
      final bytecode = await ctx.compile(
        source,
        isModule: false,
        stripSource: true,
      );
      final tmp = File('$qjcPath.tmp');
      await tmp.writeAsBytes(bytecode, flush: true);
      await tmp.rename(qjcPath);
      logger.d(
        '[BundleCompiler] compiled bundle.qjc: ${bytecode.length} bytes → $qjcPath',
      );
    } catch (e) {
      logger.d('[BundleCompiler] compile skipped: $e');
    } finally {
      _pendingDirs.remove(packageDir);
    }
  }
}
