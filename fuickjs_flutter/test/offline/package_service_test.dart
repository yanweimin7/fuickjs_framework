import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/offline/domain/entities/package.dart';
import 'package:fuickjs_flutter/offline/domain/repositories/package_repository.dart';
import 'package:fuickjs_flutter/offline/domain/services/package_service.dart';
import 'package:fuickjs_flutter/offline/domain/value_objects/package_registry.dart';

class MockPackageRepository implements PackageRepository {
  PackageRegistry _registry = const PackageRegistry();
  final Map<String, bool> _validityMap = {};
  final List<String> deleted = [];

  void seedRegistry(PackageRegistry r) => _registry = r;
  void setValidity(Package p, bool valid) =>
      _validityMap[p.versionShasumName] = valid;

  @override
  Future<void> init() async {}

  @override
  Future<PackageRegistry> loadRegistry() async => _registry;

  @override
  Future<void> saveRegistry(PackageRegistry registry) async {
    _registry = registry;
  }

  @override
  String getPackageDir(Package package) =>
      '/packages/${package.name}/${package.versionShasumName}';

  @override
  String getStagingDir(Package package) =>
      '/staging/${package.name}/${package.versionShasumName}';

  @override
  String getDownloadDir() => '/download';

  @override
  String getPackageFlagFile(Package package) =>
      '${getPackageDir(package)}/.offline_valid.flag';

  @override
  String get packagesRootDir => '/packages';

  @override
  String get offlineRootDir => '/offline';

  @override
  String builtinBundleZipAsset(String name) => 'assets/js/$name.zip';

  @override
  Future<bool> validatePackage(Package package) async =>
      _validityMap[package.versionShasumName] ?? true;

  @override
  Future<void> deletePackage(Package package) async {
    deleted.add(package.versionShasumName);
  }

  @override
  Future<void> deleteStaging(Package package) async {}

  @override
  Future<void> promoteStaging(Package package) async {}
}

void main() {
  group('PackageService state machine', () {
    late MockPackageRepository repo;
    late PackageService service;

    setUp(() {
      repo = MockPackageRepository();
      service = PackageService(repo, retainVersions: 2);
    });

    Package pkg(String name, String version, String hash, {String? url}) =>
        Package(name: name, version: version, sha256: hash, url: url);

    test('applyReady sets single staged slot (replace semantics)', () async {
      await service.init();
      await service.applyReady([pkg('app', '1.0.0', 'h1')]);
      expect(service.stagedPackages.length, 1);

      // 下载新版本替换旧 staged（旧从未 active → 删除）。
      await service.applyReady([pkg('app', '1.1.0', 'h2')]);
      expect(service.stagedPackages.length, 1);
      expect(service.getStagedPackage('app')!.version, '1.1.0');
      expect(repo.deleted, contains('app-1.0.0-h1'));
    });

    test('promoteStaged: staged -> active, old active -> history', () async {
      repo.seedRegistry(PackageRegistry(
        active: [pkg('app', '1.0.0', 'h1').copyWith(state: PackageState.active)],
      ));
      await service.init();
      await service.applyReady([pkg('app', '2.0.0', 'h2')]);

      final newActive = await service.promoteStaged('app');
      expect(newActive!.version, '2.0.0');
      expect(service.getActivePackage('app')!.version, '2.0.0');
      expect(service.stagedPackages, isEmpty);
      expect(service.registry.history.any((p) => p.version == '1.0.0'), true);
    });

    test('history retains at most N versions', () async {
      await service.init();
      // 连续提升 4 个版本，retainVersions=2。
      for (final v in ['1.0.0', '2.0.0', '3.0.0', '4.0.0']) {
        await service.applyReady([pkg('app', v, 'h$v')]);
        await service.promoteStaged('app');
      }
      final history = service.registry.history.where((p) => p.name == 'app');
      expect(history.length, lessThanOrEqualTo(2));
      expect(service.getActivePackage('app')!.version, '4.0.0');
    });

    test('reuseLocalAsStaged uses history without download', () async {
      repo.seedRegistry(PackageRegistry(
        active: [pkg('app', '2.0.0', 'h2').copyWith(state: PackageState.active)],
        history: [
          pkg('app', '1.0.0', 'h1').copyWith(state: PackageState.history),
        ],
      ));
      repo.setValidity(pkg('app', '1.0.0', 'h1'), true);
      await service.init();

      final remote = pkg('app', '1.0.0', 'h1', url: 'https://cdn/app-1.0.0.zip');
      // 返回候选包但不落盘；由调用方统一 applyReady。
      final reused = await service.reuseLocalAsStaged(remote);
      expect(reused, isNotNull);
      expect(reused!.version, '1.0.0');
      // history 中同版本已被移除（in-memory），避免 promote 后重复。
      expect(
        service.registry.history.any((p) => p.version == '1.0.0'),
        false,
      );

      await service.applyReady([reused]);
      expect(service.getStagedPackage('app')!.version, '1.0.0');
    });

    test('promoteStaged discards stale staged when not latest remote',
        () async {
      repo.seedRegistry(PackageRegistry(
        active: [pkg('app', '1.0.0', 'h1').copyWith(state: PackageState.active)],
      ));
      await service.init();
      // 误发的 v2 已 staged。
      await service.applyReady([pkg('app', '2.0.0', 'h2')]);
      // 线上最新已撤回为 v1（≠ staged v2）。
      service.setRemotePackages([pkg('app', '1.0.0', 'h1')]);

      final result = await service.promoteStaged('app');
      // staged 被丢弃，沿用当前 active v1。
      expect(result!.version, '1.0.0');
      expect(service.stagedPackages, isEmpty);
      expect(repo.deleted, contains('app-2.0.0-h2'));
      expect(service.getActivePackage('app')!.version, '1.0.0');
    });

    test('promoteStaged promotes staged when equals latest remote', () async {
      await service.init();
      await service.applyReady([pkg('app', '2.0.0', 'h2')]);
      service.setRemotePackages([pkg('app', '2.0.0', 'h2')]);

      final result = await service.promoteStaged('app');
      expect(result!.version, '2.0.0');
      expect(service.getActivePackage('app')!.version, '2.0.0');
    });

    test('promoteStaged promotes staged when remote list not ready', () async {
      await service.init();
      await service.applyReady([pkg('app', '2.0.0', 'h2')]);
      // 未 setRemotePackages（离线/首启未同步）→ 不阻断。

      final result = await service.promoteStaged('app');
      expect(result!.version, '2.0.0');
    });

    test('promoteStaged promotes internal staged regardless of remote',
        () async {
      await service.init();
      service.setInternalPackages([pkg('app', '1.0.0', 'h1')]);
      await service.applyReady([pkg('app', '1.0.0', 'h1')]);
      // 线上有更新版 v3，但 staged 是内置 v1 → 豁免校验，正常生效。
      service.setRemotePackages([pkg('app', '3.0.0', 'h3')]);

      final result = await service.promoteStaged('app');
      expect(result!.version, '1.0.0');
      expect(service.getActivePackage('app')!.version, '1.0.0');
    });

    test('reuseLocalAsStaged returns null when not in retained', () async {
      await service.init();
      final remote = pkg('app', '1.0.0', 'h1');
      expect(await service.reuseLocalAsStaged(remote), isNull);
    });

    test('init drops packages whose files are missing', () async {
      final bad = pkg('app', '1.0.0', 'h1').copyWith(state: PackageState.active);
      repo.seedRegistry(PackageRegistry(active: [bad]));
      repo.setValidity(bad, false);

      await service.init();
      expect(service.activePackages, isEmpty);
    });

    test('isInternal matches by version+hash', () async {
      service.setInternalPackages([pkg('app', '1.0.0', 'h1')]);
      expect(service.isInternal(pkg('app', '1.0.0', 'h1')), true);
      expect(service.isInternal(pkg('app', '2.0.0', 'h2')), false);
    });
  });
}
