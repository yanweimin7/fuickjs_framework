import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/offline/domain/services/bundle_verifier.dart';
import 'package:fuickjs_flutter/offline/domain/services/remote_packages_verifier.dart';

void main() {
  group('RemotePackagesVerifier (P0-5)', () {
    late BundleVerifier bundleVerifier;
    late RemotePackagesVerifier verifier;
    late String testPubB64;
    late Ed25519 testAlgorithm;
    late SimpleKeyPair testKeyPair;
    const testKeyId = 'test-key';

    setUpAll(() async {
      testAlgorithm = Ed25519();
      testKeyPair = await testAlgorithm.newKeyPair();
      final pubBytes =
          await testKeyPair.extractPublicKey().then((k) => k.bytes);
      testPubB64 = base64Encode(pubBytes);
      bundleVerifier = BundleVerifier(publicKeysB64: {testKeyId: testPubB64});
      verifier = RemotePackagesVerifier(bundleVerifier);
    });

    /// 同步地构造 canonical JSON（与 RemotePackagesVerifier 一致）。
    String canonicalize(Map<String, dynamic> m) {
      final stripped = Map<String, dynamic>.from(m)
        ..remove('_sig')
        ..remove('_kid');
      final keys = stripped.keys.toList()..sort();
      return '{${keys.map((k) => '"${_escape(k)}":${_encode(stripped[k])}').join(',')}}';
    }

    /// 用测试密钥对 canonical payload 签名，base64 输出。
    Future<String> signCanonical(String canonical) async {
      final sig = await testAlgorithm.sign(
        utf8.encode(canonical),
        keyPair: testKeyPair,
      );
      return base64Encode(sig.bytes);
    }

    test('rejects map without _sig (P0-5 mandatory)', () async {
      final m = {
        'packages': [
          {'name': 'a', 'version': '1.0.0', 'sha256': 'h'}
        ],
      };
      expect(await verifier.verify(m), isNull);
    });

    test('rejects map with empty _sig', () async {
      final m = {
        '_sig': '',
        '_kid': testKeyId,
        'packages': [],
      };
      expect(await verifier.verify(m), isNull);
    });

    test('accepts valid signed map and returns stripped version', () async {
      final payload = {
        'packages': [
          {'name': 'a', 'version': '1.0.0', 'sha256': 'h'},
          {'name': 'b', 'version': '2.0.0', 'sha256': 'i'},
        ],
      };
      final sig = await signCanonical(canonicalize(payload));
      final signed = {
        ...payload,
        '_sig': sig,
        '_kid': testKeyId,
      };
      final verified = await verifier.verify(signed);
      expect(verified, isNotNull);
      expect(verified!['packages'], hasLength(2));
      expect(verified.containsKey('_sig'), false);
      expect(verified.containsKey('_kid'), false);
    });

    test('rejects map with tampered content after signing', () async {
      final payload = {
        'packages': [
          {'name': 'a', 'version': '1.0.0', 'sha256': 'h'},
        ],
      };
      final sig = await signCanonical(canonicalize(payload));
      // 攻击者：保留签名，但塞入额外包
      final tampered = {
        ...payload,
        'packages': [
          ...payload['packages'] as List,
          {'name': 'evil', 'version': '0.0.1', 'sha256': 'z'},
        ],
        '_sig': sig,
        '_kid': testKeyId,
      };
      expect(await verifier.verify(tampered), isNull);
    });

    test('rejects when keyId unknown', () async {
      final payload = {'packages': []};
      final sig = await signCanonical(canonicalize(payload));
      final signed = {
        ...payload,
        '_sig': sig,
        '_kid': 'unknown-key',
      };
      expect(await verifier.verify(signed), isNull);
    });

    test('rejects when wrong public key used to verify', () async {
      // 签名是用 testKeyPair 签的，但 verifier 用另一组公钥。
      final otherKeyPair = await testAlgorithm.newKeyPair();
      final otherPubB64 = base64Encode(
          await otherKeyPair.extractPublicKey().then((k) => k.bytes));
      final wrongVerifier = BundleVerifier(
        publicKeysB64: {'other': otherPubB64},
      );
      final verifier2 = RemotePackagesVerifier(wrongVerifier);

      final payload = {'packages': []};
      final sig = await signCanonical(canonicalize(payload));
      final signed = {
        ...payload,
        '_sig': sig,
        '_kid': 'other',
      };
      expect(await verifier2.verify(signed), isNull);
    });
  });
}

// ── Helpers（与 RemotePackagesVerifier._canonicalize 保持一致） ──

String _escape(String s) => s.replaceAll(r'\"', r'\\"').replaceAll('"', r'\"');

String _encode(dynamic v) {
  if (v == null) return 'null';
  if (v is bool) return v.toString();
  if (v is num) return v.toString();
  if (v is String) return '"${_escape(v)}"';
  if (v is List) return '[${v.map(_encode).join(',')}]';
  if (v is Map) {
    final keys = v.keys.toList()..sort();
    return '{${keys.map((k) => '"${_escape(k.toString())}":${_encode(v[k])}').join(',')}}';
  }
  return '"${_escape(v.toString())}"';
}

// ignore: unused_element
Uint8List? _keep() => null;
