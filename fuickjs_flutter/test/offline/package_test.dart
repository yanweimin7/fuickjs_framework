import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/offline/domain/entities/package.dart';
import 'package:fuickjs_flutter/offline/domain/value_objects/package_registry.dart';

void main() {
  group('Package', () {
    test('should create package with required fields', () {
      const pkg = Package(
        name: 'test-package',
        version: '1.0.0',
        sha256: 'deadbeef',
      );

      expect(pkg.name, 'test-package');
      expect(pkg.version, '1.0.0');
      expect(pkg.sha256, 'deadbeef');
      expect(pkg.url, isNull);
      expect(pkg.mustBeUpdated, false);
      expect(pkg.timestamp, isNull);
    });

    test('should create package with all fields', () {
      const pkg = Package(
        name: 'test-package',
        version: '1.0.0',
        sha256: 'deadbeef',
        url: 'https://example.com/package.zip',
        mustBeUpdated: true,
        timestamp: 1234567890,
      );

      expect(pkg.url, 'https://example.com/package.zip');
      expect(pkg.mustBeUpdated, true);
      expect(pkg.timestamp, 1234567890);
    });

    test('versionShasumName should return name-version-sha256', () {
      const pkg = Package(
        name: 'test-package',
        version: '1.0.0',
        sha256: 'abc123',
      );

      expect(pkg.versionShasumName, 'test-package-1.0.0-abc123');
    });

    test('isSameVersion should return true for same version', () {
      const pkg1 = Package(
        name: 'test-package',
        version: '1.0.0',
        sha256: 'abc123',
      );

      const pkg2 = Package(
        name: 'test-package',
        version: '1.0.0',
        sha256: 'abc123',
      );

      expect(pkg1.isSameVersion(pkg2), true);
    });

    test('isSameVersion should return false for different version', () {
      const pkg1 = Package(
        name: 'test-package',
        version: '1.0.0',
        sha256: 'abc123',
      );

      const pkg2 = Package(
        name: 'test-package',
        version: '2.0.0',
        sha256: 'def456',
      );

      expect(pkg1.isSameVersion(pkg2), false);
    });

    test('isSameVersion should return false for different name', () {
      const pkg1 = Package(
        name: 'package-a',
        version: '1.0.0',
        sha256: 'abc123',
      );

      const pkg2 = Package(
        name: 'package-b',
        version: '1.0.0',
        sha256: 'abc123',
      );

      expect(pkg1.isSameVersion(pkg2), false);
    });

    group('fromJson', () {
      test('should create package from JSON with sha256', () {
        final json = {
          'name': 'test-package',
          'version': '1.0.0',
          'sha256': 'deadbeef',
          'url': 'https://example.com/package.zip',
          'mustBeUpdated': true,
          'timeStamp': 1234567890,
        };

        final pkg = Package.fromJson(json);

        expect(pkg.name, 'test-package');
        expect(pkg.version, '1.0.0');
        expect(pkg.sha256, 'deadbeef');
        expect(pkg.url, 'https://example.com/package.zip');
        expect(pkg.mustBeUpdated, true);
        expect(pkg.timestamp, 1234567890);
      });

      test('should throw when required fields missing', () {
        expect(() => Package.fromJson(<String, dynamic>{}), throwsArgumentError);
      });

      test('P0-2: fromJson throws when sha256 missing (no MD5 fallback)', () {
        expect(
          () => Package.fromJson({
            'name': 'p',
            'version': '1.0.0',
            'shasum': 'legacy-md5',
          }),
          throwsArgumentError,
        );
      });

      test('P0-2: fromJson throws when sha256 empty', () {
        expect(
          () => Package.fromJson({
            'name': 'p',
            'version': '1.0.0',
            'sha256': '',
          }),
          throwsArgumentError,
        );
      });

      test('tryFromJson returns null on invalid package', () {
        expect(Package.tryFromJson(<String, dynamic>{}), isNull);
        expect(
          Package.tryFromJson({'name': 'p', 'version': '1.0.0'}),
          isNull,
        );
        expect(
          Package.tryFromJson({
            'name': 'p',
            'version': '1.0.0',
            'sha256': 'abc',
          }),
          isNotNull,
        );
      });
    });

    group('toJson', () {
      test('should convert package to JSON', () {
        const pkg = Package(
          name: 'test-package',
          version: '1.0.0',
          sha256: 'abc',
          url: 'https://example.com/package.zip',
          mustBeUpdated: true,
          timestamp: 1234567890,
        );

        final json = pkg.toJson();

        expect(json['name'], 'test-package');
        expect(json['version'], '1.0.0');
        expect(json['sha256'], 'abc');
        expect(json['url'], 'https://example.com/package.zip');
        expect(json['mustBeUpdated'], true);
        expect(json['timeStamp'], 1234567890);
      });
    });

    group('copyWith', () {
      test('should copy with new values', () {
        const original = Package(
          name: 'test-package',
          version: '1.0.0',
          sha256: 'abc',
        );

        final copied = original.copyWith(
          version: '2.0.0',
          url: 'https://example.com/new.zip',
        );

        expect(copied.name, 'test-package');
        expect(copied.version, '2.0.0');
        expect(copied.sha256, 'abc');
        expect(copied.url, 'https://example.com/new.zip');
      });
    });

    group('equality', () {
      test('should be equal for same name, version, sha256', () {
        const pkg1 = Package(
          name: 'test-package',
          version: '1.0.0',
          sha256: 'abc',
        );

        const pkg2 = Package(
          name: 'test-package',
          version: '1.0.0',
          sha256: 'abc',
        );

        expect(pkg1, equals(pkg2));
        expect(pkg1.hashCode, equals(pkg2.hashCode));
      });

      test('should not be equal for different fields', () {
        const pkg1 = Package(
          name: 'test-package',
          version: '1.0.0',
          sha256: 'abc',
        );

        const pkg2 = Package(
          name: 'test-package',
          version: '2.0.0',
          sha256: 'abc',
        );

        expect(pkg1, isNot(equals(pkg2)));
      });
    });
  });

  group('PackageRegistry.fromJson tolerant parsing', () {
    test('skips a bad package (missing sha256), keeps the good ones', () {
      final registry = PackageRegistry.fromJson({
        'active': [
          {'name': 'good', 'version': '1.0.0', 'sha256': 'abc'},
          {'name': 'bad', 'version': '1.0.0', 'shasum': 'legacy-md5'},
        ],
        'staged': <Map<String, dynamic>>[],
        'history': <Map<String, dynamic>>[],
      });

      expect(registry.active.length, 1);
      expect(registry.active.single.name, 'good');
    });

    test('ignores non-map entries', () {
      final registry = PackageRegistry.fromJson({
        'active': [
          'not-a-map',
          {'name': 'good', 'version': '1.0.0', 'sha256': 'abc'},
        ],
        'staged': <Map<String, dynamic>>[],
        'history': <Map<String, dynamic>>[],
      });

      expect(registry.active.length, 1);
      expect(registry.active.single.name, 'good');
    });
  });
}
