import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/offline/domain/entities/package.dart';
import 'package:fuickjs_flutter/offline/domain/repositories/package_repository.dart';
import 'package:fuickjs_flutter/offline/domain/services/bundle_verifier.dart';
import 'package:fuickjs_flutter/offline/domain/services/bundle_verify_isolate.dart';
import 'package:fuickjs_flutter/offline/domain/services/package_service.dart';
import 'package:fuickjs_flutter/offline/domain/value_objects/package_registry.dart';

class MockPackageRepository implements PackageRepository {
  PackageRegistry _registry = const PackageRegistry();
  final Map<String, bool> _validityMap = {};
  final List<String> deleted = [];

  /// 可由测试覆盖：返回指定包的实际目录路径（用于 P0-3 验签测试）。
  /// 默认实现：保持原有 /packages/<name>/<versionShasumName> 形式。
  String Function(Package)? getPackageDirOverride;

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
  String getPackageDir(Package package) {
    final override = getPackageDirOverride;
    if (override != null) return override(package);
    return '/packages/${package.name}/${package.versionShasumName}';
  }

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
        active: [
          pkg('app', '1.0.0', 'h1').copyWith(state: PackageState.active)
        ],
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
        active: [
          pkg('app', '2.0.0', 'h2').copyWith(state: PackageState.active)
        ],
        history: [
          pkg('app', '1.0.0', 'h1').copyWith(state: PackageState.history),
        ],
      ));
      repo.setValidity(pkg('app', '1.0.0', 'h1'), true);
      await service.init();

      final remote =
          pkg('app', '1.0.0', 'h1', url: 'https://cdn/app-1.0.0.zip');
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
        active: [
          pkg('app', '1.0.0', 'h1').copyWith(state: PackageState.active)
        ],
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
      final bad =
          pkg('app', '1.0.0', 'h1').copyWith(state: PackageState.active);
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

  group('P0-3 parallel re-verification', () {
    // 任何非空 32 字节 Ed25519 公钥（用于让 BundleVerifier 通过构造检查）。
    // P0-3 实际验签由真实 manifest.sig 决定 —— 本测试不依赖此 key 真的能验签，
    // 而是通过篡改 / 不篡改 bundle 目录来观察 verifier 的行为。
    const fakePubB64 = 'BpbpV8DqQE0NGgiXalTMOpBApQaDObu8byjy7Pftrps=';
    const fakeKeyId = 'test-key';

    late Directory tmp;
    late MockPackageRepository repo;
    late PackageService service;
    late BundleVerifyIsolate verifyIsolate;
    final Map<String, String> _dirByKey = {};

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('fuick-p03-');
      verifyIsolate = await BundleVerifyIsolate.create({fakeKeyId: fakePubB64});
      repo = MockPackageRepository();
      // 让 verifier 拿到真实 temp 目录路径做验签。
      repo.getPackageDirOverride =
          (p) => _dirByKey[p.versionShasumName] ?? p.versionShasumName;
      service =
          PackageService(repo, retainVersions: 2, verifyIsolate: verifyIsolate);
    });

    tearDown(() async {
      await verifyIsolate.dispose();
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    /// 在 tmp/<dirName> 下放一个 bundle 目录 + 在 _dirByKey 注册。
    /// [tamperManifest] = true 时改坏 manifest.json。
    Future<String> makeBundleDir(String dirName,
        {bool tamperManifest = false}) async {
      final dir = '${tmp.path}/$dirName';
      await Directory(dir).create(recursive: true);
      final manifest = {
        'name': dirName,
        'version': '1.0.0',
        'sha256': 'fake-hash',
        'files': <Map<String, dynamic>>[],
      };
      await File('$dir/manifest.json').writeAsString(manifest.toString());
      if (tamperManifest) {
        await File('$dir/manifest.json').writeAsString('{}');
      }
      _dirByKey[dirName] = dir;
      return dir;
    }

    Package mkPkg(String name, String version, String hash) => Package(
          name: name,
          version: version,
          sha256: hash,
          state: PackageState.active,
        );

    test('5 bundles processed in parallel, all failed sig → all dropped',
        () async {
      // 真实场景：合法 bundle 会有合法 Ed25519 sig；这里只测并发执行正确性。
      // 用"全坏"目录触发 deletePackage 路径：verifyDir 返回 ok=false → 全 drop。
      // 验证点：5 个都被处理 + 不会 hang + deletePackage 被调用 5 次。
      final pkgList = [
        mkPkg('a', '1.0.0', 'h1'),
        mkPkg('b', '1.0.0', 'h2'),
        mkPkg('c', '1.0.0', 'h3'),
        mkPkg('d', '1.0.0', 'h4'),
        mkPkg('e', '1.0.0', 'h5'),
      ];
      for (final p in pkgList) {
        await makeBundleDir(p.versionShasumName);
      }
      repo.seedRegistry(PackageRegistry(active: pkgList));

      await service.init();
      // 关键：后台验签是 fire-and-forget，测试需 await backgroundVerifyDone。
      await service.backgroundVerifyDone;

      expect(service.activePackages, isEmpty);
      expect(repo.deleted.length, 5);
      expect(repo.deleted.toSet(),
          pkgList.map((p) => p.versionShasumName).toSet());
    });

    test('parallel: 8 bundles complete without hang', () async {
      // 软性断言：4 并发下 8 个 bundle 总耗时 < 5s。
      // 真实串行 ~ 8 * verifyDir_cost，并发后 ~ 2 * verifyDir_cost。
      final pkgList = List.generate(
        8,
        (i) => mkPkg('p$i', '1.0.0', 'h$i'),
      );
      for (final p in pkgList) {
        await makeBundleDir(p.versionShasumName);
      }
      repo.seedRegistry(PackageRegistry(active: pkgList));

      final sw = Stopwatch()..start();
      await service.init();
      // init 自身必须快速返回（不再等验签）。< 500ms 即可（主要是文件系统 setup）。
      final initTime = sw.elapsedMilliseconds;
      expect(initTime, lessThan(500),
          reason: 'init() should not block on background verify');

      // 后台验签也必须最终完成（不会 hang）。
      await service.backgroundVerifyDone;
      sw.stop();

      expect(repo.deleted.length, 8);
      expect(sw.elapsedMilliseconds, lessThan(5000),
          reason: 'parallel verify should not regress vs serial');
    });

    test('empty input is a no-op', () async {
      repo.seedRegistry(const PackageRegistry());
      await service.init();
      await service.backgroundVerifyDone; // 应立即完成
      expect(service.activePackages, isEmpty);
      expect(repo.deleted, isEmpty);
    });

    test('init returns fast even with many bundles', () async {
      // 验证 init() 不再被验签阻塞：30 个 bundle 时 init 仍 < 500ms。
      final pkgList = List.generate(30, (i) => mkPkg('p$i', '1.0.0', 'h$i'));
      for (final p in pkgList) {
        await makeBundleDir(p.versionShasumName);
      }
      repo.seedRegistry(PackageRegistry(active: pkgList));

      final sw = Stopwatch()..start();
      await service.init();
      final initMs = sw.elapsedMilliseconds;
      expect(initMs, lessThan(500),
          reason: 'init() with 30 bundles must not block on verify');

      // 后台验签最终完成。
      await service.backgroundVerifyDone;
      expect(repo.deleted.length, 30);
    });

    test('regression: no ConcurrentModificationError when all 4 bundles fail',
        () async {
      // 历史 bug：_reverifyOrDrop 用共享 list 收集结果，isolate 响应极快时
      // Future.wait 等待期间 continuation 仍在写 list，for-loop 触发
      // ListIterator "Concurrent modification" 错。修复后用 _VerifyOutcome
      // 值传递 + await 收齐后才合并到 list。
      final pkgList = [
        mkPkg('a', '1.0.0', 'h1'),
        mkPkg('b', '1.0.0', 'h2'),
        mkPkg('c', '1.0.0', 'h3'),
        mkPkg('d', '1.0.0', 'h4'),
      ];
      for (final p in pkgList) {
        await makeBundleDir(p.versionShasumName);
      }
      repo.seedRegistry(PackageRegistry(active: pkgList));

      // 之前会抛 StateError("Concurrent modification")；修复后必须正常完成。
      await service.init();
      await service.backgroundVerifyDone;

      expect(service.activePackages, isEmpty,
          reason: 'all 4 bundles should be dropped after failed verify');
      expect(repo.deleted.toSet(),
          pkgList.map((p) => p.versionShasumName).toSet());
    });

    test('regression: package without sha256 does not crash background verify',
        () async {
      // P0-1 修复前:Package.integrity 在 sha256=null 时抛 StateError,
      // _reverifyOrDrop 内 getPackageDir(pkg) → versionShasumName → integrity
      // 抛异常,Future.wait 整体 reject,_bgVerifyFuture 变 error future,
      // 且 registry 不被清理(问题包一直留在 active)。
      //
      // 修复后:单包 try/catch,失败视为 ok:false,整轮 bg verify 正常完成,
      // 问题包被 drop。其他正常包也不受影响。
      final normalPkg = mkPkg('good', '1.0.0', 'h-good');
      await makeBundleDir(normalPkg.versionShasumName);

      // 故意构造一个无 sha256 的包(模拟攻击者改 registry.json 注入)。
      final badPkg = Package(
        name: 'bad',
        version: '1.0.0',
        sha256: null, // ← 关键:触发 integrity 抛 StateError
        state: PackageState.active,
      );

      repo.seedRegistry(PackageRegistry(active: [normalPkg, badPkg]));

      await service.init();
      // 修复前:这一行会接到 StateError(bg verify 整轮崩溃)。
      // 修复后:正常完成,两个包都被 drop(normal 验签失败,bad 异常容错)。
      await service.backgroundVerifyDone;

      expect(service.activePackages, isEmpty,
          reason: 'bad pkg should be dropped, not crash whole bg verify');
      // bad 包虽然 deletePackage 时也会因 versionShasumName 抛 StateError,
      // 但 _reverifyOrDrop 内 try/catch 兜底,不会让整轮崩。
      // normal 包的目录被正常删(deletePackage 调用 1 次)。
      expect(repo.deleted, contains(normalPkg.versionShasumName));
    });
  });

  group('_withRegistryLock: serializes concurrent registry mutations', () {
    // 历史 bug：_runBackgroundVerify 的 snapshot 写回可以覆盖期间发生的
    // applyReady / promoteStaged / verifyOnOpen 改动。修复后所有改 _registry
    // 的方法都走 _withRegistryLock,严格串行化。
    test('concurrent applyReady during background verify: sync wins', () async {
      const fakePubB64 = 'BpbpV8DqQE0NGgiXalTMOpBApQaDObu8byjy7Pftrps=';
      const fakeKeyId = 'test-key';

      final tmp = await Directory.systemTemp.createTemp('fuick-lock-');
      final verifyIsolate =
          await BundleVerifyIsolate.create({fakeKeyId: fakePubB64});
      final repo = MockPackageRepository();
      // 用合法空目录让 verify 失败（manifest 缺失）,但仍走完 verify 流程
      final dirByKey = <String, String>{};
      repo.getPackageDirOverride = (p) {
        return dirByKey.putIfAbsent(
          p.versionShasumName,
          () => '${tmp.path}/${p.versionShasumName}',
        );
      };
      final svc = PackageService(repo, verifyIsolate: verifyIsolate);

      // 1 个 active bundle(验签会失败,被 bg verify 删掉)
      final initial = Package(
        name: 'a',
        version: '1.0.0',
        sha256: 'h1',
        state: PackageState.active,
      );
      dirByKey[initial.versionShasumName] = '${tmp.path}/a';
      repo.seedRegistry(PackageRegistry(active: [initial]));

      await svc.init();
      // init 内启动了 bg verify (fire-and-forget), 但还没 await 完成

      // 立刻调用 applyReady 添加一个新的 staged bundle —— 应该等 bg verify 完成
      final newStaged = Package(
        name: 'b',
        version: '1.0.0',
        sha256: 'h2',
        state: PackageState.staged,
      );
      dirByKey[newStaged.versionShasumName] = '${tmp.path}/b';
      await svc.applyReady([newStaged]);

      // 等待所有事做完
      await svc.backgroundVerifyDone;

      // 关键断言:新 staged 不被 bg verify 覆盖
      expect(svc.stagedPackages.map((p) => p.name), contains('b'),
          reason: 'applyReady must survive concurrent bg verify');
      // 旧的 a 也被清掉了 (验签失败)
      expect(svc.activePackages, isEmpty);
    });

    test('two concurrent applyReady: both survive (no overwrite)', () async {
      // 锁的关键保证:任何两个 _registry 修改操作严格串行,后到的不会丢前一个的成果。
      // 模拟场景:两个 sync 同时跑,各 applyReady 一个不同 bundle。
      // 不加锁会怎样?看具体实现:两个都通过 _persist() 写文件,最终状态可能是
      // 一个的写被另一个的 in-memory 引用覆盖。本测试验证锁内的实现没有这个问题。
      const fakePubB64 = 'BpbpV8DqQE0NGgiXalTMOpBApQaDObu8byjy7Pftrps=';
      const fakeKeyId = 'test-key';

      final tmp = await Directory.systemTemp.createTemp('fuick-lock-');
      final verifyIsolate =
          await BundleVerifyIsolate.create({fakeKeyId: fakePubB64});
      final repo = MockPackageRepository();
      final dirByKey = <String, String>{};
      repo.getPackageDirOverride = (p) {
        return dirByKey.putIfAbsent(
          p.versionShasumName,
          () => '${tmp.path}/${p.versionShasumName}',
        );
      };
      final svc = PackageService(repo, verifyIsolate: verifyIsolate);

      // 没有 active/staged,只触发 init
      repo.seedRegistry(const PackageRegistry());
      await svc.init();

      // 两个并发的 applyReady
      final a = Package(
        name: 'a',
        version: '1.0.0',
        sha256: 'h1',
        state: PackageState.staged,
      );
      final b = Package(
        name: 'b',
        version: '1.0.0',
        sha256: 'h2',
        state: PackageState.staged,
      );
      await Future.wait([
        svc.applyReady([a]),
        svc.applyReady([b]),
      ]);

      // 锁保证两个都生效
      expect(svc.stagedPackages.map((p) => p.name), containsAll(['a', 'b']));
    });
  });
}
