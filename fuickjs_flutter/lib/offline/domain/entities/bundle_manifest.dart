/// manifest.json 中声明的单个代码文件。
class ManifestFile {
  final String path;
  final String sha256;

  const ManifestFile({required this.path, required this.sha256});

  factory ManifestFile.fromJson(Map<String, dynamic> json) {
    final path = json['path'] as String?;
    final sha256 = json['sha256'] as String?;
    if (path == null || path.isEmpty) {
      throw const FormatException('manifest file.path is required');
    }
    if (sha256 == null || sha256.isEmpty) {
      throw const FormatException('manifest file.sha256 is required');
    }
    return ManifestFile(path: path, sha256: sha256);
  }
}

/// bundle 的 manifest.json —— 只声明代码文件（图片不入 manifest）。
class BundleManifest {
  final String name;
  final String version;
  final String? minAppVersion;
  final String? keyId;
  final String entry;
  final String codeForm; // qjc | js
  final List<ManifestFile> files;

  const BundleManifest({
    required this.name,
    required this.version,
    this.minAppVersion,
    this.keyId,
    required this.entry,
    required this.codeForm,
    required this.files,
  });

  factory BundleManifest.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String?;
    final version = json['version'] as String?;
    final entry = json['entry'] as String?;
    if (name == null || name.isEmpty) {
      throw const FormatException('manifest.name is required');
    }
    if (version == null || version.isEmpty) {
      throw const FormatException('manifest.version is required');
    }
    if (entry == null || entry.isEmpty) {
      throw const FormatException('manifest.entry is required');
    }
    final rawFiles = (json['files'] as List<dynamic>? ?? const []);
    final files = rawFiles
        .map((e) => ManifestFile.fromJson(e as Map<String, dynamic>))
        .toList();
    return BundleManifest(
      name: name,
      version: version,
      minAppVersion: json['minAppVersion'] as String?,
      keyId: json['keyId'] as String?,
      entry: entry,
      codeForm: (json['codeForm'] as String?) ?? 'qjc',
      files: files,
    );
  }
}
