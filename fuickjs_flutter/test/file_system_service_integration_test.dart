import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/core/engine/engine.dart';
import 'package:fuickjs_flutter/core/engine/jscontext_delegate.dart';
import 'package:fuickjs_flutter/core/service/app_service_binder.dart';
import 'package:fuickjs_flutter/core/service/file_system_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late JsContextDelegate ctx;
  late AppServiceBinder binder;
  late String tempPath;

  setUpAll(() async {
    // Create a temporary directory for testing
    final systemTempDir = Directory.systemTemp;
    final testDir = systemTempDir.createTempSync('fuick_fs_js_test_');
    tempPath = testDir.path;

    // Mock path_provider method channel
    const MethodChannel channel =
        MethodChannel('plugins.flutter.io/path_provider');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getTemporaryDirectory') {
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

    // We bind the FileSystemService to the delegate (which acts as the context in main isolate)
    binder.init(ctx, null, allowedServices: [FileSystemService]);
  });

  tearDown(() {
    binder.dispose(ctx);
    ctx.dispose();
  });

  tearDownAll(() {
    final dir = Directory(tempPath);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  test('JS can invoke FileSystemService methods', () async {
    // Inject JS side fs implementation (simplified)
    // We need to define dartCallNativeAsync because QuickJsContext might not expose it globally by default
    // or fjs_engine does it differently.
    // In fjs_engine, `ctx.onCallNativeAsync` is a Dart setter.
    // The JS side usually has `globalThis.dartCallNativeAsync` or similar if the engine sets it up.
    // Let's verify how fjs_engine exposes it.
    // Assuming standard fjs_engine behavior: it exposes `dartCallNativeAsync`.

    const jsSetup = r'''
      const fs = {
        writeFile: async (path, data) => {
          return await dartCallNativeAsync('FileSystem.writeFile', { path, data });
        },
        readFile: async (path, encoding) => {
          return await dartCallNativeAsync('FileSystem.readFile', { path, encoding });
        },
        exists: async (path) => {
          return await dartCallNativeAsync('FileSystem.exists', { path });
        }
      };
    ''';

    await ctx.eval(jsSetup);

    final filePath = '$tempPath/js_test.txt';
    final content = 'Hello from JS!';

    // 1. Write file via JS
    final writeScript = '''
      (async () => {
        await fs.writeFile('$filePath', '$content');
        return true;
      })();
    ''';

    // eval returns a Future that completes with the result of the last expression
    // For async IIFE, it returns a Promise. QuickJsContext.eval usually handles Promise resolution
    // if using `evaluate` or similar, but basic `eval` might return the Promise object handle.
    // Let's check how ctx.eval works. It usually returns the result.
    // If it returns a Promise, we might need to await it in Dart if the binding supports it,
    // or use a callback mechanism.

    // fjs_engine's eval returns dynamic. If it's a promise, we might need to handle it.
    // A safe way is to use `await` in JS and return a value, but `eval` evaluates the script.
    // If the script evaluates to a Promise, Dart gets a Promise object reference or Future.

    // Let's assume standard behavior: we need to handle the promise or use a done callback.
    // But for simplicity, we can just await the file existence in Dart after a short delay,
    // or use a loop to check.

    // Better: define a global function `testWrite` and call it.

    await ctx.eval('''
      async function testWrite() {
        await fs.writeFile('$filePath', '$content');
        return "ok";
      }
    ''');

    // We can't easily await the async function result via simple eval if the engine doesn't auto-resolve promises.
    // But we can check the side effect (file creation).

    await ctx.eval('testWrite();');

    // Poll for file existence
    int retries = 0;
    while (!File(filePath).existsSync() && retries < 10) {
      await Future.delayed(Duration(milliseconds: 100));
      retries++;
    }

    // Verify file content
    final file = File(filePath);
    expect(await file.exists(), true, reason: "File should be created by JS");
    expect(await file.readAsString(), 'Hello from JS!',
        reason: "File content should match");

    // 2. Read file via JS
    await ctx.eval('''
      async function testRead() {
        const content = await fs.readFile('$filePath');
        // Send back to Dart via a specialized channel or console if needed, 
        // but here we can just verify logic inside JS and throw if wrong, 
        // or write to another file.
        if (content !== '$content') {
           throw new Error("Content mismatch: " + content);
        }
        await fs.writeFile('$filePath.copy', content);
      }
    ''');

    await ctx.eval('testRead();');

    final copyPath = '$filePath.copy';
    retries = 0;
    while (!File(copyPath).existsSync() && retries < 10) {
      await Future.delayed(Duration(milliseconds: 100));
      retries++;
    }

    expect(File(copyPath).existsSync(), true,
        reason: "JS should have read and written copy");
    expect(File(copyPath).readAsStringSync(), content);
  });
}
