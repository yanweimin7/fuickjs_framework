import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:fuickjs_flutter/core/service/app_service_binder.dart';
import 'package:fuickjs_flutter/core/service/base_fuick_service.dart';
import 'package:fuickjs_flutter/core/service/native_services.dart';

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

class _TestService extends BaseFuickService {
  _TestService(this.serviceName);

  final String serviceName;

  @override
  String get name => serviceName;
}

void main() {
  group('AppServiceBinder sync/async compatibility', () {
    late _MockContext ctx;
    late AppServiceBinder binder;
    late _TestService service;

    late List<ServiceBuilder> savedBuilders;

    setUp(() {
      ctx = _MockContext();
      binder = AppServiceBinder();
      service = _TestService('Test');
      savedBuilders = List<ServiceBuilder>.from(
        NativeServiceManager().serviceBuilders,
      );
      NativeServiceManager().serviceBuilders
        ..clear()
        ..add(() => service);
    });

    tearDown(() {
      binder.dispose();
      NativeServiceManager().serviceBuilders
        ..clear()
        ..addAll(savedBuilders);
    });

    test('callNativeAsync hits sync handler', () async {
      service.registerMethod('ping', (args) => 'pong');
      binder.init(ctx, null);

      final result = await ctx.callNativeAsync('Test.ping', null);
      expect(result, 'pong');
    });

    test('callNative hits async handler should throw strict-policy error', () {
      service.registerAsyncMethod('fetch', (args) async => {'ok': true});
      binder.init(ctx, null);

      // 严格策略: sync 桥不允许命中 registerAsyncMethod 注册的方法,
      // 必须 throw 让用户立即改用 dartCallNativeAsync。
      expect(
        () => ctx.callNative('Test.fetch', null),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('"Test.fetch"'), contains('registered as async')),
          ),
        ),
      );
    });

    test('callNativeAsync awaits sync handler returning Future', () async {
      service.registerMethod(
        'delayed',
        (args) => Future.value('done'),
      );
      binder.init(ctx, null);

      final result = await ctx.callNativeAsync('Test.delayed', null);
      expect(result, 'done');
    });
  });
}
