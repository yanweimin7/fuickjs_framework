import 'package:fjs_engine/core/quickjs_ffi.dart';
import 'package:fjs_engine/core/runtime.dart';
import 'package:flutter/cupertino.dart';
import 'package:fuickjs_flutter/core/engine/worker.dart';

import '../logger.dart';

class EngineInit {
  static QuickJsFFI? _qjs;

  static QuickJsFFI? get qjs => _qjs;
  static QuickJsRuntime? runtime;

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

  static Future<void> initIsolate() async {
    await IsolateWorker.instance.ensureInitialized();
  }
  static Future<void> preload(){
    return initIsolate();
  }

  static void setUseBinaryProtocol(bool use) {
    _qjs?.setUseBinaryProtocol(use);
  }
}
