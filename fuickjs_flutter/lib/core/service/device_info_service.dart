import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';

import '../logger.dart';
import 'base_fuick_service.dart';

class DeviceInfoService extends BaseFuickService {
  @override
  String get name => 'DeviceInfo';

  StreamSubscription? _connectivitySub;

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

    // makePhoneCall: 拨打电话
    registerAsyncMethod('makePhoneCall', (args) async {
      final m = args is Map ? args : {};
      final phoneNumber = m['phoneNumber']?.toString() ?? '';
      if (phoneNumber.isEmpty) {
        return {'success': false, 'error': 'phoneNumber is required'};
      }
      try {
        final uri = Uri(scheme: 'tel', path: phoneNumber);
        final ok = await launchUrl(uri);
        return {'success': ok};
      } catch (e) {
        return {'success': false, 'error': e.toString()};
      }
    });

    // vibrate: 触发设备震动
    registerAsyncMethod('vibrate', (args) async {
      final m = args is Map ? args : {};
      final String type = m['type']?.toString() ?? 'medium';
      try {
        final hasVibrator = await Vibration.hasVibrator() ?? false;
        if (!hasVibrator) return {'success': false, 'error': 'no vibrator'};

        switch (type) {
          case 'heavy':
            await Vibration.vibrate(duration: 400, amplitude: 255);
            break;
          case 'medium':
            await Vibration.vibrate(duration: 200, amplitude: 128);
            break;
          case 'light':
            await Vibration.vibrate(duration: 50, amplitude: 64);
            break;
          default:
            await Vibration.vibrate(duration: 200);
        }
        return {'success': true};
      } catch (e) {
        return {'success': false, 'error': e.toString()};
      }
    });

    // getNetworkType: 获取当前网络类型
    registerAsyncMethod('getNetworkType', (args) async {
      try {
        final results = await Connectivity().checkConnectivity();
        final type = results.isNotEmpty ? results.first : ConnectivityResult.none;
        return {'networkType': _connectivityToType(type)};
      } catch (e) {
        return {'networkType': 'unknown'};
      }
    });

    // onNetworkStatusChange: 开始监听网络状态变化
    registerMethod('startNetworkListener', (args) {
      _connectivitySub?.cancel();
      _connectivitySub =
          Connectivity().onConnectivityChanged.listen((results) {
        final type = results.isNotEmpty ? results.first : ConnectivityResult.none;
        final networkType = _connectivityToType(type);
        final isConnected = type != ConnectivityResult.none;
        try {
          ctx.invoke('NativeEvent', 'receive',
              ['networkStatusChange', {'networkType': networkType, 'isConnected': isConnected}]);
        } catch (e) {
          logger.e('[DeviceInfoService] Error notifying network change: $e');
        }
      });
      return true;
    });

    registerMethod('stopNetworkListener', (args) {
      _connectivitySub?.cancel();
      _connectivitySub = null;
      return true;
    });
  }

  static String _connectivityToType(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'wifi';
      case ConnectivityResult.mobile:
        return '4g';
      case ConnectivityResult.ethernet:
        return 'ethernet';
      case ConnectivityResult.none:
        return 'none';
      default:
        return 'unknown';
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
