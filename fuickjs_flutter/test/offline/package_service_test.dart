import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/offline/domain/entities/package.dart';
import 'package:fuickjs_flutter/offline/domain/repositories/package_repository.dart';
import 'package:fuickjs_flutter/offline/domain/services/package_service.dart';

class MockPackageRepository implements PackageRepository {
  List<Package> _activePackages = [];
  final Map<String, bool> _validityMap = {};
  bool saveCalled = false;
  List<Package>? savedPackages;

  void setActivePackages(List<Package> packages) {
    _activePackages = List.from(packages);
  }

  void setPackageValidity(Package package, bool valid) {
    _validityMap[package.versionShasumName] = valid;
  }

  @override
  Future<void> init() async {}

  @override
  Future<List<Package>> loadActivePackages() async {
    return List.from(_activePackages);
  }

  @override
  Future<void> saveActivePackages(List<Package> packages) async {
    saveCalled = true;
    savedPackages = packages;
    _activePackages = List.from(packages);
  }

  @override
  String getPackageDir(Package package) => '/packages/${package.name}';

  @override
  String getDownloadDir() => '/download';

  @override
  String getPackageFlagFile(Package package) =>
      '/packages/${package.name}/${package.versionShasumName}/.offline_valid.flag';

  @override
  Future<bool> validatePackage(Package package) async {
    return _validityMap[package.versionShasumName] ?? true;
  }

  @override
  Future<void> deletePackage(Package package) async {}
}

void main() {
  group('PackageService', () {
    late MockPackageRepository repository;
    late PackageService packageService;

    setUp(() {
      repository = MockPackageRepository();
      packageService = PackageService(repository);
    });

    Package pkg(String name, String version, String shasum) =>
        Package(name: name, version: version, shasum: shasum);

    group('init', () {
      test('should load active packages from repository', () async {
        repository.setActivePackages([
          pkg('pkg1', '1.0.0', 'aaa'),
          pkg('pkg2', '2.0.0', 'bbb'),
        ]);

        await packageService.init();

        expect(packageService.activePackages.length, 2);
      });

      test('should filter out invalid packages and save', () async {
        repository.setActivePackages([
          pkg('pkg1', '1.0.0', 'aaa'),
        ]);
        repository.setPackageValidity(pkg('pkg1', '1.0.0', 'aaa'), false);

        await packageService.init();

        expect(packageService.activePackages, isEmpty);
        expect(repository.saveCalled, true);
      });

      test('should not save when all packages are valid', () async {
        repository.setActivePackages([
          pkg('pkg1', '1.0.0', 'aaa'),
        ]);
        repository.setPackageValidity(pkg('pkg1', '1.0.0', 'aaa'), true);

        await packageService.init();

        expect(repository.saveCalled, false);
      });

      test('should not init twice', () async {
        repository.setActivePackages([
          pkg('pkg1', '1.0.0', 'aaa'),
        ]);

        await packageService.init();
        await packageService.init();
      });
    });

    group('setRemotePackages', () {
      test('should store remote packages', () async {
        packageService.setRemotePackages([
          pkg('pkg1', '1.0.0', 'aaa'),
          pkg('pkg2', '2.0.0', 'bbb'),
        ]);

        expect(packageService.remotePackages.length, 2);
      });
    });

    group('setInternalPackages', () {
      test('should store internal packages', () async {
        packageService.setInternalPackages([
          pkg('pkg1', '1.0.0', 'aaa'),
        ]);

        expect(packageService.internalPackages.length, 1);
      });
    });

    group('isInternal', () {
      test('should return true for internal package', () async {
        packageService.setInternalPackages([
          pkg('pkg1', '1.0.0', 'aaa'),
        ]);

        expect(packageService.isInternal(pkg('pkg1', '1.0.0', 'aaa')), true);
      });

      test('should return false for non-internal package', () async {
        packageService.setInternalPackages([
          pkg('pkg1', '1.0.0', 'aaa'),
        ]);

        expect(packageService.isInternal(pkg('pkg2', '2.0.0', 'bbb')), false);
      });

      test('should return false for different version', () async {
        packageService.setInternalPackages([
          pkg('pkg1', '1.0.0', 'aaa'),
        ]);

        expect(packageService.isInternal(pkg('pkg1', '2.0.0', 'bbb')), false);
      });
    });

    group('activatePackages', () {
      test('should add new packages', () async {
        await packageService.init();

        await packageService.activatePackages([
          pkg('pkg1', '1.0.0', 'aaa'),
        ]);

        expect(packageService.activePackages.length, 1);
        expect(packageService.activePackages.first.name, 'pkg1');
        expect(repository.saveCalled, true);
      });

      test('should replace existing package with same name', () async {
        repository.setActivePackages([
          pkg('pkg1', '1.0.0', 'aaa'),
        ]);
        await packageService.init();

        await packageService.activatePackages([
          pkg('pkg1', '2.0.0', 'bbb'),
        ]);

        expect(packageService.activePackages.length, 1);
        expect(packageService.activePackages.first.version, '2.0.0');
      });

      test('should not do anything for empty list', () async {
        await packageService.init();
        repository.saveCalled = false;

        await packageService.activatePackages([]);

        expect(repository.saveCalled, false);
      });

      test('should keep existing packages when adding new ones', () async {
        repository.setActivePackages([
          pkg('pkg1', '1.0.0', 'aaa'),
        ]);
        await packageService.init();

        await packageService.activatePackages([
          pkg('pkg2', '2.0.0', 'bbb'),
        ]);

        expect(packageService.activePackages.length, 2);
      });
    });

    group('deactivatePackages', () {
      test('should remove packages', () async {
        repository.setActivePackages([
          pkg('pkg1', '1.0.0', 'aaa'),
          pkg('pkg2', '2.0.0', 'bbb'),
        ]);
        await packageService.init();

        await packageService.deactivatePackages([
          pkg('pkg1', '1.0.0', 'aaa'),
        ]);

        expect(packageService.activePackages.length, 1);
        expect(packageService.activePackages.first.name, 'pkg2');
      });

      test('should not do anything for empty list', () async {
        repository.setActivePackages([
          pkg('pkg1', '1.0.0', 'aaa'),
        ]);
        await packageService.init();
        repository.saveCalled = false;

        await packageService.deactivatePackages([]);

        expect(repository.saveCalled, false);
      });
    });

    group('isActive', () {
      test('should return true for active package', () async {
        repository.setActivePackages([
          pkg('pkg1', '1.0.0', 'aaa'),
        ]);
        await packageService.init();

        expect(packageService.isActive('pkg1', '1.0.0-aaa'), true);
      });

      test('should return false for inactive package', () async {
        repository.setActivePackages([
          pkg('pkg1', '1.0.0', 'aaa'),
        ]);
        await packageService.init();

        expect(packageService.isActive('pkg2', '2.0.0-bbb'), false);
      });

      test('should return false for different version', () async {
        repository.setActivePackages([
          pkg('pkg1', '1.0.0', 'aaa'),
        ]);
        await packageService.init();

        expect(packageService.isActive('pkg1', '2.0.0-bbb'), false);
      });
    });

    group('getActivePackage', () {
      test('should return package by name', () async {
        repository.setActivePackages([
          pkg('pkg1', '1.0.0', 'aaa'),
        ]);
        await packageService.init();

        final result = packageService.getActivePackage('pkg1');

        expect(result, isNotNull);
        expect(result!.name, 'pkg1');
      });

      test('should return null for non-existent package', () async {
        repository.setActivePackages([
          pkg('pkg1', '1.0.0', 'aaa'),
        ]);
        await packageService.init();

        final result = packageService.getActivePackage('pkg2');

        expect(result, isNull);
      });
    });
  });
}
