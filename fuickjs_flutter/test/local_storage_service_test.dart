import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/core/service/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('LocalStorageService setItem and getItem', () async {
    final service = LocalStorageService();
    final setItem = service.asyncMethods['setItem']!;
    final getItem = service.asyncMethods['getItem']!;

    await setItem(['key1', 'value1']);
    final result = await getItem(['key1']);

    expect(result, 'value1');
  });

  test('LocalStorageService persistence', () async {
    final service1 = LocalStorageService();
    final setItem = service1.asyncMethods['setItem']!;
    await setItem(['key2', 'value2']);

    // Re-create service to simulate app restart (file read)
    final service2 = LocalStorageService();
    final getItem = service2.asyncMethods['getItem']!;

    final result = await getItem(['key2']);
    expect(result, 'value2');
  });

  test('LocalStorageService removeItem', () async {
    final service = LocalStorageService();
    final setItem = service.asyncMethods['setItem']!;
    final removeItem = service.asyncMethods['removeItem']!;
    final getItem = service.asyncMethods['getItem']!;

    await setItem(['key3', 'value3']);
    await removeItem(['key3']);
    final result = await getItem(['key3']);

    expect(result, null);
  });

  test('LocalStorageService clear', () async {
    final service = LocalStorageService();
    final setItem = service.asyncMethods['setItem']!;
    final clear = service.asyncMethods['clear']!;
    final getItem = service.asyncMethods['getItem']!;

    await setItem(['key4', 'value4']);
    await clear([]);
    final result = await getItem(['key4']);

    expect(result, null);
  });
}
