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

  /// 整包 SHA-256（主完整性哈希，必填）。
  ///
  /// P0-2 加固：删除 MD5 兑底。bundles.json 里的 package 记录必须含 sha256，
  /// 否则会抛异常。这避免了攻击者注入无 sha256 的 remote package 后，
  /// 绕过 SHA-256 走 MD5 的历史错误路径。
  final String? sha256;

  /// 历史字段：MD5。不再作为完整性计算（仅作为调试信息保留）。
  /// 若 sha256 缺失，本字段不作为兑底，直接抛异常。
  @Deprecated('MD5 no longer used for integrity. Provide sha256 instead.')
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

  /// 完整性哈希：仅 sha256。不提供兑底。
  ///
  /// 缺失 sha256 是配置错误：要么宿主配置不完整，要么被攻击者伪造了一个不含
  /// sha256 的 remote package。两种情况都不应静默装上。
  String get integrity {
    if (sha256 == null || sha256!.isEmpty) {
      throw StateError(
        'Package "$name@$version" has no sha256. P0-2: SHA-256 is mandatory, '
        'MD5 (shasum) fallback has been removed. Reject this package.',
      );
    }
    return sha256!;
  }

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
