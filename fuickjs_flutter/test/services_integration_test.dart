import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/core/engine/engine.dart';
import 'package:fuickjs_flutter/core/engine/jscontext_delegate.dart';
import 'package:fuickjs_flutter/core/service/app_service_binder.dart';
import 'package:fuickjs_flutter/core/service/device_info_service.dart';
import 'package:fuickjs_flutter/core/service/local_storage_service.dart';
import 'package:fuickjs_flutter/core/service/toast_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late JsContextDelegate ctx;
  late AppServiceBinder binder;
  late String tempPath;

  setUpAll(() async {
    // Create a temporary directory for testing
    final systemTempDir = Directory.systemTemp;
    final testDir = systemTempDir.createTempSync('fuick_services_js_test_');
    tempPath = testDir.path;

    // Mock path_provider method channel for LocalStorage
    const MethodChannel channel =
        MethodChannel('plugins.flutter.io/path_provider');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return tempPath;
      }
      return null;
    });

    // Initialize Engine and Isolate
    await EngineInit.initIsolate();
  });

  setUp(() async {
    final contextId = 'test_ctx_${DateTime.now().microsecondsSinceEpoch}';
    ctx = JsContextDelegate(contextId);
    await ctx.init();

    binder = AppServiceBinder();

    // Bind services
    binder.init(ctx, null, allowedServices: [
      LocalStorageService,
      DeviceInfoService,
      ToastService,
    ]);
  });

  tearDown(() {
    // Dispose context might not clean up everything if isolate is reused, but good practice
    // ctx.dispose(); // JsContextDelegate doesn't have dispose, it's just a proxy
  });

  tearDownAll(() {
    final dir = Directory(tempPath);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  Future<void> loadTsService(
      JsContextDelegate ctx, String fileName, String className) async {
    final file = File('../fuickjs/dist/services/$fileName.js');
    if (!file.existsSync()) {
      throw Exception(
          'Service file not found: ${file.path}. Please run "npm run build" in fuickjs directory first.');
    }
    final content = await file.readAsString();

    // Mock exports and require to support CommonJS module format
    // Then expose the class globally
    final script = '''
      (function() {
        const exports = {};
        const require = (id) => { return {}; }; // Mock require
        
        $content
        
        globalThis.$className = exports.$className;
      })();
    ''';

    await ctx.eval(script);
  }

  test('JS can invoke LocalStorage methods', () async {
    // Load actual TS implementation
    await loadTsService(ctx, 'LocalStorage', 'LocalStorage');

    final completer = Completer<String>();

    // We override the default onCallNative to intercept test reporting
    // But we need to keep the original handler logic for services (though here services use async/sync handlers registered in binder)
    // The binder registers itself to ctx.onCallNative.
    // We can wrap the binder's logic.

    final originalHandler = ctx.onCallNative;
    ctx.onCallNative = (method, args) {
      if (method == 'Test.reportResult') {
        completer.complete(args as String);
        return true;
      }
      return originalHandler?.call(method, args);
    };

    final script = '''
      (async () => {
        try {
          await LocalStorage.setItem('test_key', 'test_value');
          const val1 = await LocalStorage.getItem('test_key');
          
          await LocalStorage.removeItem('test_key');
          const val2 = await LocalStorage.getItem('test_key');
          
          await LocalStorage.setItem('test_key_2', 'val2');
          await LocalStorage.clear();
          const val3 = await LocalStorage.getItem('test_key_2');

          const result = JSON.stringify({
            val1,
            val2,
            val3
          });
          dartCallNative('Test.reportResult', result);
        } catch (e) {
          dartCallNative('Test.reportResult', 'ERROR: ' + e.toString());
        }
      })();
    ''';

    await ctx.eval(script);

    final result = await completer.future.timeout(const Duration(seconds: 2));

    expect(result, contains('"val1":"test_value"'));
    expect(result, contains('"val2":null'));
    expect(result, contains('"val3":null'));
  });

  test('JS can invoke DeviceInfo methods', () async {
    await loadTsService(ctx, 'DeviceInfo', 'DeviceInfo');

    final completer = Completer<String>();
    final originalHandler = ctx.onCallNative;
    ctx.onCallNative = (method, args) {
      if (method == 'Test.reportResult') {
        completer.complete(args as String);
        return true;
      }
      return originalHandler?.call(method, args);
    };

    final script = '''
      (async () => {
        try {
          const info = await DeviceInfo.getDeviceInfo();
          dartCallNative('Test.reportResult', JSON.stringify(info));
        } catch (e) {
          dartCallNative('Test.reportResult', 'ERROR: ' + e.toString());
        }
      })();
    ''';

    await ctx.eval(script);

    final result = await completer.future.timeout(const Duration(seconds: 2));

    expect(result, contains('"os":'));
    expect(result, contains('"osVersion":'));
    expect(result, contains('"screenWidth":'));
  });

  test('JS can invoke Toast methods', () async {
    await loadTsService(ctx, 'Toast', 'Toast');

    final completer = Completer<String>();
    final originalHandler = ctx.onCallNative;
    ctx.onCallNative = (method, args) {
      if (method == 'Test.reportResult') {
        completer.complete(args.toString());
        return true;
      }
      return originalHandler?.call(method, args);
    };

    final script = '''
      (async () => {
        try {
          const result = await Toast.show('Hello', 1000);
          dartCallNative('Test.reportResult', String(result));
        } catch (e) {
          dartCallNative('Test.reportResult', 'ERROR: ' + e.toString());
        }
      })();
    ''';

    await ctx.eval(script);

    final result = await completer.future.timeout(const Duration(seconds: 2));
    expect(result, 'false');
  });
}
