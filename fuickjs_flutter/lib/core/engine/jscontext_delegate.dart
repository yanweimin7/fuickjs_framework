import 'dart:async';

import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:flutter/services.dart';
import 'package:fuickjs_flutter/core/engine/worker.dart';

class JsContextDelegate implements IQuickJsContext {
  final String contextId;

  FutureOr<dynamic> Function(String method, dynamic args)? _onCallNative;
  FutureOr<dynamic> Function(String method, dynamic args)? _onCallNativeAsync;

  JsContextDelegate(this.contextId) {
    IsolateWorker.instance.registerDelegate(this);
  }

  @override
  set onCallNative(
    FutureOr<dynamic> Function(String method, dynamic args)? callback,
  ) {
    _onCallNative = callback;
  }

  @override
  set onCallNativeAsync(
    FutureOr<dynamic> Function(String method, dynamic args)? callback,
  ) {
    _onCallNativeAsync = callback;
  }

  FutureOr<dynamic> Function(String method, dynamic args)? get onCallNative =>
      _onCallNative;

  FutureOr<dynamic> Function(String method, dynamic args)?
      get onCallNativeAsync => _onCallNativeAsync;

  @override
  int get handleAddress => identityHashCode(this);

  Future<void> init() async {
    await IsolateWorker.instance.sendRequest(contextId, 'createContext', null);
  }

  @override
  Future<dynamic> eval(String code, {bool returnValue = true}) =>
      IsolateWorker.instance.sendRequest(contextId, 'eval', {'code': code, 'returnValue': returnValue});

  @override
  Future<dynamic> evalModule(String code) =>
      IsolateWorker.instance.sendRequest(contextId, 'evalModule', code);

  @override
  Future<dynamic> evalBinary(Uint8List bytecode, {bool returnValue = false}) =>
      IsolateWorker.instance.sendRequest(contextId, 'evalBinary', {'bytecode': bytecode, 'returnValue': returnValue});

  @override
  dynamic invoke(String? objectName, String methodName, List<dynamic> args) =>
      IsolateWorker.instance.sendRequest(contextId, 'invoke', {
        'objectName': objectName,
        'methodName': methodName,
        'args': args,
      });

  @override
  void registerModule(String name, String code) {
    IsolateWorker.instance.sendRequest(contextId, 'registerModule', {
      'name': name,
      'code': code,
    });
  }

  @override
  Future<int> runJobs() async {
    final res = await IsolateWorker.instance.sendRequest(
      contextId,
      'runJobs',
      null,
    );
    return res as int? ?? 0;
  }

  @override
  void dispose() {
    IsolateWorker.instance.sendRequest(contextId, 'disposeContext', null);
    IsolateWorker.instance.unregisterDelegate(contextId);
  }

  @override
  Future evalBinaryFile(String path, {bool returnValue = false}) async {
    final ByteData data = await rootBundle.load(path);
    final Uint8List bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return evalBinary(bytes, returnValue: returnValue);
  }

  @override
  Future evalFile(String path, {bool returnValue = true}) async {
    final String code = await rootBundle.loadString(path);
    return eval(code, returnValue: returnValue);
  }
}
