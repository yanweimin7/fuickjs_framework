import 'dart:async';
import 'dart:isolate';

import 'package:easy_isolate/easy_isolate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/core/engine/isolate_manager.dart';
import 'package:fuickjs_flutter/core/engine/jscontext_delegate.dart';
import 'package:fuickjs_flutter/core/engine/worker.dart';

/// init 第一次抛错、第二次成功：验证 ensureInitialized 失败后状态被重置、
/// 允许后续重试（旧实现会把 _initialized 提前置 true 且 _ready 永不完成，
/// 导致失败后永久 hang 且无法重试）。
class _FlakyWorker extends Worker {
  int initCalls = 0;

  @override
  Future<void> init(
    MainMessageHandler mainHandler,
    IsolateMessageHandler isolateHandler, {
    Object? initialMessage,
    bool queueMode = false,
    MessageHandler? errorHandler,
    MessageHandler? exitHandler,
  }) async {
    initCalls++;
    if (initCalls == 1) {
      throw Exception('simulated init failure');
    }
    // 第二次及以后视为成功：不真正 spawn isolate，仅满足 ensureInitialized 的契约。
  }
}

/// init 永远失败：验证并发调用不会永久 hang（旧实现会让所有 join 者拿到
/// 永不完成的 Future）。
class _AlwaysFailingWorker extends Worker {
  @override
  Future<void> init(
    MainMessageHandler mainHandler,
    IsolateMessageHandler isolateHandler, {
    Object? initialMessage,
    bool queueMode = false,
    MessageHandler? errorHandler,
    MessageHandler? exitHandler,
  }) async {
    throw Exception('always fails');
  }
}

class _CapturingWorker extends Worker {
  MainMessageHandler? capturedMainHandler;

  @override
  Future<void> init(
    MainMessageHandler mainHandler,
    IsolateMessageHandler isolateHandler, {
    Object? initialMessage,
    bool queueMode = false,
    MessageHandler? errorHandler,
    MessageHandler? exitHandler,
  }) async {
    capturedMainHandler = mainHandler;
  }
}

FutureOr<void> _dummyEntry(dynamic _, SendPort __, SendErrorFunction ___) {}

void main() {
  group('IsolateWorker.ensureInitialized 失败后可重试 / 不 hang', () {
    test('init 失败后可重试：第一次抛错，第二次成功，第三次幂等', () async {
      final worker = IsolateWorker.forTest(_dummyEntry, worker: _FlakyWorker());

      // 第一次：init 抛错，应向上抛出。
      await expectLater(
        worker.ensureInitialized(),
        throwsA(isA<Exception>()),
      );

      // 第二次：状态已重置，重试应成功（不再永久 hang）。
      await expectLater(worker.ensureInitialized(), completes);

      // 第三次：已 _initialized，幂等完成。
      await expectLater(worker.ensureInitialized(), completes);
    });

    test('并发调用 init 失败后不会永久 hang', () async {
      final worker =
          IsolateWorker.forTest(_dummyEntry, worker: _AlwaysFailingWorker());

      // 并发发起多次；旧实现会让首个失败后所有 join 者拿到永不完成的 Future。
      final f1 = worker.ensureInitialized();
      final f2 = worker.ensureInitialized();
      final f3 = worker.ensureInitialized();
      await expectLater(
        Future.wait([f1, f2, f3]),
        throwsA(isA<Exception>()),
      );

      // 紧随其后的一次调用也应被抛错完成（不 hang）。
      await expectLater(worker.ensureInitialized(), throwsA(isA<Exception>()));
    });
  });

  group('IsolateWorker Native callback response', () {
    test('callback 异常通过 replyPort 回传，不会让 worker 永久等待', () async {
      final backend = _CapturingWorker();
      final worker = IsolateWorker.forTest(_dummyEntry, worker: backend);
      await worker.ensureInitialized();

      final delegate = JsContextDelegate('ctx-error', worker: worker);
      delegate.onCallNativeAsync = (_, __) async {
        throw StateError('simulated native failure');
      };

      final replyPort = ReceivePort();
      final isolatePort = ReceivePort();
      addTearDown(() {
        replyPort.close();
        isolatePort.close();
      });

      await Future.sync(() => backend.capturedMainHandler!({
            'contextId': delegate.contextId,
            'type': 'callNativeAsync',
            'replyPort': replyPort.sendPort,
            'payload': {'method': 'Test.fail', 'args': null},
          }, isolatePort.sendPort));

      final envelope = await replyPort.first.timeout(
        const Duration(seconds: 1),
      );
      expect(
        () => NativeCallReply.unwrap(envelope),
        throwsA(
          isA<RemoteError>().having(
            (e) => e.toString(),
            'message',
            contains('simulated native failure'),
          ),
        ),
      );
    });

    test('delegate 缺失时也会返回结构化错误', () async {
      final backend = _CapturingWorker();
      final worker = IsolateWorker.forTest(_dummyEntry, worker: backend);
      await worker.ensureInitialized();

      final replyPort = ReceivePort();
      final isolatePort = ReceivePort();
      addTearDown(() {
        replyPort.close();
        isolatePort.close();
      });

      await Future.sync(() => backend.capturedMainHandler!({
            'contextId': 'missing-context',
            'type': 'callNativeAsync',
            'replyPort': replyPort.sendPort,
            'payload': {'method': 'Test.fail', 'args': null},
          }, isolatePort.sendPort));

      final envelope = await replyPort.first.timeout(
        const Duration(seconds: 1),
      );
      expect(
        () => NativeCallReply.unwrap(envelope),
        throwsA(isA<RemoteError>()),
      );
    });
  });
}
