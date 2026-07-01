import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:fuickjs_flutter/core/service/app_service_binder.dart';
import 'package:fuickjs_flutter/core/service/base_fuick_service.dart';
import 'package:fuickjs_flutter/core/service/native_services.dart';
import 'package:fuickjs_flutter/core/service/sync_fuick_service.dart';

class _MockContext implements IQuickJsContext {
  FutureOr<dynamic> Function(String method, dynamic args)? _onCallNative;
  FutureOr<dynamic> Function(String method, dynamic args)? _onCallNativeAsync;

  @override
  set onCallNative(
      FutureOr<dynamic> Function(String method, dynamic args)? cb) {
    _onCallNative = cb;
  }

  @override
  set onCallNativeAsync(
    FutureOr<dynamic> Function(String method, dynamic args)? cb,
  ) {
    _onCallNativeAsync = cb;
  }

  FutureOr<dynamic> callNative(String method, dynamic args) =>
      _onCallNative!(method, args);

  FutureOr<dynamic> callNativeAsync(String method, dynamic args) =>
      _onCallNativeAsync!(method, args);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestSyncService extends SyncFuickService {
  _TestSyncService(this.serviceName);
  final String serviceName;
  @override
  String get name => serviceName;
}

class _TestAsyncService extends BaseFuickService {
  _TestAsyncService(this.serviceName);
  final String serviceName;
  @override
  String get name => serviceName;
}

void main() {
  group('AppServiceBinder dispose + reinit', () {
    late _MockContext ctx1;
    late _MockContext ctx2;
    late AppServiceBinder binder;
    late _TestSyncService svc;
    late _TestAsyncService asyncSvc;
    late List<ServiceBuilder> savedBuilders;

    setUp(() {
      ctx1 = _MockContext();
      ctx2 = _MockContext();
      binder = AppServiceBinder();
      svc = _TestSyncService('Reinit');
      asyncSvc = _TestAsyncService('AsyncSvc');
      savedBuilders = List<ServiceBuilder>.from(
        NativeServiceManager().serviceBuilders,
      );
      NativeServiceManager().serviceBuilders
        ..clear()
        ..add(() => svc)
        ..add(() => asyncSvc);
    });

    tearDown(() {
      binder.dispose();
      NativeServiceManager().serviceBuilders
        ..clear()
        ..addAll(savedBuilders);
    });

    test('reinit replaces handlers — ctx2 gets the new bindings', () async {
      svc.registerMethod('ping', (_) => 'first');
      asyncSvc.registerAsyncMethod('fetch', (_) async => 'first');
      binder.init(ctx1, null);
      expect(await ctx1.callNativeAsync('Reinit.ping', null), 'first');
      expect(await ctx1.callNativeAsync('AsyncSvc.fetch', null), 'first');

      // Re-register new handlers then reinit on ctx2.
      svc.registerMethod('ping', (_) => 'second');
      asyncSvc.registerAsyncMethod('fetch', (_) async => 'second');
      binder.init(ctx2, null);
      expect(await ctx2.callNativeAsync('Reinit.ping', null), 'second');
      expect(await ctx2.callNativeAsync('AsyncSvc.fetch', null), 'second');
    });

    test('dispose disposes all services and clears the service list', () {
      svc.registerMethod('op', (_) => 1);
      asyncSvc.registerAsyncMethod('op', (_) async => 1);
      binder.init(ctx1, null);
      expect(svc.isDisposed, isFalse);
      expect(asyncSvc.isDisposed, isFalse);

      binder.dispose();

      expect(svc.isDisposed, isTrue);
      expect(asyncSvc.isDisposed, isTrue);
    });
  });

  group('AppServiceBinder allowedServices filter', () {
    late _MockContext ctx;
    late AppServiceBinder binder;
    late _TestSyncService syncSvc;
    late _TestAsyncService asyncSvc;
    late List<ServiceBuilder> savedBuilders;

    setUp(() {
      ctx = _MockContext();
      binder = AppServiceBinder();
      syncSvc = _TestSyncService('SyncOnly');
      asyncSvc = _TestAsyncService('AsyncOnly');
      savedBuilders = List<ServiceBuilder>.from(
        NativeServiceManager().serviceBuilders,
      );
      NativeServiceManager().serviceBuilders
        ..clear()
        ..add(() => syncSvc)
        ..add(() => asyncSvc);
    });

    tearDown(() {
      binder.dispose();
      NativeServiceManager().serviceBuilders
        ..clear()
        ..addAll(savedBuilders);
    });

    test('allowedServices=null exposes all services', () async {
      syncSvc.registerMethod('p', (_) => 's');
      asyncSvc.registerAsyncMethod('a', (_) async => 'a');
      binder.init(ctx, null);

      expect(await ctx.callNativeAsync('SyncOnly.p', null), 's');
      expect(await ctx.callNativeAsync('AsyncOnly.a', null), 'a');
    });

    test(
        'allowedServices whitelists only matching types — others not initialized',
        () async {
      syncSvc.registerMethod('p', (_) => 's');
      asyncSvc.registerAsyncMethod('a', (_) async => 'a');
      binder.init(ctx, null, allowedServices: [_TestSyncService]);

      expect(await ctx.callNativeAsync('SyncOnly.p', null), 's');
      // AsyncOnly was filtered out — async path returns null (no throw).
      expect(await ctx.callNativeAsync('AsyncOnly.a', null), isNull);
    });

    test('allowedServices filter list excludes all types → no handlers',
        () async {
      syncSvc.registerMethod('p', (_) => 's');
      asyncSvc.registerAsyncMethod('a', (_) async => 'a');
      binder.init(ctx, null, allowedServices: []);

      // Both sync and async paths should report "no handler" / "not allowed".
      expect(
        () => ctx.callNative('SyncOnly.p', null),
        throwsA(isA<StateError>()),
      );
      // callNativeAsync with no handler returns null silently.
      expect(await ctx.callNativeAsync('AsyncOnly.a', null), isNull);
    });
  });

  group('AppServiceBinder fallbackAsync', () {
    late _MockContext ctx;
    late AppServiceBinder binder;
    late _TestAsyncService svc;
    late List<ServiceBuilder> savedBuilders;

    setUp(() {
      ctx = _MockContext();
      binder = AppServiceBinder();
      svc = _TestAsyncService('Fb');
      savedBuilders = List<ServiceBuilder>.from(
        NativeServiceManager().serviceBuilders,
      );
      NativeServiceManager().serviceBuilders
        ..clear()
        ..add(() => svc);
    });

    tearDown(() {
      binder.dispose();
      NativeServiceManager().serviceBuilders
        ..clear()
        ..addAll(savedBuilders);
    });

    test('fallbackAsync is invoked when no local handler exists', () async {
      binder.init(
        ctx,
        null,
        fallbackAsync: (method, args) async => 'fallback:$method',
      );
      expect(
        await ctx.callNativeAsync('Unknown.method', {'x': 1}),
        'fallback:Unknown.method',
      );
    });

    test('local handler takes precedence over fallbackAsync', () async {
      svc.registerAsyncMethod('known', (_) async => 'local');
      binder.init(
        ctx,
        null,
        fallbackAsync: (method, args) async => 'fallback:$method',
      );
      expect(await ctx.callNativeAsync('Fb.known', null), 'local');
    });

    test('fallbackAsync=null is OK — unknown method returns null silently',
        () async {
      binder.init(ctx, null);
      expect(await ctx.callNativeAsync('Unknown.method', null), isNull);
    });
  });

  group('AppServiceBinder sync gate error messages', () {
    late _MockContext ctx;
    late AppServiceBinder binder;
    late _TestAsyncService svc;
    late List<ServiceBuilder> savedBuilders;

    setUp(() {
      ctx = _MockContext();
      binder = AppServiceBinder();
      svc = _TestAsyncService('X');
      savedBuilders = List<ServiceBuilder>.from(
        NativeServiceManager().serviceBuilders,
      );
      NativeServiceManager().serviceBuilders
        ..clear()
        ..add(() => svc);
    });

    tearDown(() {
      binder.dispose();
      NativeServiceManager().serviceBuilders
        ..clear()
        ..addAll(savedBuilders);
    });

    test('error message mentions use of dartCallNativeAsync', () {
      svc.registerAsyncMethod('renderUI', (_) async => true);
      binder.init(ctx, null);
      try {
        ctx.callNative('X.renderUI', null);
        fail('expected throw');
      } on StateError catch (e) {
        expect(e.message, contains('dartCallNativeAsync'));
      }
    });

    test('error message lists the actual method name', () {
      svc.registerAsyncMethod('fooBar', (_) async => true);
      binder.init(ctx, null);
      try {
        ctx.callNative('X.fooBar', null);
        fail('expected throw');
      } on StateError catch (e) {
        expect(e.message, contains('"X.fooBar"'));
      }
    });

    test('error for unknown method (no handler, no allowedServices hint)', () {
      binder.init(ctx, null);
      try {
        ctx.callNative('NeverHeardOf.it', null);
        fail('expected throw');
      } on StateError catch (e) {
        expect(e.message, contains('"NeverHeardOf.it"'));
        // No hint when allowedServices is null.
        expect(e.message, isNot(contains('Worker isolate')));
      }
    });

    test('error includes worker-isolate hint when allowedServices is set', () {
      binder.init(ctx, null, allowedServices: [_TestSyncService]);
      try {
        ctx.callNative('Anything', null);
        fail('expected throw');
      } on StateError catch (e) {
        expect(e.message, contains('Worker isolate'));
      }
    });
  });
}
