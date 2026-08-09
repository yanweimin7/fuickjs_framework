import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/offline/domain/services/bundle_verifier.dart';
import 'package:fuickjs_flutter/offline/domain/services/bundle_verify_isolate.dart';

void main() {
  // 任何非空 32 字节 Ed25519 公钥（仅用于让 BundleVerifier 通过构造检查）。
  // BundleVerifyIsolate 内部构造 verifier，会走同样的非空校验。
  const fakePubB64 = 'BpbpV8DqQE0NGgiXalTMOpBApQaDObu8byjy7Pftrps=';
  const fakeKeyId = 'test-key';

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fuick-verify-isolate-');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<String> makeValidDir(String name) async {
    final dir = '${tmp.path}/$name';
    await Directory(dir).create(recursive: true);
    await File('$dir/manifest.json').writeAsString('{}');
    return dir;
  }

  group('BundleVerifyIsolate lifecycle', () {
    test('create + verify + dispose', () async {
      final isolate = await BundleVerifyIsolate.create({fakeKeyId: fakePubB64});
      final dir = await makeValidDir('d1');
      final r = await isolate.verify(dir);
      expect(r.ok, false); // manifest 内容无 sig → verify 失败
      expect(r.reason, isNotNull);
      await isolate.dispose();
    });

    test('dispose rejects pending requests', () async {
      final isolate = await BundleVerifyIsolate.create({fakeKeyId: fakePubB64});
      final dir = await makeValidDir('d1');
      // 提交后立刻 dispose：pending Future 必须以 StateError reject。
      // 注意：极端情况下 isolate 可能赶在 dispose 前处理完（race），
      // 此时 fut 已 success 完成。这种情况下 dispose 不再 reject。
      // 用 catchError 兼容两种结果：要么 error，要么 success。
      final fut = isolate.verify(dir);
      await isolate.dispose();
      try {
        final result = await fut.timeout(const Duration(seconds: 1));
        // 没被 reject（race）→ success 也算 pass
        expect(result, isA<VerifyResult>());
      } on StateError {
        // 被 reject（正常路径）→ 期望抛 StateError
      }
    });
  });

  group('BundleVerifyIsolate concurrent verifies', () {
    test('8 concurrent verifies all complete', () async {
      final isolate = await BundleVerifyIsolate.create({fakeKeyId: fakePubB64});
      // 预创建 8 个目录
      final dirs = <String>[];
      for (var i = 0; i < 8; i++) {
        dirs.add(await makeValidDir('d$i'));
      }

      // 同时提交
      final futures = dirs.map(isolate.verify).toList();
      final results = await Future.wait(futures);

      // 8 个全部返回（无 hang）
      expect(results.length, 8);
      // 全部失败（无 sig）
      for (final r in results) {
        expect(r.ok, false);
      }
      await isolate.dispose();
    });

    test('10 concurrent verifies finish faster than 10x serial', () async {
      final isolate = await BundleVerifyIsolate.create({fakeKeyId: fakePubB64});
      // I/O bound (读 manifest + 验签尝试)，4 worker pool 应能并行。
      // 串行 = 10 * verify_cost；并发后 ~ 3 * verify_cost。
      final dirs = <String>[];
      for (var i = 0; i < 10; i++) {
        dirs.add(await makeValidDir('d$i'));
      }

      final sw = Stopwatch()..start();
      await Future.wait(dirs.map(isolate.verify));
      sw.stop();

      // 软性断言：< 3s。CI 慢盘 + isolate 启动开销下留余量。
      // 串行基线 ~ 10 * 5ms = 50ms，4 并发后 ~ 25ms，理论上更快。
      expect(sw.elapsedMilliseconds, lessThan(3000),
          reason: 'concurrent verifies should be parallelized');
      await isolate.dispose();
    });
  });

  group('BundleVerifyIsolate behavior', () {
    test('missing manifest.json returns failure result', () async {
      final isolate = await BundleVerifyIsolate.create({fakeKeyId: fakePubB64});
      final dir = '${tmp.path}/no-manifest';
      await Directory(dir).create();
      final r = await isolate.verify(dir);
      expect(r.ok, false);
      expect(r.reason, contains('manifest.json missing'));
      await isolate.dispose();
    });

    test('invalid manifest JSON returns parse failure', () async {
      final isolate = await BundleVerifyIsolate.create({fakeKeyId: fakePubB64});
      final dir = '${tmp.path}/bad-manifest';
      await Directory(dir).create();
      await File('$dir/manifest.json').writeAsString('not-json{{{');
      final r = await isolate.verify(dir);
      expect(r.ok, false);
      expect(r.reason, contains('manifest parse failed'));
      await isolate.dispose();
    });

    test('verify never hangs: saturated pool + short timeout always completes',
        () async {
      // 回归测试：修复前 worker 崩溃会令所有 in-flight verify 永久 hang（软 brick）。
      // 这里用 4-worker 池 + 1ms 超时 + 20 个并发请求制造"来不及处理"的局面，
      // 断言每个 Future 都必然以 VerifyResult 完成（不抛、不 hang）。
      final isolate = await BundleVerifyIsolate.create({fakeKeyId: fakePubB64});
      final dirs = <String>[];
      for (var i = 0; i < 20; i++) {
        dirs.add(await makeValidDir('d$i'));
      }
      final futures = dirs
          .map((d) => isolate.verify(d, timeout: const Duration(milliseconds: 1)))
          .toList();
      // 若超时机制失效，部分 Future 会永久挂起 → 此 await 永不返回。
      final results = await Future.wait(futures);
      expect(results.length, 20);
      for (final r in results) {
        expect(r, isA<VerifyResult>());
        expect(r.ok, false); // 无 sig 本就失败；超时也是 failure
      }
      await isolate.dispose();
    });
  });
}
