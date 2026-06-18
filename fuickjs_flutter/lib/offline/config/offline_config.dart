class OfflineConfig {
  final String Function() envGetter;
  final Future<Map?> Function() offlinePackagesGetter;
  final Future<Map?> Function() offlineConfigGetter;
  final void Function(String tag, String? msg) logger;
  final String Function()? uaGetter;
  final bool debug;

  /// 当前 App 版本（semver），用于 minAppVersion 兼容性判断。
  final String Function()? appVersionGetter;

  /// 内置签名公钥，keyId → base64(Ed25519 公钥 32 字节)。可多把用于轮换。
  /// 为空表示不做签名校验（仅 SHA-256 完整性）。
  final Map<String, String> signaturePublicKeysB64;

  /// history 保留版本数（用于回滚）。
  final int retainVersions;

  const OfflineConfig({
    required this.envGetter,
    required this.offlinePackagesGetter,
    required this.logger,
    required this.debug,
    this.uaGetter,
    required this.offlineConfigGetter,
    this.appVersionGetter,
    this.signaturePublicKeysB64 = const {},
    this.retainVersions = 3,
  });

  String get appVersion => appVersionGetter?.call() ?? '0.0.0';
}
