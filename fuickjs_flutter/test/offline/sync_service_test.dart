import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/offline/domain/entities/package.dart';
import 'package:fuickjs_flutter/offline/domain/services/sync_service.dart';
import 'package:fuickjs_flutter/offline/domain/value_objects/sync_result.dart';

void main() {
  group('SyncService', () {
    late SyncService syncService;

    setUp(() {
      syncService = SyncService();
    });

    Package pkg(String name, String version, String hash, {String? url}) {
      // P0-2: 必填 sha256，旧 shasum 字段已废弃，测试统一改用 sha256。
      return Package(name: name, version: version, sha256: hash, url: url);
    }

    SyncResult run({
      List<Package> remote = const [],
      List<Package> internal = const [],
      List<Package> active = const [],
      String appVersion = '99.0.0',
    }) {
      return syncService.sync(
        remote: remote,
        internal: internal,
        active: active,
        appVersion: appVersion,
      );
    }

    group('sync', () {
      test('should return empty result when no packages', () {
        final result = run(
          remote: [],
          internal: [],
          active: [],
        );

        expect(result.added, isEmpty);
        expect(result.updated, isEmpty);
        expect(result.removed, isEmpty);
      });

      test('should add new packages not in active', () {
        final result = run(
          remote: [pkg('pkg1', '1.0.0', 'abc123')],
          internal: [],
          active: [],
        );

        expect(result.added.length, 1);
        expect(result.added.first.name, 'pkg1');
        expect(result.updated, isEmpty);
        expect(result.removed, isEmpty);
      });

      test('should not add packages already active with same version', () {
        final result = run(
          remote: [pkg('pkg1', '1.0.0', 'abc123')],
          internal: [],
          active: [pkg('pkg1', '1.0.0', 'abc123')],
        );

        expect(result.added, isEmpty);
        expect(result.updated, isEmpty);
      });

      test('should mark packages with different version as updated', () {
        final result = run(
          remote: [pkg('pkg1', '2.0.0', 'def456')],
          internal: [],
          active: [pkg('pkg1', '1.0.0', 'abc123')],
        );

        expect(result.added, isEmpty);
        expect(result.updated.length, 1);
        expect(result.updated.first.version, '2.0.0');
      });

      test('should remove packages not in remote', () {
        final result = run(
          remote: [],
          internal: [],
          active: [pkg('pkg1', '1.0.0', 'abc123')],
        );

        expect(result.added, isEmpty);
        expect(result.updated, isEmpty);
        expect(result.removed.length, 1);
        expect(result.removed.first.name, 'pkg1');
      });

      test('should handle multiple packages correctly', () {
        final result = run(
          remote: [
            pkg('pkg1', '1.0.0', 'aaa'),
            pkg('pkg2', '2.0.0', 'bbb'),
            pkg('pkg3', '3.0.0', 'ccc'),
          ],
          internal: [],
          active: [
            pkg('pkg1', '1.0.0', 'aaa'),
            pkg('pkg2', '1.0.0', 'bbb'),
            pkg('old', '1.0.0', 'ddd'),
          ],
        );

        expect(result.added.length, 1); // pkg3
        expect(result.updated.length, 1); // pkg2 (1.0.0 -> 2.0.0)
        expect(result.removed.length, 1); // old
      });

      group('internal package priority', () {
        test('should prefer internal package when version and shasum match',
            () {
          final result = run(
            remote: [
              pkg('pkg1', '1.0.0', 'same123',
                  url: 'https://remote.com/pkg1.zip')
            ],
            internal: [
              pkg('pkg1', '1.0.0', 'same123', url: 'assets://internal/pkg1.zip')
            ],
            active: [],
          );

          expect(result.added.length, 1);
          // Internal replaces remote when version AND hash match
          expect(result.added.first.sha256, 'same123');
          // Verify it's the internal package (has internal url)
          expect(result.added.first.url, 'assets://internal/pkg1.zip');
        });

        test('should use remote when internal hash differs', () {
          final result = run(
            remote: [pkg('pkg1', '1.0.0', 'remote123')],
            internal: [pkg('pkg1', '1.0.0', 'internal123')],
            active: [],
          );

          expect(result.added.length, 1);
          // Different hash means use remote
          expect(result.added.first.sha256, 'remote123');
        });

        test('should use remote when internal version differs', () {
          final result = run(
            remote: [pkg('pkg1', '1.0.0', 'remote123')],
            internal: [pkg('pkg1', '2.0.0', 'internal123')],
            active: [],
          );

          expect(result.added.length, 1);
          expect(result.added.first.sha256, 'remote123');
        });

        test('should ignore internal-only packages (remote list is complete)',
            () {
          final result = run(
            remote: [],
            internal: [pkg('pkg1', '1.0.0', 'internal123')],
            active: [],
          );

          expect(result.added, isEmpty);
        });
      });

      group('complex scenarios', () {
        test('should handle mixed remote and internal', () {
          final result = run(
            remote: [
              pkg('pkg1', '1.0.0', 'same1'),
              pkg('pkg2', '2.0.0', 'remote2'),
            ],
            internal: [
              pkg('pkg1', '1.0.0',
                  'same1'), // matches remote (version+hash), should use internal
            ],
            active: [],
          );

          expect(result.added.length, 2);
          // pkg1 should use internal version (same hash, so internal is used)
          final pkg1 = result.added.firstWhere((p) => p.name == 'pkg1');
          expect(pkg1.sha256, 'same1');
          // pkg2 should use remote version
          final pkg2 = result.added.firstWhere((p) => p.name == 'pkg2');
          expect(pkg2.sha256, 'remote2');
        });

        test(
            'should update when internal version available for active remote package',
            () {
          final result = run(
            remote: [pkg('pkg1', '1.0.0', 'same1')],
            internal: [pkg('pkg1', '1.0.0', 'same1')],
            active: [pkg('pkg1', '1.0.0', 'old1')],
          );

          // Same version+hash as remote, so internal is used, different from active
          expect(result.updated.length, 1);
        });
      });
    });

    group('hasChanges', () {
      test('should return false when no changes', () {
        final result = run(
          remote: [pkg('pkg1', '1.0.0', 'abc')],
          internal: [],
          active: [pkg('pkg1', '1.0.0', 'abc')],
        );

        expect(result.hasChanges, false);
      });

      test('should return true when there are added packages', () {
        final result = run(
          remote: [pkg('pkg1', '1.0.0', 'abc')],
          internal: [],
          active: [],
        );

        expect(result.hasChanges, true);
      });

      test('should return true when there are updated packages', () {
        final result = run(
          remote: [pkg('pkg1', '2.0.0', 'def')],
          internal: [],
          active: [pkg('pkg1', '1.0.0', 'abc')],
        );

        expect(result.hasChanges, true);
      });

      test('should return true when there are removed packages', () {
        final result = run(
          remote: [],
          internal: [],
          active: [pkg('pkg1', '1.0.0', 'abc')],
        );

        expect(result.hasChanges, true);
      });
    });

    group('minAppVersion', () {
      test('should skip package when app version is too low', () {
        final p = Package(
          name: 'pkg1',
          version: '1.0.0',
          sha256: 'abc',
          minAppVersion: '5.0.0',
        );
        final result = run(remote: [p], appVersion: '3.0.0');
        expect(result.added, isEmpty);
      });

      test('should add package when app version satisfies minAppVersion', () {
        final p = Package(
          name: 'pkg1',
          version: '1.0.0',
          sha256: 'abc',
          minAppVersion: '3.0.0',
        );
        final result = run(remote: [p], appVersion: '3.0.0');
        expect(result.added.length, 1);
      });
    });
  });
}
