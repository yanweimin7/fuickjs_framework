import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/offline/domain/entities/package.dart';

void main() {
  group('Package', () {
    test('should create package with required fields', () {
      const pkg = Package(
        name: 'test-package',
        version: '1.0.0',
        shasum: 'abc123',
      );

      expect(pkg.name, 'test-package');
      expect(pkg.version, '1.0.0');
      expect(pkg.shasum, 'abc123');
      expect(pkg.url, isNull);
      expect(pkg.mustBeUpdated, false);
      expect(pkg.timestamp, isNull);
    });

    test('should create package with all fields', () {
      const pkg = Package(
        name: 'test-package',
        version: '1.0.0',
        shasum: 'abc123',
        url: 'https://example.com/package.zip',
        mustBeUpdated: true,
        timestamp: 1234567890,
      );

      expect(pkg.url, 'https://example.com/package.zip');
      expect(pkg.mustBeUpdated, true);
      expect(pkg.timestamp, 1234567890);
    });

    test('versionShasumName should return name-version-shasum', () {
      const pkg = Package(
        name: 'test-package',
        version: '1.0.0',
        shasum: 'abc123',
      );

      expect(pkg.versionShasumName, 'test-package-1.0.0-abc123');
    });

    test('isSameVersion should return true for same version', () {
      const pkg1 = Package(
        name: 'test-package',
        version: '1.0.0',
        shasum: 'abc123',
      );

      const pkg2 = Package(
        name: 'test-package',
        version: '1.0.0',
        shasum: 'abc123',
      );

      expect(pkg1.isSameVersion(pkg2), true);
    });

    test('isSameVersion should return false for different version', () {
      const pkg1 = Package(
        name: 'test-package',
        version: '1.0.0',
        shasum: 'abc123',
      );

      const pkg2 = Package(
        name: 'test-package',
        version: '2.0.0',
        shasum: 'def456',
      );

      expect(pkg1.isSameVersion(pkg2), false);
    });

    test('isSameVersion should return false for different name', () {
      const pkg1 = Package(
        name: 'package-a',
        version: '1.0.0',
        shasum: 'abc123',
      );

      const pkg2 = Package(
        name: 'package-b',
        version: '1.0.0',
        shasum: 'abc123',
      );

      expect(pkg1.isSameVersion(pkg2), false);
    });

    group('fromJson', () {
      test('should create package from JSON', () {
        final json = {
          'name': 'test-package',
          'version': '1.0.0',
          'shasum': 'abc123',
          'url': 'https://example.com/package.zip',
          'mustBeUpdated': true,
          'timeStamp': 1234567890,
        };

        final pkg = Package.fromJson(json);

        expect(pkg.name, 'test-package');
        expect(pkg.version, '1.0.0');
        expect(pkg.shasum, 'abc123');
        expect(pkg.url, 'https://example.com/package.zip');
        expect(pkg.mustBeUpdated, true);
        expect(pkg.timestamp, 1234567890);
      });

      test('should throw when required fields missing', () {
        expect(() => Package.fromJson(<String, dynamic>{}), throwsArgumentError);
      });

      test('integrity prefers sha256 over shasum', () {
        final pkg = Package.fromJson({
          'name': 'p',
          'version': '1.0.0',
          'sha256': 'deadbeef',
          'shasum': 'legacy',
        });
        expect(pkg.integrity, 'deadbeef');
        expect(pkg.versionShasumName, 'p-1.0.0-deadbeef');
      });
    });

    group('toJson', () {
      test('should convert package to JSON', () {
        const pkg = Package(
          name: 'test-package',
          version: '1.0.0',
          shasum: 'abc123',
          url: 'https://example.com/package.zip',
          mustBeUpdated: true,
          timestamp: 1234567890,
        );

        final json = pkg.toJson();

        expect(json['name'], 'test-package');
        expect(json['version'], '1.0.0');
        expect(json['shasum'], 'abc123');
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
          shasum: 'abc123',
        );

        final copied = original.copyWith(
          version: '2.0.0',
          url: 'https://example.com/new.zip',
        );

        expect(copied.name, 'test-package');
        expect(copied.version, '2.0.0');
        expect(copied.shasum, 'abc123');
        expect(copied.url, 'https://example.com/new.zip');
      });
    });

    group('equality', () {
      test('should be equal for same name, version, shasum', () {
        const pkg1 = Package(
          name: 'test-package',
          version: '1.0.0',
          shasum: 'abc123',
        );

        const pkg2 = Package(
          name: 'test-package',
          version: '1.0.0',
          shasum: 'abc123',
        );

        expect(pkg1, equals(pkg2));
        expect(pkg1.hashCode, equals(pkg2.hashCode));
      });

      test('should not be equal for different fields', () {
        const pkg1 = Package(
          name: 'test-package',
          version: '1.0.0',
          shasum: 'abc123',
        );

        const pkg2 = Package(
          name: 'test-package',
          version: '2.0.0',
          shasum: 'abc123',
        );

        expect(pkg1, isNot(equals(pkg2)));
      });
    });
  });
}
