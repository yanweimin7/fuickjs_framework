import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/offline/config/offline_config.dart';
import 'package:fuickjs_flutter/offline/domain/entities/package.dart';
import 'package:fuickjs_flutter/offline/domain/repositories/package_repository.dart';
import 'package:fuickjs_flutter/offline/domain/services/bundle_verifier.dart';
import 'package:fuickjs_flutter/offline/domain/services/download_service.dart';
import 'package:fuickjs_flutter/offline/domain/value_objects/package_registry.dart';
import 'package:path/path.dart' as p;

/// 根目录锚定到 tmp 的 repository：让 preparePackage 的下载/解压/落盘全走
/// 真实文件系统，而不是固定写 /tmp/fuick-test（避免测试间污染）。
class _TmpRepo extends MockPackageRepository {
  final String root;
  _TmpRepo(this.root);

  @override
  String getPackageDir(Package package) =>
      '$root/packages/${package.name}/${package.versionShasumName}';

  @override
  String getStagingDir(Package package) =>
      '$root/staging/${package.name}/${package.versionShasumName}';

  @override
  String getDownloadDir() => '$root/download';

  @override
  String getPackageFlagFile(Package package) =>
      '${getPackageDir(package)}/.offline_valid.flag';

  @override
  String get packagesRootDir => '$root/packages';

  @override
  String get offlineRootDir => '$root/offline';
}

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

class _CountingRepository extends MockPackageRepository {
  _CountingRepository({required this.onValidate});
  final void Function() onValidate;

  @override
  Future<bool> validatePackage(Package package) async {
    onValidate();
    return super.validatePackage(package);
  }
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

    test('concurrent preparePackage for same package is deduplicated', () async {
      var validateCalls = 0;
      final countingRepo =
          _CountingRepository(onValidate: () => validateCalls++);
      final svc = DownloadService(
        countingRepo,
        config: testConfig(),
        verifier:
            BundleVerifier(publicKeysB64: const {'test-key': _pubKeyB64}),
      );
      svc.setInternalChecker((p) => false);

      final pkgA = pkg('test', '1.0.0', 'aaa');
      final pkgB = pkg('test', '1.0.0', 'aaa');
      final results = await Future.wait([
        svc.preparePackage(pkgA),
        svc.preparePackage(pkgB),
      ]);
      expect(results[0], isNull);
      expect(results[1], isNull);
      // 第二个并发调用 join 了 in-flight，不应重复跑完整流程。
      expect(validateCalls, 1);
    });

    test('throws when enableSignatureVerify=true but keys empty', () {
      // enableSignatureVerify 开启却未配公钥 → fail-fast，避免验签必失败
      // 导致正常包被误判为篡改删除。
      expect(
        () => DownloadService(
          repository,
          config: OfflineConfig(
            envGetter: () => 'test',
            offlinePackagesGetter: () async => null,
            offlineConfigGetter: () async => null,
            logger: (_, __) {},
            debug: false,
            appVersionGetter: () => '99.0.0',
            // 未配公钥（默认空），但 enableSignatureVerify 默认 true。
          ),
          verifier: BundleVerifier(
            publicKeysB64: const {},
            allowEmptyKeys: true,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('DownloadService.enableSignatureVerify', () {
    // 真实文件系统 + 真实 fixture + 本地 HTTP server：验证开关关闭后跳过
    // 代码层验签，但仍保留整包 zip SHA-256。
    late Directory tmp;
    late String fixtureZip;
    late String zipSha256;
    late HttpServer server;
    late String baseUrl;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('fuick-dl-sig-');
      // 拷贝 fixture 到 tmp，避免 preparePackage 校验后删除影响其他测试。
      fixtureZip = p.join(tmp.path, 'test_bundle-1.0.0.zip');
      final src = File('test/offline/fixtures/test_bundle-1.0.0.zip');
      await src.copy(fixtureZip);
      zipSha256 =
          sha256.convert(await File(fixtureZip).readAsBytes()).toString();

      // 起本地 HTTP server 提供 fixture 下载（Dio 不支持 file:// 协议）。
      server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((req) async {
        final bytes = await File(fixtureZip).readAsBytes();
        req.response
          ..statusCode = HttpStatus.ok
          ..contentLength = bytes.length
          ..add(bytes);
        await req.response.close();
      });
      baseUrl = 'http://127.0.0.1:${server.port}/bundle.zip';
    });

    tearDown(() async {
      await server.close(force: true);
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    Package forced(String sha256) => Package(
          name: 'test',
          version: '1.0.0',
          sha256: sha256,
          url: baseUrl,
        );

    DownloadService makeService({required bool enabled}) {
      final svc = DownloadService(
        _TmpRepo(tmp.path),
        config: OfflineConfig(
          envGetter: () => 'test',
          offlinePackagesGetter: () async => null,
          offlineConfigGetter: () async => null,
          logger: (_, __) {},
          debug: false,
          appVersionGetter: () => '99.0.0',
          signaturePublicKeysB64:
              enabled ? const {'key-test': _pubKeyB64} : const {},
          enableSignatureVerify: enabled,
        ),
        verifier: BundleVerifier(
          publicKeysB64:
              enabled ? const {'key-test': _pubKeyB64} : const {},
          allowEmptyKeys: !enabled,
        ),
        enableSignatureVerify: enabled,
      );
      svc.setInternalChecker((p) => false);
      return svc;
    }

    test('disabled: skips code-layer verify, succeeds even with empty keys',
        () async {
      final svc = makeService(enabled: false);
      // fixture 带合法 sig，但开关关闭 → 不验签，仍校验 zip sha256 通过。
      final result = await svc.preparePackage(forced(zipSha256));
      expect(result, isNotNull);
      expect(result!.state, PackageState.staged);
    });

    test('enabled: same zip with wrong key fails code-layer verify', () async {
      // 用正确 sha256 但配置了错误 keyId（manifest.keyId=key-test，这里注册为
      // other-key）→ _selectPublicKey('key-test') 返回 null → 验签失败。
      final svc = DownloadService(
        _TmpRepo(tmp.path),
        config: OfflineConfig(
          envGetter: () => 'test',
          offlinePackagesGetter: () async => null,
          offlineConfigGetter: () async => null,
          logger: (_, __) {},
          debug: false,
          appVersionGetter: () => '99.0.0',
          signaturePublicKeysB64: const {'other-key': _pubKeyB64},
        ),
        verifier:
            BundleVerifier(publicKeysB64: const {'other-key': _pubKeyB64}),
      );
      svc.setInternalChecker((p) => false);
      final result = await svc.preparePackage(forced(zipSha256));
      expect(result, isNull);
    });

    test('disabled: zip sha256 mismatch is still rejected', () async {
      final svc = makeService(enabled: false);
      final result = await svc.preparePackage(forced('deadbeef'));
      expect(result, isNull);
    });

    test('onDownloadProgress emits throttled progress and terminal 1.0',
        () async {
      final events = <(String, double)>[];
      final svc = DownloadService(
        _TmpRepo(tmp.path),
        config: OfflineConfig(
          envGetter: () => 'test',
          offlinePackagesGetter: () async => null,
          offlineConfigGetter: () async => null,
          logger: (_, __) {},
          debug: false,
          appVersionGetter: () => '99.0.0',
          signaturePublicKeysB64: const {'key-test': _pubKeyB64},
          onDownloadProgress: (name, progress) =>
              events.add((name, progress)),
        ),
        verifier: BundleVerifier(publicKeysB64: const {'key-test': _pubKeyB64}),
      );
      svc.setInternalChecker((p) => false);

      final result = await svc.preparePackage(forced(zipSha256));
      expect(result, isNotNull);

      // 至少有一次进度事件，且都以 name 为 key。
      expect(events, isNotEmpty);
      expect(events.every((e) => e.$1 == 'test'), true);
      // 终止态必须透出 1.0（下载成功）。
      expect(events.last.$2, 1.0);
      // 进度单调不降（节流后）。
      for (var i = 1; i < events.length; i++) {
        expect(events[i].$2 >= events[i - 1].$2, true,
            reason: 'progress should be monotonic: ${events[i]}');
      }
      // pull 查询也应返回终态 1.0。
      expect(svc.getProgressByName('test'), 1.0);
    });
  });
}
