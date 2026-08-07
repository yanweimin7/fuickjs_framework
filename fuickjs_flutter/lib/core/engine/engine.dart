import 'dart:io';

import 'package:fjs_engine/core/jsc_runtime.dart';
import 'package:fjs_engine/core/quickjs_ffi.dart';
import 'package:fjs_engine/core/runtime.dart';
import 'package:flutter/cupertino.dart';
import 'package:fuickjs_flutter/core/engine/worker.dart';

import '../logger.dart';

class EngineInit {
  static QuickJsFFI? _qjs;

  static QuickJsFFI? get qjs => _qjs;
  static QuickJsRuntime? runtime;
  static JscRuntime? jscRuntime;

  ///只需要在isolate中初始化
  static initQjs() {
    if (_qjs == null) {
      try {
        logger.d("init runtime");
        final lib = QuickJsFFI.load();
        _qjs = QuickJsFFI(lib);
        runtime = QuickJsRuntime(_qjs!);
      } catch (e) {
        logger.e('初始化错误: $e');
        runtime = null;
      }
    }
  }

  static void initJsc() {
    jscRuntime ??= JscRuntime();
  }

  /// Set to false before [initIsolate] / [preload] to force QuickJS on iOS.
  static bool get useJscOnIos => IsolateWorker.useJscOnIos;
  static set useJscOnIos(bool value) => IsolateWorker.useJscOnIos = value;

  static Future<void> initIsolate() async {
    await IsolateWorker.instance.ensureInitialized();
  }
  static Future<void> preload(){
    return initIsolate();
  }

  static void setUseBinaryProtocol(bool use) {
    _qjs?.setUseBinaryProtocol(use);
  }

  /// 当前引擎是否支持 JS 源码 → 字节码本地编译。
  /// JSC 无便携字节码格式，仅 QuickJS 支持。
  static bool get supportsBytecodeCompilation =>
      !(useJscOnIos && Platform.isIOS);

  /// 触发一次引擎层故意崩溃(SIGSEGV)，用于验证 native 崩溃符号化链路。
  /// Debug-only 测试入口，业务代码禁止调用。
  static void debugCrash() => QuickJsFFI.debugCrash();
}
