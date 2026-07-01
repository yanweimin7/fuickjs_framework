import 'package:flutter_test/flutter_test.dart';
import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:fuickjs_flutter/core/service/sync_fuick_service.dart';

class _TestSyncService extends SyncFuickService {
  _TestSyncService(this.serviceName);

  final String serviceName;

  @override
  String get name => serviceName;
}

class _NoopContext implements IQuickJsContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SyncFuickService', () {
    test('extends BaseFuickService — supports registerAsyncMethod too',
        () async {
      final s = _TestSyncService('Both');
      s.registerMethod('fast', (args) => 'sync');
      s.registerAsyncMethod('slow', (args) async => 'async');

      expect(s.syncMethods.containsKey('fast'), isTrue);
      expect(s.asyncMethods.containsKey('slow'), isTrue);
      expect(s.syncMethods['fast']!(null), 'sync');
      expect(await s.asyncMethods['slow']!(null), 'async');
    });

    test('registerMethod stores handler verbatim in syncMethods', () {
      final s = _TestSyncService('S');
      s.registerMethod('echo', (args) => args);
      expect(s.syncMethods['echo']!(42), 42);
    });

    test('re-registering a sync method overwrites the old handler', () {
      final s = _TestSyncService('S');
      s.registerMethod('op', (_) => 'first');
      s.registerMethod('op', (_) => 'second');
      expect(s.syncMethods['op']!(null), 'second');
    });

    test('sync method handler can return a Future — still treated as sync',
        () async {
      final s = _TestSyncService('S');
      s.registerMethod('slow', (_) => Future.value('done'));

      // The binder may bridge to async, but the handler itself can legitimately
      // return a Future and the caller can await it.
      final result = await s.syncMethods['slow']!(null);
      expect(result, 'done');
    });

    test('sync method handler exception propagates', () {
      final s = _TestSyncService('S');
      s.registerMethod('boom', (_) => throw StateError('boom'));
      expect(
        () => s.syncMethods['boom']!(null),
        throwsA(isA<StateError>()),
      );
    });

    test('isDisposed reflects BaseFuickService state', () {
      final s = _TestSyncService('S');
      expect(s.isDisposed, isFalse);
      s.init(_NoopContext(), null);
      s.dispose();
      expect(s.isDisposed, isTrue);
    });

    test('dispose clears both syncMethods and asyncMethods', () {
      final s = _TestSyncService('S');
      s.registerMethod('s', (_) => 1);
      s.registerAsyncMethod('a', (_) async => 2);
      s.dispose();
      expect(s.syncMethods, isEmpty);
      expect(s.asyncMethods, isEmpty);
    });

    test(
        'async handler returns null without invoking user code when service is disposed',
        () async {
      final s = _TestSyncService('S');
      var called = 0;
      s.registerAsyncMethod('late', (_) async {
        called++;
        return 'should not run';
      });
      s.init(_NoopContext(), null);

      final wrapper = s.asyncMethods['late']!;
      s.dispose();

      expect(await wrapper(null), isNull);
      expect(called, 0);
    });
  });
}
