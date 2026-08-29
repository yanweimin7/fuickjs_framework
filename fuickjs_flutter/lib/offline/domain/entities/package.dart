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

  /// 整包 SHA-256（主完整性哈希，必填，**不能为空**）。
  ///
  /// P0-2 加固：删除 MD5 兑底。字段为非空 `String`，缺失/空 sha256 的包在
  /// [Package.fromJson] 即被抛异常拦截，**无法进入内存**——「缺 sha256」在编译期
  /// 就不可表示，取代旧的可空字段 + 运行时抛 `StateError` 的 `integrity` getter。
  final String sha256;

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
    required this.sha256,
    this.url,
    this.mustBeUpdated = false,
    this.timestamp,
    this.minAppVersion,
    this.state = PackageState.active,
  });

  /// 全局唯一身份标识 / 目录名：`<name>-<version>-<hash>`（日志与路径均可区分 bundle）。
  String get versionShasumName => '$name-$version-$sha256';

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
    final sha256 = json['sha256'] as String?;
    if (sha256 == null || sha256.isEmpty) {
      throw ArgumentError(
        'Package "$name@$version" has no sha256. P0-2: SHA-256 is mandatory, '
        'MD5 (shasum) fallback has been removed. Reject this package.',
      );
    }
    return Package(
      name: name,
      version: version,
      sha256: sha256,
      url: json['url'] as String?,
      mustBeUpdated: json['mustBeUpdated'] as bool? ?? false,
      timestamp: json['timeStamp'] as int? ?? json['timestamp'] as int?,
      minAppVersion: json['minAppVersion'] as String?,
      state: _stateFromString(json['state'] as String?),
    );
  }

  /// 容错解析：任一字段非法（缺 name/version/sha256 等）返回 null 而非抛异常。
  ///
  /// 供批量解析入口（registry / internal / remote 列表）使用，避免一个坏包拖垮
  /// 整批列表——例如攻击者往 registry.json 注入一个缺 sha256 的包，不应导致
  /// 其余正常包一起丢失。单包校验语义（抛异常）见 [Package.fromJson]。
  static Package? tryFromJson(Map<String, dynamic> json) {
    try {
      return Package.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'version': version,
      'sha256': sha256,
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
          sha256 == other.sha256 &&
          url == other.url;

  @override
  int get hashCode => Object.hash(name, version, sha256, url);
}
