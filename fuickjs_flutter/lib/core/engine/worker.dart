import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:easy_isolate/easy_isolate.dart';
import 'package:meta/meta.dart';

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

  IsolateWorker._(this._isolateEntry, [Worker? worker])
      : _worker = worker ?? Worker();

  /// 测试用构造：注入自定义 [Worker]（如 init 必然/首次失败的假实现），
  /// 以便回归验证 [ensureInitialized] 在 init 失败后的重试 / 不 hang 行为，
  /// 无需真正 spawn isolate。
  @visibleForTesting
  factory IsolateWorker.forTest(
    FutureOr<void> Function(dynamic, SendPort, SendErrorFunction)
        isolateEntry, {
    Worker? worker,
  }) =>
      IsolateWorker._(isolateEntry, worker);

  final FutureOr<void> Function(dynamic, SendPort, SendErrorFunction)
      _isolateEntry;

  final Worker _worker;

  static Completer<void> _newReadyCompleter() {
    final completer = Completer<void>();
    // 首个 init 调用方直接 await _worker.init 并接收 rethrow；只有并发 join 者
    // 会监听 ready.future。预挂一个 error handler，避免没有 join 者时
    // completeError 变成未处理异步错误，同时不影响其他监听者收到同一异常。
    completer.future.ignore();
    return completer;
  }

  // 非 final：init 失败时需要换一个新的 Completer 以允许后续重试。
  Completer<void> _ready = _newReadyCompleter();
  bool _initialized = false;
  // 并发 join 守卫：避免两个调用方同时通过 _initialized 判断而重复 init。
  bool _initializing = false;

  final Map<String, JsContextDelegate> _delegates = {};
  final Map<String, Completer<dynamic>> _pendingRequests = {};
  int _requestId = 0;

  Future<void> ensureInitialized() async {
    if (_initialized) return _ready.future;
    if (_initializing) return _ready.future; // 合并进行中的 init
    _initializing = true;
    try {
      await _worker.init(_mainHandler, _isolateEntry);
      _initialized = true; // 仅成功后才置位
      _ready.complete();
    } catch (e) {
      // init 失败：重置状态允许未来重试；旧的 _ready 以 error 完成，避免并发
      // join 者（已在 await 旧 _ready.future）永久 hang；本调用方通过 rethrow 报错。
      _initializing = false;
      final old = _ready;
      _ready = _newReadyCompleter();
      old.completeError(e);
      rethrow;
    }
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
      final replyPort = data['replyPort'] as SendPort?;
      try {
        if (contextId == null) {
          throw StateError('Native call is missing contextId');
        }
        final delegate = _delegates[contextId];
        if (delegate == null) {
          throw StateError('Native call context not found: $contextId');
        }

        final method = payload['method'];
        final args = payload['args'];
        final callback = (type == 'callNative')
            ? delegate.onCallNative
            : delegate.onCallNativeAsync;
        final result = callback == null ? null : await callback(method, args);
        replyPort?.send(NativeCallReply.success(result));
      } catch (e, s) {
        // replyPort 是 worker 侧这次 Native 调用的唯一完成通道；异常也必须回包，
        // 否则 ReceivePort.first 和 JS Promise 都会永久 pending。
        replyPort?.send(NativeCallReply.failure(e, s));
      }
    }
  }

  void dispose() {
    _worker.dispose();
  }
}
