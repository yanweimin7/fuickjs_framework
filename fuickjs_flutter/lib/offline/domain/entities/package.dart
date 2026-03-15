class Package {
  final String name;
  final String version;
  final String shasum;
  final String? url;
  final bool mustBeUpdated;
  final int? timestamp;

  String get versionShasumName => '$version-$shasum';

  bool isSameVersion(Package other) => versionShasumName == other.versionShasumName;

  const Package({
    required this.name,
    required this.version,
    required this.shasum,
    this.url,
    this.mustBeUpdated = false,
    this.timestamp,
  });

  factory Package.fromJson(Map<String, dynamic> json) {
    return Package(
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '',
      shasum: json['shasum'] as String? ?? '',
      url: json['url'] as String?,
      mustBeUpdated: json['mustBeUpdated'] as bool? ?? false,
      timestamp: json['timeStamp'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'version': version,
      'shasum': shasum,
      'url': url,
      'mustBeUpdated': mustBeUpdated,
      'timeStamp': timestamp,
    };
  }

  Package copyWith({
    String? name,
    String? version,
    String? shasum,
    String? url,
    bool? mustBeUpdated,
    int? timestamp,
  }) {
    return Package(
      name: name ?? this.name,
      version: version ?? this.version,
      shasum: shasum ?? this.shasum,
      url: url ?? this.url,
      mustBeUpdated: mustBeUpdated ?? this.mustBeUpdated,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Package &&
          name == other.name &&
          version == other.version &&
          shasum == other.shasum;

  @override
  int get hashCode => Object.hash(name, version, shasum);
}
