import 'dart:async';

import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:flutter/cupertino.dart';

import '../container/fuick_app_controller.dart';
import '../logger.dart';
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
    this.useAotCode = false,
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
        BundlePreloader().preloadBundle('framework.bundle', useAot: useAotCode);
    final appPreload = (debugBusinessCode == null)
        ? BundlePreloader().preloadBundle(appName,useAot: useAotCode)
        : Future.value();

    try {
      final contextId = '${appName}_${DateTime.now().microsecondsSinceEpoch}';
      await EngineInit.initIsolate();
      logger.d(
        '[Performance] initIsolate cost: ${stopwatch.elapsedMilliseconds}ms',
      );
      final delegate = JsContextDelegate(contextId);
      await delegate.init();
      logger.d(
        '[Performance] JsContextDelegate.init cost: ${stopwatch.elapsedMilliseconds}ms',
      );
      ctx = delegate;
      appController = FuickAppController(ctx);

      // Wait for preloading to finish
      await Future.wait([frameworkPreload, appPreload]);

      isReady.value = true;
      await _loadBundle();
    } catch (e, s) {
      logger.e('FuickAppContext init failed: $e\n$s');
    }
  }

  Future<void> _loadBundle() async {
    final stopwatch = Stopwatch()..start();
    try {
      await _loadSingleBundle('framework.bundle');
      logger.d(
        '[Performance] load framework.bundle cost: ${stopwatch.elapsedMilliseconds}ms',
      );

      if (debugBusinessCode != null) {
        await ctx.eval(debugBusinessCode!,returnValue: false);
        logger.d(
          '[Debug] Successfully loaded business bundle from debug payload',
        );
      } else {
        await _loadSingleBundle(appName);
      }
      logger.d(
        '[Performance] load business bundle cost: ${stopwatch.elapsedMilliseconds}ms',
      );

      appController.isBundleLoaded.value = true;
    } catch (e, s) {
      logger.e('加载 React bundle 失败: $e\n$s');
    }
  }

  Future<void> _loadSingleBundle(String bundleName) async {
    try {
      final preloader = BundlePreloader();
      // Try using preloaded bytecode
      final bytecode = preloader.getByteCode(bundleName);
      if (bytecode != null && useAotCode) {
        await ctx.evalBinary(bytecode, returnValue: false);
        return;
      }

      // Try using preloaded source code
      final sourceCode = preloader.getSourceCode(bundleName);
      if (sourceCode != null) {
        await ctx.eval(sourceCode, returnValue: false);
        return;
      }

      // Fallback to file loading if not preloaded (though it should be)
      try {
        if (useAotCode) {
          await ctx.evalBinaryFile('assets/js/$bundleName.qjc', returnValue: false);
        } else {
          await ctx.evalFile('assets/js/$bundleName.js', returnValue: false);
        }
      } catch (e) {
        logger.w('加载字节码 bundle $bundleName 失败，尝试加载文本 bundle: $e');
        await ctx.evalFile('assets/js/$bundleName.js', returnValue: false);
        logger.i('成功加载文本 bundle $bundleName');
      }
    } catch (e) {
      logger.e('加载 bundle $bundleName 失败: $e');
      rethrow;
    }
  }

  void dispose() {
    appController.dispose();
  }
}
