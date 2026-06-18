import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import '../../util/logger.dart';
import '../entities/bundle_manifest.dart';

/// 验签结果。
class VerifyResult {
  final bool ok;
  final String? reason;
  final BundleManifest? manifest;

  const VerifyResult.success(this.manifest)
      : ok = true,
        reason = null;
  const VerifyResult.failure(this.reason)
      : ok = false,
        manifest = null;
}

/// 代码层校验：Ed25519 验 manifest.sig + 对 manifest.files 逐代码文件 SHA-256。
/// 不枚举/不校验图片（图片由整包 SHA-256 兜底）。
class BundleVerifier {
  /// 内置公钥，按 keyId → base64(公钥原始 32 字节) 映射；支持多把轮换。
  final Map<String, String> _publicKeysB64;

  BundleVerifier({Map<String, String> publicKeysB64 = const {}})
      : _publicKeysB64 = publicKeysB64;

  bool get hasPublicKey => _publicKeysB64.isNotEmpty;

  /// 校验已解压目录 [dir]。
  Future<VerifyResult> verifyDir(String dir) async {
    final manifestFile = File(p.join(dir, 'manifest.json'));
    if (!await manifestFile.exists()) {
      return const VerifyResult.failure('manifest.json missing');
    }

    final BundleManifest manifest;
    final Uint8List manifestBytes;
    try {
      manifestBytes = await manifestFile.readAsBytes();
      final map = jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;
      manifest = BundleManifest.fromJson(map);
    } catch (e) {
      return VerifyResult.failure('manifest parse failed: $e');
    }

    // 签名校验：仅当配置了公钥时强制要求 manifest.sig。
    if (hasPublicKey) {
      final sigFile = File(p.join(dir, 'manifest.sig'));
      if (!await sigFile.exists()) {
        return const VerifyResult.failure('manifest.sig missing');
      }
      final sigOk = await _verifySignature(
        manifestBytes,
        (await sigFile.readAsString()).trim(),
        manifest.keyId,
      );
      if (!sigOk) {
        return const VerifyResult.failure('signature verify failed');
      }
    }

    // 逐代码文件 SHA-256。
    for (final f in manifest.files) {
      final file = File(p.join(dir, f.path));
      if (!await file.exists()) {
        return VerifyResult.failure('code file missing: ${f.path}');
      }
      final actual = await _sha256OfFile(file);
      if (actual.toLowerCase() != f.sha256.toLowerCase()) {
        return VerifyResult.failure('sha256 mismatch: ${f.path}');
      }
    }

    return VerifyResult.success(manifest);
  }

  Future<bool> _verifySignature(
    Uint8List message,
    String signatureB64,
    String? keyId,
  ) async {
    try {
      final pubB64 = _selectPublicKey(keyId);
      if (pubB64 == null) {
        logger(() => 'No public key for keyId=$keyId');
        return false;
      }
      final pubBytes = base64Decode(pubB64);
      final sigBytes = base64Decode(signatureB64);

      final algorithm = Ed25519();
      final publicKey = SimplePublicKey(pubBytes, type: KeyPairType.ed25519);
      final signature = Signature(sigBytes, publicKey: publicKey);
      return await algorithm.verify(message, signature: signature);
    } catch (e) {
      logger(() => 'signature verify error: $e');
      return false;
    }
  }

  String? _selectPublicKey(String? keyId) {
    if (_publicKeysB64.isEmpty) return null;
    if (keyId != null && _publicKeysB64.containsKey(keyId)) {
      return _publicKeysB64[keyId];
    }
    // 无 keyId 或未命中：回退到任意一把（单密钥场景）。
    return _publicKeysB64.values.first;
  }

  Future<String> _sha256OfFile(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }
}
