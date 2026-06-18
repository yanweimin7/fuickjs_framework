import 'dart:async';

import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:flutter/services.dart';
import 'package:fuickjs_flutter/core/engine/worker.dart';

class JsContextDelegate implements IQuickJsContext {
  final String contextId;
  final IsolateWorker _worker;

  FutureOr<dynamic> Function(String method, dynamic args)? _onCallNative;
  FutureOr<dynamic> Function(String method, dynamic args)? _onCallNativeAsync;

  JsContextDelegate(this.contextId, {IsolateWorker? worker})
      : _worker = worker ?? IsolateWorker.instance {
    _worker.registerDelegate(this);
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
    await _worker.sendRequest(contextId, 'createContext', null);
  }

  @override
  Future<dynamic> eval(String code, {bool returnValue = true}) =>
      _worker.sendRequest(contextId, 'eval', {'code': code, 'returnValue': returnValue});

  @override
  Future<dynamic> evalModule(String code) =>
      _worker.sendRequest(contextId, 'evalModule', code);

  @override
  Future<dynamic> evalBinary(Uint8List bytecode,
      {bool returnValue = false, bool isModule = false}) =>
      _worker.sendRequest(contextId, 'evalBinary',
          {'bytecode': bytecode, 'returnValue': returnValue, 'isModule': isModule});

  @override
  Future<Uint8List> compile(String code,
          {bool isModule = false, bool stripSource = true}) async {
    final res = await _worker.sendRequest(contextId, 'compile', {
      'code': code,
      'isModule': isModule,
      'stripSource': stripSource,
    });
    return res as Uint8List;
  }

  @override
  dynamic invoke(String? objectName, String methodName, List<dynamic> args) =>
      _worker.sendRequest(contextId, 'invoke', {
        'objectName': objectName,
        'methodName': methodName,
        'args': args,
      });

  @override
  void registerModule(String name, String code) {
    _worker.sendRequest(contextId, 'registerModule', {
      'name': name,
      'code': code,
    }).catchError((e) {
      // Log but don't throw - registerModule is void in the interface
      assert(() { print('[JsContextDelegate] registerModule error: $e'); return true; }());
    });
  }

  @override
  Future<int> runJobs() async {
    final res = await _worker.sendRequest(
      contextId,
      'runJobs',
      null,
    );
    return res as int? ?? 0;
  }

  @override
  void dispose() {
    _worker.sendRequest(contextId, 'disposeContext', null);
    _worker.unregisterDelegate(contextId);
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
