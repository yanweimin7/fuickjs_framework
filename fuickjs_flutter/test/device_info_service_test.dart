import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/core/logger.dart';
import 'package:fuickjs_flutter/core/service/device_info_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DeviceInfoService returns valid structure', () async {
    final service = DeviceInfoService();
    final getDeviceInfo = service.asyncMethods['getDeviceInfo']!;

    // In test environment, views might be empty or default.
    // We should check if it throws or returns default.

    // We might need to setup window.
    // But let's see if it works out of the box with TestWidgetsFlutterBinding.

    try {
      final result = await getDeviceInfo([]) as Map;

      expect(result.containsKey('os'), true);
      expect(result.containsKey('osVersion'), true);
      expect(result.containsKey('locale'), true);
      // Screen size might be 0 or default in test environment
      expect(result.containsKey('screenWidth'), true);
      expect(result.containsKey('screenHeight'), true);
      expect(result.containsKey('pixelRatio'), true);
    } catch (e) {
      // If no views available, it might throw.
      // But usually tests run with a test window.
      logger.e('Error: $e');
      rethrow;
    }
  });
}
