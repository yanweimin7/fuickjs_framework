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

    test('error for unknown method (no handler, main isolate strict)', () {
      // 主 isolate 上未注册任何方法,允许 allowedServices 白名单(仅影响
      // 哪些 service 实例被加进来),主 isolate 默认 allowSyncToAsyncFallback=false
      // 仍抛"no handler registered",不再有"Worker isolate"死字符串。
      binder.init(ctx, null, allowedServices: [_TestSyncService]);
      try {
        ctx.callNative('Anything', null);
        fail('expected throw');
      } on StateError catch (e) {
        expect(e.message, contains('"Anything"'));
        expect(e.message, contains('no handler registered'));
      }
    });

    test('worker isolate: allowSyncToAsyncFallback falls back to async handler',
        () async {
      // 模拟 worker isolate 场景: 业务 service(只能注册 async)被 JS 端错用
      // sync 调用,允许 sync→async 智能转发,不再硬崩。
      svc.registerAsyncMethod('renderUI', (args) async => 'rendered');
      binder.init(
        ctx,
        null,
        allowSyncToAsyncFallback: true,
      );
      // 不抛错,返回 async handler 的结果(Future,会 await 完成)。
      final result = await ctx.callNative('X.renderUI', null);
      expect(result, 'rendered');
    });

    test('worker isolate: sync→fallbackAsync when no local handler at all',
        () async {
      // 业务 service 不在本 isolate(白名单过滤掉了),sync 路径命中时
      // 走 fallbackAsync 转发到主 isolate。允许 sync→async 转发。
      binder.init(
        ctx,
        null,
        allowSyncToAsyncFallback: true,
        fallbackAsync: (method, args) async => 'forwarded:$method',
      );
      final result = await ctx.callNative('Unknown.method', null);
      expect(result, 'forwarded:Unknown.method');
    });

    test(
        'worker isolate: still throws if no local handler AND no fallbackAsync',
        () {
      // 兜底都没有 → 抛错(动态从实际注册列表生成文案,不再写死)。
      binder.init(ctx, null, allowSyncToAsyncFallback: true);
      try {
        ctx.callNative('Anything', null);
        fail('expected throw');
      } on StateError catch (e) {
        expect(e.message, contains('"Anything"'));
        expect(e.message, contains('no handler registered'));
        // 错误信息动态从实际注册列表生成。
        expect(e.message, contains('Registered sync handlers:'));
      }
    });

    test('main isolate strict policy preserved: sync hitting async throws', () {
      // 主 isolate 默认 allowSyncToAsyncFallback=false,保留历史严格策略
      // —— 业务 service 错用 sync 调用必须立即报错让用户改代码。
      svc.registerAsyncMethod('renderUI', (_) async => true);
      binder.init(ctx, null);
      try {
        ctx.callNative('X.renderUI', null);
        fail('expected throw');
      } on StateError catch (e) {
        expect(e.message, contains('"X.renderUI"'));
        expect(e.message, contains('registered as async'));
      }
    });
  });
}
