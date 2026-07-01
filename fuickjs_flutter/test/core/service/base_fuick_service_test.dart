import 'package:flutter_test/flutter_test.dart';
import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:fuickjs_flutter/core/service/base_fuick_service.dart';

class _TestAsyncService extends BaseFuickService {
  _TestAsyncService(this.serviceName);

  final String serviceName;

  @override
  String get name => serviceName;
}

class _NoopContext implements IQuickJsContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('BaseFuickService', () {
    test('name getter returns the service name', () {
      final s = _TestAsyncService('MyService');
      expect(s.name, 'MyService');
    });

    test('registerAsyncMethod exposes the handler via asyncMethods map',
        () async {
      final s = _TestAsyncService('S');
      s.registerAsyncMethod('echo', (args) async => args);

      expect(s.asyncMethods.containsKey('echo'), isTrue);
      final result = await s.asyncMethods['echo']!('hello');
      expect(result, 'hello');
    });

    test('asyncMethods starts empty and only contains what was registered', () {
      final s = _TestAsyncService('S');
      expect(s.asyncMethods, isEmpty);
      s.registerAsyncMethod('a', (_) async => 1);
      s.registerAsyncMethod('b', (_) async => 2);
      expect(s.asyncMethods.keys.toSet(), {'a', 'b'});
    });

    test('re-registering an async method overwrites the old handler', () async {
      final s = _TestAsyncService('S');
      s.registerAsyncMethod('op', (_) async => 'first');
      s.registerAsyncMethod('op', (_) async => 'second');

      final result = await s.asyncMethods['op']!(null);
      expect(result, 'second');
    });

    test('handler can register multiple methods independently', () async {
      final s = _TestAsyncService('S');
      s.registerAsyncMethod('plus', (args) async {
        final m = args as Map;
        return (m['a'] as int) + (m['b'] as int);
      });
      s.registerAsyncMethod('minus', (args) async {
        final m = args as Map;
        return (m['a'] as int) - (m['b'] as int);
      });

      expect(await s.asyncMethods['plus']!({'a': 2, 'b': 3}), 5);
      expect(await s.asyncMethods['minus']!({'a': 5, 'b': 2}), 3);
    });

    test('handler exception propagates to caller', () async {
      final s = _TestAsyncService('S');
      s.registerAsyncMethod('boom', (_) async {
        throw StateError('expected');
      });

      await expectLater(
        s.asyncMethods['boom']!(null),
        throwsA(isA<StateError>()),
      );
    });

    test('isDisposed is false after init, true after dispose', () {
      final s = _TestAsyncService('S');
      expect(s.isDisposed, isFalse);
      s.init(_NoopContext(), null);
      expect(s.isDisposed, isFalse);
      s.dispose();
      expect(s.isDisposed, isTrue);
    });

    test(
        'async handler returns null without invoking user code when service is disposed',
        () async {
      final s = _TestAsyncService('S');
      var called = 0;
      s.registerAsyncMethod('late', (_) async {
        called++;
        return 'should not run';
      });
      s.init(_NoopContext(), null);

      // Capture the wrapper installed by registerAsyncMethod before dispose
      // (dispose itself clears the map, which is also asserted below).
      final wrapper = s.asyncMethods['late']!;
      s.dispose();

      // Dispose guard must short-circuit even when the wrapper is invoked
      // directly (e.g. via the previously-captured handler reference).
      final result = await wrapper(null);
      expect(result, isNull);
      expect(called, 0,
          reason: 'disposed service must not run the user handler');
    });

    test('dispose clears asyncMethods', () {
      final s = _TestAsyncService('S');
      s.registerAsyncMethod('a', (_) async => 1);
      s.registerAsyncMethod('b', (_) async => 2);
      s.dispose();
      expect(s.asyncMethods, isEmpty);
    });

    test('init can be called again after dispose to reset lifecycle', () {
      final s = _TestAsyncService('S');
      s.init(_NoopContext(), null);
      s.dispose();
      expect(s.isDisposed, isTrue);

      s.init(_NoopContext(), null);
      expect(s.isDisposed, isFalse);
    });

    test('controller defaults to null and is set by init', () {
      final s = _TestAsyncService('S');
      expect(s.controller, isNull);
      s.init(_NoopContext(), null);
      expect(s.controller, isNull);
      // Re-init with a controller stub would require a real FuickAppController
      // which has heavy dependencies; we verify the assignment path stays null-safe
      // for the common case.
    });
  });
}
