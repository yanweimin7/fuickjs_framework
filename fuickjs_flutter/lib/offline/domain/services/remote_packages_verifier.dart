import 'dart:convert';
import 'dart:typed_data';

import 'package:fuickjs_flutter/offline/util/logger.dart';

import 'bundle_verifier.dart';

/// 远程 packages 列表（latest.json）的签名验证器（P0-5）。
///
/// 协议（与 `gen-keys.js` 配套）：
/// ```json
/// {
///   "_sig": "<base64 Ed25519 sig>",
///   "_kid": "<keyId>",
///   "packages": [...]
/// }
/// ```
///
/// 签名内容：对去掉 `_sig` 后剩余字段**按 key 排序 + 无空白**的 JSON 字节做 Ed25519。
/// 验签通过则返回去掉签名头后的 Map；失败返回 null，调用方应视为"无 remote"。
///
/// P0-5 设计要点：
/// - 远程列表必须签名。未签名直接 reject（不再接受"裸 latest.json"）
/// - keyId 不识别 → reject（防止用旧公钥下发新包）
/// - 签名失败 → reject（防止中间人替换）
class RemotePackagesVerifier {
  final BundleVerifier _bundleVerifier;

  /// 强制要求：必须带签名头才接受。
  static const _kSigField = '_sig';
  static const _kKeyIdField = '_kid';

  RemotePackagesVerifier(this._bundleVerifier);

  /// 验证 [rawMap] 是否为合法的签名包列表。
  ///
  /// 返回：签名头剥离后的干净 Map（不含 `_sig` / `_kid`）。
  /// 失败返回 null —— 调用方应等同"无 remote 配置"。
  Future<Map<String, dynamic>?> verify(Map<String, dynamic> rawMap) async {
    final sig = rawMap[_kSigField] as String?;
    final kid = rawMap[_kKeyIdField] as String?;

    if (sig == null || sig.isEmpty) {
      logger(() => '[Remote] latest.json missing _sig (P0-5: signature required)');
      return null;
    }

    // 剥签名头，剩余字段做 canonical JSON。
    final stripped = Map<String, dynamic>.from(rawMap)
      ..remove(_kSigField)
      ..remove(_kKeyIdField);
    final canonical = _canonicalize(stripped);
    final ok = await _bundleVerifier.verifySignedBytes(
      Uint8List.fromList(utf8.encode(canonical)),
      sig,
      kid,
    );
    if (!ok) {
      logger(() => '[Remote] latest.json signature verify failed (kid=$kid)');
      return null;
    }
    return stripped;
  }

  /// Canonical JSON: key 排序 + 无空白。
  /// 与 Node 端 `gen-keys.js` / `sign-latest.js` 的 canonicalize 必须一致。
  static String _canonicalize(Map<String, dynamic> m) {
    final sortedKeys = m.keys.toList()..sort();
    final entries = sortedKeys.map((k) {
      final v = m[k];
      return '"${_escape(k)}":${_encodeValue(v)}';
    }).join(',');
    return '{$entries}';
  }

  static String _encodeValue(dynamic v) {
    if (v == null) return 'null';
    if (v is bool) return v.toString();
    if (v is num) return v.toString();
    if (v is String) return '"${_escape(v)}"';
    if (v is List) {
      return '[${v.map(_encodeValue).join(',')}]';
    }
    if (v is Map) {
      return _canonicalize(v.cast<String, dynamic>());
    }
    // 兜底：toString 后按字符串处理（理论上不应该到这里）。
    return '"${_escape(v.toString())}"';
  }

  static String _escape(String s) =>
      s.replaceAll(r'\"', r'\\"').replaceAll('"', r'\"');
}
