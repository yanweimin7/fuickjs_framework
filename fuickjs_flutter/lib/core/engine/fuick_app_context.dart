import 'dart:async';

import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:flutter/cupertino.dart';

import '../container/fuick_app_controller.dart';
import 'bundle_preloader.dart';
import 'engine.dart';
import 'jscontext_delegate.dart';

class FuickAppContext {
  final String appName;

  final bool useAotCode;
  final String? debugBusinessCode;

  late IQuickJsContext ctx;
  late FuickAppController appController;
  final ValueNotifier<bool> isReady = ValueNotifier<bool>(false);

  FuickAppContext({
    required this.appName,
    this.useAotCode = true,
    this.debugBusinessCode,
  });

  Future<void>? _initFuture;

  Future<void> init() {
    _initFuture ??= _doInit();
    return _initFuture!;
  }

  Future<void> _doInit() async {
    final stopwatch = Stopwatch()..start();

    // Start bundle preloading in parallel with engine initialization
    final frameworkPreload =
        BundlePreloader().preloadBundle('framework.bundle');
    final appPreload = (debugBusinessCode == null)
        ? BundlePreloader().preloadBundle(appName)
        : Future.value();

    try {
      final contextId = '${appName}_${DateTime.now().microsecondsSinceEpoch}';
      await EngineInit.initIsolate();
      debugPrint(
        '[Performance] initIsolate cost: ${stopwatch.elapsedMilliseconds}ms',
      );
      final delegate = JsContextDelegate(contextId);
      await delegate.init();
      debugPrint(
        '[Performance] JsContextDelegate.init cost: ${stopwatch.elapsedMilliseconds}ms',
      );
      ctx = delegate;
      appController = FuickAppController(ctx);

      // Wait for preloading to finish
      await Future.wait([frameworkPreload, appPreload]);

      isReady.value = true;
      await _loadBundle();
    } catch (e, s) {
      debugPrint('FuickAppContext init failed: $e\n$s');
    }
  }

  Future<void> _loadBundle() async {
    final stopwatch = Stopwatch()..start();
    try {
      await _loadSingleBundle('framework.bundle');
      debugPrint(
        '[Performance] load framework.bundle cost: ${stopwatch.elapsedMilliseconds}ms',
      );

      if (debugBusinessCode != null) {
        await ctx.eval(debugBusinessCode!);
        debugPrint(
          '[Debug] Successfully loaded business bundle from debug payload',
        );
      } else {
        await _loadSingleBundle(appName);
      }
      debugPrint(
        '[Performance] load business bundle cost: ${stopwatch.elapsedMilliseconds}ms',
      );

      appController.isBundleLoaded.value = true;
    } catch (e, s) {
      debugPrint('加载 React bundle 失败: $e\n$s');
    }
  }

  Future<void> _loadSingleBundle(String bundleName) async {
    try {
      final preloader = BundlePreloader();
      // Try using preloaded bytecode
      final bytecode = preloader.getByteCode(bundleName);
      if (bytecode != null && useAotCode) {
        await ctx.evalBinary(bytecode);
        return;
      }

      // Try using preloaded source code
      final sourceCode = preloader.getSourceCode(bundleName);
      if (sourceCode != null) {
        await ctx.eval(sourceCode);
        return;
      }

      // Fallback to file loading if not preloaded (though it should be)
      try {
        if (useAotCode) {
          await ctx.evalBinaryFile('assets/js/$bundleName.qjc');
        } else {
          await ctx.evalFile('assets/js/$bundleName.js');
        }
      } catch (e) {
        debugPrint('加载字节码 bundle $bundleName 失败，尝试加载文本 bundle: $e');
        await ctx.evalFile('assets/js/$bundleName.js');
        debugPrint('成功加载文本 bundle $bundleName');
      }
    } catch (e) {
      debugPrint('加载 bundle $bundleName 失败: $e');
      rethrow;
    }
  }

  void dispose() {
    appController.dispose();
  }
}
