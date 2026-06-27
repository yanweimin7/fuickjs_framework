import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:easy_isolate/easy_isolate.dart';

import '../service/js_error_bus.dart';
import 'isolate_manager.dart';
import 'jscontext_delegate.dart';

/// Manages a single Isolate that can host multiple JS contexts.
class IsolateWorker {
  // Controlled via EngineInit.useJscOnIos — must be set before first access.
  static bool useJscOnIos = true;

  /// Platform-appropriate worker: JSC on iOS (when [EngineInit.useJscOnIos] is true), QuickJS elsewhere.
  static IsolateWorker get instance => _instance ??= IsolateWorker._(
    Platform.isIOS && useJscOnIos ? jscIsolateEntry : quickJsIsolateEntry,
  );
  static IsolateWorker? _instance;

  IsolateWorker._(this._isolateEntry);

  final FutureOr<void> Function(dynamic, SendPort, SendErrorFunction) _isolateEntry;

  final Worker _worker = Worker();
  final Completer<void> _ready = Completer<void>();
  bool _initialized = false;

  final Map<String, JsContextDelegate> _delegates = {};
  final Map<String, Completer<dynamic>> _pendingRequests = {};
  int _requestId = 0;

  Future<void> ensureInitialized() async {
    if (_initialized) return _ready.future;
    _initialized = true;
    await _worker.init(_mainHandler, _isolateEntry);
    _ready.complete();
  }

  void registerDelegate(JsContextDelegate delegate) {
    _delegates[delegate.contextId] = delegate;
  }

  void unregisterDelegate(String contextId) {
    _delegates.remove(contextId);
  }

  Future<dynamic> sendRequest(
    String contextId,
    String type,
    dynamic payload,
  ) async {
    await ensureInitialized();
    final id = '${_requestId++}';
    final completer = Completer<dynamic>();
    _pendingRequests[id] = completer;

    try {
      _worker.sendMessage({
        'contextId': contextId,
        'type': type,
        'id': id,
        'payload': payload,
      });
    } catch (e) {
      _pendingRequests.remove(id);
      completer.completeError(e);
    }

    return completer.future;
  }

  FutureOr<void> _mainHandler(dynamic data, SendPort isolateSendPort) async {
    if (data is! Map) return;

    final contextId = data['contextId'] as String?;
    final type = data['type'];
    final id = data['id'];
    final payload = data['payload'];

    if (type == 'response') {
      final completer = _pendingRequests.remove(id);
      if (data['error'] != null) {
        completer?.completeError(data['error']);
      } else {
        completer?.complete(payload);
      }
    } else if (type == 'callNative' || type == 'callNativeAsync') {
      if (contextId == null) return;
      final delegate = _delegates[contextId];
      if (delegate == null) return;

      final method = payload['method'];
      final args = payload['args'];
      final replyPort = data['replyPort'] as SendPort?;

      final callback = (type == 'callNative')
          ? delegate.onCallNative
          : delegate.onCallNativeAsync;

      if (callback != null) {
        final result = await callback(method, args);
        replyPort?.send(result);
      } else {
        replyPort?.send(null);
      }
    } else if (type == 'jsError') {
      // isolate 里 ErrorReportService 非阻塞发回的 JS 错误，转发到 JsErrorBus
      JsErrorBus.instance.report(
        JsErrorInfo.fromMap(payload as Map<String, dynamic>),
      );
    }
  }

  void dispose() {
    _worker.dispose();
  }
}
