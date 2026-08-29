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
///
/// 图片/资源文件不在 manifest.files 内 —— 它们仅在 DownloadService 下载/解压时
/// 由 zip 整包 SHA-256 校验（Package.integrity）。解压后的 packages 目录不再
/// 对图片做校验，威胁模型认为图片不含可执行代码；如需校验请走整包 hash 比对。
///
/// P0-1 加固：强制 Ed25519 签名。不存在 `publicKeysB64 = {}` 的"跳过签名"分支。
/// 构造函数在公钥为空时直接 throw，确保 host 必须显式注入公钥。
class BundleVerifier {
  /// 内置公钥，按 keyId → base64(公钥原始 32 字节) 映射；支持多把轮换。
  final Map<String, String> _publicKeysB64;

  /// bundle 目录内代码层验签协议固定文件名（单一数据源）。
  ///
  /// 任何需要「验签覆盖哪些文件」的代码（如 [PackageService] 的指纹计算）
  /// 都应从这里取，不要散落硬编码 `manifest.json` / `manifest.sig` 字符串。
  static const String manifestFileName = 'manifest.json';
  static const String manifestSigFileName = 'manifest.sig';

  /// 判断某个代码文件是否被排除在验签（及指纹）之外。
  ///
  /// 仅 `.qjc`（本地编译的 QuickJS 字节码）被排除：其 sha256 不固定、本就不
  /// 参与验签（见 [BundleVerifier._verifyDirImpl] 的逐文件 SHA-256 循环）。
  /// 指纹计算应与这里保持同一判定，避免 BundleCompiler 后台重编 qjc 触发重验。
  static bool isVerificationExcluded(String path) => path.endsWith('.qjc');

  BundleVerifier({
    required Map<String, String> publicKeysB64,
    bool allowEmptyKeys = false,
  }) : _publicKeysB64 = Map.unmodifiable(publicKeysB64) {
    // P0-6 强约束：未配置任何公钥 → 拒绝构造，从源头避免"无密钥跳过签"路径。
    // allowEmptyKeys=true 仅在显式关闭代码层验签（enableSignatureVerify=false）
    // 时由 Offline 传入：此时允许空公钥构造，verifyDir 会因无 key 匹配而返回
    // failure，但调用方已不依赖其返回值。
    if (!allowEmptyKeys && _publicKeysB64.isEmpty) {
      throw ArgumentError(
        'BundleVerifier requires at least one public key. '
        'P0-1/P0-6: signature verification is mandatory and cannot be disabled.',
      );
    }
  }

  /// 校验已解压目录 [dir]。
  ///
  /// 任何异常（文件 IO、编码、签名算法内部错误等）都统一转成 failure 返回 ——
  /// 不能让异常向上传播到 worker,否则会触发 Isolate.exit() 杀掉整个验签
  /// isolate,导致所有 pending 请求 hang。
  Future<VerifyResult> verifyDir(String dir) async {
    try {
      return await _verifyDirImpl(dir);
    } catch (e) {
      return VerifyResult.failure('verify error: $e');
    }
  }

  Future<VerifyResult> _verifyDirImpl(String dir) async {
    final manifestFile = File(p.join(dir, manifestFileName));
    if (!await manifestFile.exists()) {
      return const VerifyResult.failure('manifest.json missing');
    }

    final BundleManifest manifest;
    final Uint8List manifestBytes;
    try {
      manifestBytes = await manifestFile.readAsBytes();
      final map =
          jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;
      manifest = BundleManifest.fromJson(map);
    } catch (e) {
      return VerifyResult.failure('manifest parse failed: $e');
    }

    // P0-1：manifest.sig 现在是必填，删除 "hasPublicKey 跳过" 分支。
    final sigFile = File(p.join(dir, manifestSigFileName));
    if (!await sigFile.exists()) {
      return const VerifyResult.failure(
        'manifest.sig missing (P0-1: signature is mandatory)',
      );
    }
    final sigOk = await verifySignedBytes(
      manifestBytes,
      (await sigFile.readAsString()).trim(),
      manifest.keyId,
    );
    if (!sigOk) {
      return const VerifyResult.failure('signature verify failed');
    }

    // 逐代码文件 SHA-256。
    for (final f in manifest.files) {
      // 防御路径遍历：manifest 已通过 Ed25519 验签,理论上不可被篡改,
      // 但仍拒绝 .. 防止意外读取 dir 外文件。
      if (f.path.contains('..')) {
        return VerifyResult.failure('illegal path in manifest: ${f.path}');
      }
      // qjc 是 QuickJS 字节码,可能是本地编译的(引擎版本升级后 BundleCompiler
      // 重新编译生成),sha256 不固定,不参与验签。安全考量:qjc 被篡改不会执行
      // 恶意代码——字节码格式不匹配时引擎加载失败 → 回退到已验签的 bundle.js。
      if (isVerificationExcluded(f.path)) continue;
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

  /// 通用 Ed25519 验签（供 P0-5 latest.json 等复用）。
  ///
  /// 返回 true 表示签名通过，false 表示签名失败或不认识 keyId。
  Future<bool> verifySignedBytes(
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
    if (keyId == null) {
      // 无 keyId：必须显式声明匹配哪把 key，不接受静默回退。
      // 静默回退会让攻击者用一把公钥签的 bundle 蒙混到另一把公钥下。
      return null;
    }
    return _publicKeysB64[keyId]; // 未命中 → null
  }

  Future<String> _sha256OfFile(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }
}
