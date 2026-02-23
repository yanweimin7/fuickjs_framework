import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'base_fuick_service.dart';

class DeviceInfoService extends BaseFuickService {
  @override
  String get name => 'DeviceInfo';

  DeviceInfoService() {
    registerAsyncMethod('getDeviceInfo', (args) async {
      final window = WidgetsBinding.instance.platformDispatcher.views.first;
      final size = window.physicalSize / window.devicePixelRatio;

      return {
        'os': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'locale': Platform.localeName,
        'screenWidth': size.width,
        'screenHeight': size.height,
        'pixelRatio': window.devicePixelRatio,
        'isAndroid': Platform.isAndroid,
        'isIOS': Platform.isIOS,
        'isMacOS': Platform.isMacOS,
        'isWindows': Platform.isWindows,
        'isLinux': Platform.isLinux,
        'isFuchsia': Platform.isFuchsia,
      };
    });
  }
}
