// Roundtrip test (P0-5): 用 Node sign-latest.js 离线签名 → Dart RemotePackagesVerifier 验签。
//
// 准备数据：
//   1. cd fuickjs_demo/js && node tools/bundle/sign-latest.js \
//        --in ../app/assets/js/bundles.json \
//        --out /tmp/latest_signed.json \
//        --key tools/bundle/bundle_signing_key.pem \
//        --keyId demo-key
//   2. flutter test test/offline/sign_latest_roundtrip_test.dart
//
// 注意：此测试在沙盒中读 /tmp/latest_signed.json；若文件不存在会 skip。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/offline/domain/services/bundle_verifier.dart';
import 'package:fuickjs_flutter/offline/domain/services/remote_packages_verifier.dart';

void main() {
  test('sign-latest.js ↔ RemotePackagesVerifier roundtrip', () async {
    final signedFile = File('/tmp/latest_signed.json');
    if (!await signedFile.exists()) {
      // 沙盒内没文件 → skip（CI 也可保留这个 skip 行为）
      return;
    }
    final pubFile = File(
        '/Users/wey/work/flutter_dynamic/fuickjs_demo/js/tools/bundle/bundle_signing_pub.b64');
    if (!await pubFile.exists()) {
      return;
    }
    final pubB64 = (await pubFile.readAsString()).trim();
    final map =
        jsonDecode(await signedFile.readAsString()) as Map<String, dynamic>;

    final bv = BundleVerifier(publicKeysB64: {'demo-key': pubB64});
    final rv = RemotePackagesVerifier(bv);
    final verified = await rv.verify(map);

    expect(verified, isNotNull, reason: 'signature should be accepted');
    final pkgs = verified!['packages'] as List<dynamic>;
    expect(pkgs, isNotEmpty);
    // 签名头必须被剥离。
    expect(verified.containsKey('_sig'), false);
    expect(verified.containsKey('_kid'), false);
  });
}
