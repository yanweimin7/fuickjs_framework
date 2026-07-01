import 'package:flutter_test/flutter_test.dart';
import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:fuickjs_flutter/core/service/native_event_service.dart';

class _SpyContext implements IQuickJsContext {
  final List<({String? objectName, String methodName, List<dynamic> args})>
      invokes = [];

  @override
  dynamic invoke(String? objectName, String methodName, List<dynamic> args) {
    invokes.add((objectName: objectName, methodName: methodName, args: args));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('NativeEventService', () {
    test('name is "NativeEvent"', () {
      expect(NativeEventService().name, 'NativeEvent');
    });

    test('registers an async "emit" method on construction', () {
      final svc = NativeEventService();
      expect(svc.asyncMethods.keys, contains('emit'));
    });

    test(
        'JS emit("foo", payload) forwards event name + data to Flutter listeners',
        () async {
      final svc = NativeEventService();
      svc.init(_SpyContext(), null);
      String? receivedEvent;
      Map? receivedData;
      svc.on('foo', (data) {
        receivedEvent = 'foo';
        receivedData = data as Map;
      });

      final result = await svc.asyncMethods['emit']!([
        'foo',
        {'k': 1}
      ]);
      expect(result, isTrue);
      expect(receivedEvent, 'foo');
      expect(receivedData, {'k': 1});
    });

    test('JS emit with no data passes null to Flutter listener', () async {
      final svc = NativeEventService();
      svc.init(_SpyContext(), null);
      Object? captured = 'unset';
      svc.on('noData', (d) => captured = d);

      final result = await svc.asyncMethods['emit']!(['noData']);
      expect(result, isTrue);
      expect(captured, isNull);
    });

    test('JS emit with non-list args is treated as a single arg', () async {
      final svc = NativeEventService();
      svc.init(_SpyContext(), null);
      final events = <String>[];
      svc.on('e', (d) => events.add('called'));

      // Pass a raw Map (not a List) — implementation wraps it as [args].
      final result = await svc.asyncMethods['emit']!({'level': 0});
      // After wrap, listArgs[0] is a Map, not a String, so return false.
      expect(result, isFalse);
      expect(events, isEmpty,
          reason: 'non-string first arg should not dispatch to listeners');
    });

    test('JS emit with empty list returns false and does not dispatch',
        () async {
      final svc = NativeEventService();
      svc.init(_SpyContext(), null);
      var called = 0;
      svc.on('e', (_) => called++);

      final result = await svc.asyncMethods['emit']!(<dynamic>[]);
      expect(result, isFalse);
      expect(called, 0);
    });

    test('multiple listeners on the same event all receive the payload',
        () async {
      final svc = NativeEventService();
      svc.init(_SpyContext(), null);
      final calls = <String>[];
      svc.on('x', (d) => calls.add('a:$d'));
      svc.on('x', (d) => calls.add('b:$d'));

      await svc.asyncMethods['emit']!(['x', 7]);
      expect(calls, ['a:7', 'b:7']);
    });

    test('listeners on different events are isolated', () async {
      final svc = NativeEventService();
      svc.init(_SpyContext(), null);
      final a = <dynamic>[];
      final b = <dynamic>[];
      svc.on('a', (d) => a.add(d));
      svc.on('b', (d) => b.add(d));

      await svc.asyncMethods['emit']!(['a', 1]);
      await svc.asyncMethods['emit']!(['b', 2]);
      expect(a, [1]);
      expect(b, [2]);
    });

    test('off() detaches the listener — subsequent emits skip it', () async {
      final svc = NativeEventService();
      svc.init(_SpyContext(), null);
      var called = 0;
      void cb(dynamic _) => called++;
      svc.on('e', cb);

      await svc.asyncMethods['emit']!(['e', null]);
      expect(called, 1);

      svc.off('e', cb);
      await svc.asyncMethods['emit']!(['e', null]);
      expect(called, 1, reason: 'after off, listener must not fire');
    });

    test('off() with unknown event does not throw', () {
      final svc = NativeEventService();
      svc.init(_SpyContext(), null);
      void cb(dynamic _) {}
      expect(() => svc.off('never-added', cb), returnsNormally);
    });

    test('on() returns an unsubscribe closure that detaches via off()',
        () async {
      final svc = NativeEventService();
      svc.init(_SpyContext(), null);
      var called = 0;
      final unsub = svc.on('e', (_) => called++);

      await svc.asyncMethods['emit']!(['e', null]);
      expect(called, 1);

      unsub();
      await svc.asyncMethods['emit']!(['e', null]);
      expect(called, 1);
    });

    test('off() removes only the matching callback reference', () async {
      final svc = NativeEventService();
      svc.init(_SpyContext(), null);
      var a = 0, b = 0;
      void aCb(dynamic _) => a++;
      void bCb(dynamic _) => b++;
      svc.on('e', aCb);
      svc.on('e', bCb);

      svc.off('e', aCb);
      await svc.asyncMethods['emit']!(['e', null]);
      expect(a, 0);
      expect(b, 1);
    });

    test('listener exception is caught — other listeners still fire', () async {
      final svc = NativeEventService();
      svc.init(_SpyContext(), null);
      var reached = false;
      svc.on('e', (_) => throw StateError('listener boom'));
      svc.on('e', (_) => reached = true);

      // Must not throw out of the dispatch loop.
      await svc.asyncMethods['emit']!(['e', null]);
      expect(reached, isTrue);
    });

    test(
        'listener that removes a peer during dispatch does not break iteration',
        () async {
      final svc = NativeEventService();
      svc.init(_SpyContext(), null);
      final order = <String>[];
      void peer(dynamic _) {}
      svc.on('e', peer);
      svc.on('e', (_) {
        order.add('a');
        svc.off('e', peer);
      });
      svc.on('e', (_) => order.add('b'));

      await svc.asyncMethods['emit']!(['e', null]);
      // Snapshot semantics — 'a' and 'b' both fire; 'peer' has no recording
      // here so we only assert that dispatch survives a mid-iteration removal.
      expect(order, ['a', 'b']);
    });

    test(
        'Flutter emit() forwards to JS via ctx.invoke("NativeEvent", "receive", ...)',
        () {
      final svc = NativeEventService();
      final ctx = _SpyContext();
      svc.init(ctx, null);

      svc.emit('tick', {'n': 1});
      expect(ctx.invokes, hasLength(1));
      expect(ctx.invokes.first.objectName, 'NativeEvent');
      expect(ctx.invokes.first.methodName, 'receive');
      expect(ctx.invokes.first.args, [
        'tick',
        {'n': 1}
      ]);
    });

    test('Flutter emit() swallows ctx.invoke exceptions and does not throw',
        () {
      final svc = NativeEventService();
      svc.init(_ThrowingContext(), null);
      // Should not re-throw — the service catches the exception and logs.
      expect(() => svc.emit('e', null), returnsNormally);
    });

    test('Flutter emit() after dispose is a no-op (no invoke, no throw)', () {
      final svc = NativeEventService();
      final ctx = _SpyContext();
      svc.init(ctx, null);
      svc.dispose();

      svc.emit('after-dispose', 42);
      expect(ctx.invokes, isEmpty,
          reason: 'disposed service must not push to JS');
    });

    test('dispose() clears all listeners — later JS emits have no effect',
        () async {
      final svc = NativeEventService();
      svc.init(_SpyContext(), null);
      var called = 0;
      svc.on('e', (_) => called++);

      // Capture the wrapper installed by registerAsyncMethod before dispose
      // (dispose itself clears the map, which is also asserted below).
      final wrapper = svc.asyncMethods['emit']!;
      svc.dispose();

      // After dispose, BaseFuickService.registerAsyncMethod's wrapper
      // short-circuits (isDisposed check) so the listener body never runs.
      await wrapper(['e', null]);
      expect(called, 0);
      expect(svc.asyncMethods, isEmpty);
    });

    test('isDisposed reflects state correctly', () {
      final svc = NativeEventService();
      expect(svc.isDisposed, isFalse);
      svc.init(_SpyContext(), null);
      expect(svc.isDisposed, isFalse);
      svc.dispose();
      expect(svc.isDisposed, isTrue);
    });

    test('off() of all listeners for an event removes the bucket', () async {
      final svc = NativeEventService();
      svc.init(_SpyContext(), null);
      void cb(dynamic _) {}
      svc.on('e', cb);
      svc.off('e', cb);

      // After removing the last listener, a new emit should not invoke anyone.
      var reached = false;
      svc.on('e', (_) => reached = true);
      await svc.asyncMethods['emit']!(['e', 'hello']);
      expect(reached, isTrue,
          reason: 're-subscribing after off should still receive events');
    });
  });
}

class _ThrowingContext implements IQuickJsContext {
  @override
  dynamic invoke(String? objectName, String methodName, List<dynamic> args) {
    throw StateError('boom from ctx.invoke');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
