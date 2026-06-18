/// 包在状态机中的角色。
enum PackageState {
  /// 已下载校验通过，等待"下次打开"提升为 active。
  staged,

  /// 当前生效，引擎加载它。
  active,

  /// 曾经 active 的旧版本，保留用于本地复用（回滚时远程改指该版本即可）。
  history,
}

PackageState _stateFromString(String? s) {
  switch (s) {
    case 'staged':
      return PackageState.staged;
    case 'history':
      return PackageState.history;
    case 'active':
    default:
      return PackageState.active;
  }
}

String _stateToString(PackageState s) => s.name;

class Package {
  final String name;
  final String version;

  /// 整包 SHA-256（新主完整性哈希）。
  final String? sha256;

  /// 兼容旧字段（历史上为 MD5）。新流程优先使用 [sha256]。
  final String shasum;

  final String? url;
  final bool mustBeUpdated;
  final int? timestamp;

  /// 最低 App 版本要求（semver）。低于此版本不加载。
  final String? minAppVersion;

  /// 状态机角色。
  final PackageState state;

  const Package({
    required this.name,
    required this.version,
    this.sha256,
    this.shasum = '',
    this.url,
    this.mustBeUpdated = false,
    this.timestamp,
    this.minAppVersion,
    this.state = PackageState.active,
  });

  /// 完整性哈希：优先 sha256，回退 shasum。
  String get integrity => (sha256 != null && sha256!.isNotEmpty) ? sha256! : shasum;

  /// 全局唯一身份标识 / 目录名：`<name>-<version>-<hash>`（日志与路径均可区分 bundle）。
  String get versionShasumName => '$name-$version-$integrity';

  /// 同 bundle 下版本+完整性是否相同（name 已含在 [versionShasumName] 中）。
  bool isSameVersion(Package other) =>
      versionShasumName == other.versionShasumName;

  factory Package.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String?;
    final version = json['version'] as String?;
    if (name == null || name.isEmpty) {
      throw ArgumentError('Package name is required');
    }
    if (version == null || version.isEmpty) {
      throw ArgumentError('Package version is required');
    }
    return Package(
      name: name,
      version: version,
      sha256: json['sha256'] as String?,
      shasum: (json['shasum'] as String?) ?? '',
      url: json['url'] as String?,
      mustBeUpdated: json['mustBeUpdated'] as bool? ?? false,
      timestamp: json['timeStamp'] as int? ?? json['timestamp'] as int?,
      minAppVersion: json['minAppVersion'] as String?,
      state: _stateFromString(json['state'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'version': version,
      'sha256': sha256,
      'shasum': shasum,
      'url': url,
      'mustBeUpdated': mustBeUpdated,
      'timeStamp': timestamp,
      'minAppVersion': minAppVersion,
      'state': _stateToString(state),
    };
  }

  Package copyWith({
    String? name,
    String? version,
    String? sha256,
    String? shasum,
    String? url,
    bool? mustBeUpdated,
    int? timestamp,
    String? minAppVersion,
    PackageState? state,
  }) {
    return Package(
      name: name ?? this.name,
      version: version ?? this.version,
      sha256: sha256 ?? this.sha256,
      shasum: shasum ?? this.shasum,
      url: url ?? this.url,
      mustBeUpdated: mustBeUpdated ?? this.mustBeUpdated,
      timestamp: timestamp ?? this.timestamp,
      minAppVersion: minAppVersion ?? this.minAppVersion,
      state: state ?? this.state,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Package &&
          name == other.name &&
          version == other.version &&
          integrity == other.integrity &&
          url == other.url;

  @override
  int get hashCode => Object.hash(name, version, integrity, url);
}
