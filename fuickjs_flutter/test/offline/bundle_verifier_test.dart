import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/offline/domain/services/bundle_verifier.dart';
import 'package:path/path.dart' as p;

// 与 tools/bundle/gen-keys.js 生成、pack-bundle.js 打包的 fixture 配对的公钥。
const _pubKeyB64 = 'BpbpV8DqQE0NGgiXalTMOpBApQaDObu8byjy7Pftrps=';
const _keyId = 'key-test';
const _fixtureZip = 'test/offline/fixtures/test_bundle-1.0.0.zip';

void main() {
  group('BundleVerifier (cross-language with Node pack-bundle)', () {
    late Directory tmp;
    late String dir;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('fuick-verify-');
      dir = p.join(tmp.path, 'bundle');
      await _extractZip(File(_fixtureZip), dir);
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('valid bundle passes with public key', () async {
      final verifier = BundleVerifier(publicKeysB64: {_keyId: _pubKeyB64});
      final r = await verifier.verifyDir(dir);
      expect(r.ok, true, reason: r.reason);
      expect(r.manifest!.name, 'test_bundle');
    });

    test('valid bundle passes without public key (hash only)', () async {
      final verifier = BundleVerifier();
      final r = await verifier.verifyDir(dir);
      expect(r.ok, true, reason: r.reason);
    });

    test('tampered CODE file fails verification', () async {
      // 篡改代码文件 → 逐文件 SHA-256 不匹配。
      final code = File(p.join(dir, 'bundle.js'));
      await code.writeAsString('var x=999;x;');

      final verifier = BundleVerifier(publicKeysB64: {_keyId: _pubKeyB64});
      final r = await verifier.verifyDir(dir);
      expect(r.ok, false);
    });

    test('tampered IMAGE does not affect code-layer verification', () async {
      // 篡改图片（不在 manifest）→ 代码层验签不受影响。
      final img = File(p.join(dir, 'assets', 'images', 'logo.png'));
      await img.writeAsString('TAMPERED');

      final verifier = BundleVerifier(publicKeysB64: {_keyId: _pubKeyB64});
      final r = await verifier.verifyDir(dir);
      expect(r.ok, true, reason: r.reason);
    });

    test('tampered manifest.json fails signature', () async {
      final manifest = File(p.join(dir, 'manifest.json'));
      final content = await manifest.readAsString();
      await manifest.writeAsString(content.replaceFirst('1.0.0', '9.9.9'));

      final verifier = BundleVerifier(publicKeysB64: {_keyId: _pubKeyB64});
      final r = await verifier.verifyDir(dir);
      expect(r.ok, false);
    });
  });
}

Future<void> _extractZip(File zipFile, String outputPath) async {
  final bytes = await zipFile.readAsBytes();
  final archive = ZipDecoder().decodeBytes(bytes);
  for (final file in archive.files) {
    if (file.isSymbolicLink) continue;
    final filePath = p.join(outputPath, p.normalize(file.name));
    if (!file.isFile) {
      await Directory(filePath).create(recursive: true);
      continue;
    }
    final outFile = File(filePath);
    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(file.content as List<int>);
  }
}
