import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/offline/config/offline_config.dart';
import 'package:fuickjs_flutter/offline/domain/entities/package.dart';
import 'package:fuickjs_flutter/offline/domain/repositories/package_repository.dart';
import 'package:fuickjs_flutter/offline/domain/services/bundle_verifier.dart';
import 'package:fuickjs_flutter/offline/domain/services/download_service.dart';
import 'package:fuickjs_flutter/offline/domain/value_objects/package_registry.dart';

class MockPackageRepository implements PackageRepository {
  @override
  Future<void> init() async {}

  @override
  Future<PackageRegistry> loadRegistry() async => const PackageRegistry();

  @override
  Future<void> saveRegistry(PackageRegistry registry) async {}

  @override
  String getPackageDir(Package package) =>
      '/tmp/fuick-test/packages/${package.name}/${package.versionShasumName}';

  @override
  String getStagingDir(Package package) =>
      '/tmp/fuick-test/staging/${package.name}/${package.versionShasumName}';

  @override
  String getDownloadDir() => '/tmp/fuick-test/download';

  @override
  String getPackageFlagFile(Package package) =>
      '${getPackageDir(package)}/.offline_valid.flag';

  @override
  String get packagesRootDir => '/tmp/fuick-test/packages';

  @override
  String get offlineRootDir => '/tmp/fuick-test/offline';

  @override
  String builtinBundleZipAsset(String name) => 'assets/js/$name.zip';

  // 文件未落盘 → preparePackage 走完整下载/解压流程。
  @override
  Future<bool> validatePackage(Package package) async => false;

  @override
  Future<void> deletePackage(Package package) async {}

  @override
  Future<void> deleteStaging(Package package) async {}

  @override
  Future<void> promoteStaging(Package package) async {}
}

OfflineConfig testConfig() => OfflineConfig(
      envGetter: () => 'test',
      offlinePackagesGetter: () async => null,
      offlineConfigGetter: () async => null,
      logger: (_, __) {},
      debug: false,
      appVersionGetter: () => '99.0.0',
      signaturePublicKeysB64: const {'test-key': _pubKeyB64},
    );

// P0-1: 任意非空 32 字节 Ed25519 公钥即可（仅用于让 BundleVerifier 通过构造检查）。
const _pubKeyB64 = 'BpbpV8DqQE0NGgiXalTMOpBApQaDObu8byjy7Pftrps=';

void main() {
  group('DownloadService', () {
    late MockPackageRepository repository;
    late DownloadService downloadService;

    setUp(() {
      repository = MockPackageRepository();
      downloadService = DownloadService(
        repository,
        config: testConfig(),
        verifier: BundleVerifier(publicKeysB64: const {'test-key': _pubKeyB64}),
      );
    });

    Package pkg(String name, String version, String hash, {String? url}) =>
        Package(name: name, version: version, sha256: hash, url: url);

    test('returns null when remote url is empty', () async {
      downloadService.setInternalChecker((p) => false);
      final result = await downloadService.preparePackage(
        pkg('test', '1.0.0', 'aaa'),
      );
      expect(result, isNull);
    });

    test('returns null when internal asset is missing', () async {
      downloadService.setInternalChecker((p) => true);
      final result = await downloadService.preparePackage(
        pkg('nonexistent', '1.0.0', 'aaa'),
      );
      expect(result, isNull);
    });

    test('getProgress returns 0 for unknown url', () {
      expect(downloadService.getProgress('unknown'), 0);
    });

    test('isDownloading returns false for unknown url', () {
      expect(downloadService.isDownloading('unknown'), false);
    });
  });
}
