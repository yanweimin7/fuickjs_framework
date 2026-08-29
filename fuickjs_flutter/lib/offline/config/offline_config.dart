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
  /// P0-1/P0-6 改为必填：传空会被构造校验拦截，不再支持"无密钥跳过签"模式。
  ///
  /// 现放宽为可选（默认空）：仅当 [enableSignatureVerify] 为 true 时才会因
  /// 空公钥在启动期被拦截；关闭验签的宿主可不配置公钥。
  final Map<String, String> signaturePublicKeysB64;

  /// 是否启用代码层验签（Ed25519 签名 + 逐代码文件 SHA-256）。
  ///
  /// 默认 true。关闭后跳过 BundleVerifier 层，但仍保留整包 zip SHA-256
  /// （DownloadService 基于版本元数据的传输完整性，不依赖签名密钥）。
  final bool enableSignatureVerify;

  /// 远程包下载进度回调（可选）：packageName → 0.0~1.0。
  ///
  /// 仅远程下载触发；内置包（assets 解压）无下载进度。框架内已按进度增量
  /// （≥1%）节流，但接口仍可能较频繁，接入方如需驱动 UI 请自行用 ValueNotifier
  /// 或再节流。终止态：1.0 表示下载完成，-1.0 表示失败/取消。
  final void Function(String packageName, double progress)? onDownloadProgress;

  /// 强制更新前征询用户（可选）：在打开 bundle、发现 mustBeUpdated 新版本时，
  /// 下载之前调用。接入方可在此弹出确认框；返回 true 表示用户同意 → 走下载流程，
  /// 返回 false 表示拒绝 → 跳过本次强制更新，直接使用本地已生效（active）包。
  ///
  /// 入参为 bundle name 与目标版本字符串。未配置（null）时视为同意（默认行为，
  /// 与既有"强制更新"语义一致，不阻塞、不弹框）。
  final Future<bool> Function(String name, String version)?
      onForcedUpdateConfirm;

  /// 强制更新判定前等待远程包列表就绪的上限。
  ///
  /// 远程同步是启动后台跑的，冷启动首次打开 bundle 往往早于列表落地，不等就必然
  /// 判成"无强制更新"（强制更新退化为下次启动生效）。代价是列表未就绪时打开会被
  /// 拖慢最多这么久（在线场景通常几百毫秒内就绪，等不满）。
  /// 设为 [Duration.zero] 表示不等待，保持"打开零延迟、强制更新尽力而为"。
  final Duration forcedUpdateRemoteWait;

  /// 强制更新下载的最长等待时间。
  ///
  /// 强制更新是在 `promoteAndGetRoot` 里同步等待的，会阻塞 bundle 打开；弱网或
  /// 服务端挂起时若不设上限，页面会一直 pending。超时后回退旧 active 继续加载，
  /// 下载本身不取消（后台跑完即 staged，下次打开生效）。
  final Duration forcedUpdateTimeout;

  /// history 保留版本数（用于回滚）。
  final int retainVersions;

  const OfflineConfig({
    required this.envGetter,
    required this.offlinePackagesGetter,
    required this.logger,
    required this.debug,
    required this.offlineConfigGetter,
    this.uaGetter,
    this.appVersionGetter,
    this.signaturePublicKeysB64 = const {},
    this.enableSignatureVerify = true,
    this.onDownloadProgress,
    this.onForcedUpdateConfirm,
    this.forcedUpdateRemoteWait = const Duration(seconds: 3),
    this.forcedUpdateTimeout = const Duration(seconds: 30),
    this.retainVersions = 3,
  });

  String get appVersion => appVersionGetter?.call() ?? '0.0.0';
}
