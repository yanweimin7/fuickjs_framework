import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/offline/domain/entities/package.dart';
import 'package:fuickjs_flutter/offline/domain/services/download_service.dart';
import 'package:fuickjs_flutter/offline/domain/repositories/package_repository.dart';

class MockPackageRepository implements PackageRepository {
  @override
  Future<void> init() async {}

  @override
  Future<List<Package>> loadActivePackages() async => [];

  @override
  Future<void> saveActivePackages(List<Package> packages) async {}

  @override
  String getPackageDir(Package package) => '/tmp/packages/${package.name}';

  @override
  String getDownloadDir() => '/tmp/download';

  @override
  String getPackageFlagFile(Package package) =>
      '/tmp/packages/${package.name}/${package.versionShasumName}/.offline_valid.flag';

  @override
  Future<bool> validatePackage(Package package) async => true;

  @override
  Future<void> deletePackage(Package package) async {}
}

void main() {
  group('DownloadService', () {
    late MockPackageRepository repository;
    late DownloadService downloadService;

    setUp(() {
      repository = MockPackageRepository();
      downloadService = DownloadService(repository);
    });

    Package pkg(String name, String version, String shasum, {String? url}) =>
        Package(name: name, version: version, shasum: shasum, url: url);

    group('setInternalChecker', () {
      test('should set internal checker', () {
        bool called = false;
        downloadService.setInternalChecker((pkg) {
          called = true;
          return true;
        });

        final checker = (Package p) => false;
        downloadService.setInternalChecker(checker);

        expect(called, false);
      });
    });

    group('preparePackage', () {
      test('should return null when url is null or empty', () async {
        downloadService.setInternalChecker((pkg) => false);

        final result = await downloadService.preparePackage(
          pkg('test', '1.0.0', 'aaa'),
        );

        expect(result, isNull);
      });

      test('should use internal checker to determine package source', () async {
        downloadService.setInternalChecker((pkg) => true);

        final result = await downloadService.preparePackage(
          pkg('nonexistent', '1.0.0', 'aaa'),
        );

        expect(result, isNull);
      });

      test('should default to remote when no checker set', () async {
        final result = await downloadService.preparePackage(
          pkg('test', '1.0.0', 'aaa', url: 'https://example.com/test.zip'),
        );

        expect(result, isNull);
      });
    });

    group('getProgress', () {
      test('should return 0 for unknown url', () {
        expect(downloadService.getProgress('unknown'), 0);
      });

      test('should return 0 for url without progress', () {
        expect(downloadService.getProgress('https://example.com/test.zip'), 0);
      });
    });

    group('isDownloading', () {
      test('should return false for unknown url', () {
        expect(downloadService.isDownloading('unknown'), false);
      });
    });
  });
}
