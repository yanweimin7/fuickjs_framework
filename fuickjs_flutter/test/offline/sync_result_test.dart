import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/offline/domain/entities/package.dart';
import 'package:fuickjs_flutter/offline/domain/value_objects/sync_result.dart';

void main() {
  group('SyncResult', () {
    test('should create with empty lists by default', () {
      const result = SyncResult();

      expect(result.added, isEmpty);
      expect(result.updated, isEmpty);
      expect(result.removed, isEmpty);
    });

    test('should create with provided lists', () {
      const result = SyncResult(
        added: [Package(name: 'pkg1', version: '1.0.0', shasum: 'aaa')],
        updated: [Package(name: 'pkg2', version: '2.0.0', shasum: 'bbb')],
        removed: [Package(name: 'pkg3', version: '3.0.0', shasum: 'ccc')],
      );

      expect(result.added.length, 1);
      expect(result.updated.length, 1);
      expect(result.removed.length, 1);
    });

    group('hasChanges', () {
      test('should return false when all lists are empty', () {
        const result = SyncResult();
        expect(result.hasChanges, false);
      });

      test('should return true when there are added packages', () {
        final result = SyncResult(
          added: [Package(name: 'pkg1', version: '1.0.0', shasum: 'aaa')],
        );
        expect(result.hasChanges, true);
      });

      test('should return true when there are updated packages', () {
        final result = SyncResult(
          updated: [Package(name: 'pkg1', version: '1.0.0', shasum: 'aaa')],
        );
        expect(result.hasChanges, true);
      });

      test('should return true when there are removed packages', () {
        final result = SyncResult(
          removed: [Package(name: 'pkg1', version: '1.0.0', shasum: 'aaa')],
        );
        expect(result.hasChanges, true);
      });
    });

    group('totalChanges', () {
      test('should return 0 when all lists are empty', () {
        const result = SyncResult();
        expect(result.totalChanges, 0);
      });

      test('should return sum of all changes', () {
        final result = SyncResult(
          added: [
            Package(name: 'pkg1', version: '1.0.0', shasum: 'aaa'),
            Package(name: 'pkg2', version: '1.0.0', shasum: 'bbb'),
          ],
          updated: [
            Package(name: 'pkg3', version: '1.0.0', shasum: 'ccc'),
          ],
          removed: [
            Package(name: 'pkg4', version: '1.0.0', shasum: 'ddd'),
            Package(name: 'pkg5', version: '1.0.0', shasum: 'eee'),
            Package(name: 'pkg6', version: '1.0.0', shasum: 'fff'),
          ],
        );

        expect(result.totalChanges, 6);
      });
    });

    group('copyWith', () {
      test('should copy with new added list', () {
        const original = SyncResult(
          added: [Package(name: 'pkg1', version: '1.0.0', shasum: 'aaa')],
        );

        final copied = original.copyWith(
          added: [
            Package(name: 'pkg2', version: '2.0.0', shasum: 'bbb'),
          ],
        );

        expect(copied.added.length, 1);
        expect(copied.added.first.name, 'pkg2');
        expect(copied.updated, isEmpty);
        expect(copied.removed, isEmpty);
      });

      test('should preserve original values when not specified', () {
        const original = SyncResult(
          added: [Package(name: 'pkg1', version: '1.0.0', shasum: 'aaa')],
          updated: [Package(name: 'pkg2', version: '2.0.0', shasum: 'bbb')],
        );

        final copied = original.copyWith(
          removed: [Package(name: 'pkg3', version: '3.0.0', shasum: 'ccc')],
        );

        expect(copied.added.length, 1);
        expect(copied.updated.length, 1);
        expect(copied.removed.length, 1);
      });
    });
  });
}
