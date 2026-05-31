import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logger.dart';
import 'base_fuick_service.dart';

class DeviceInfoService extends BaseFuickService {
  @override
  String get name => 'DeviceInfo';

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

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

    registerAsyncMethod('makePhoneCall', (args) async {
      final m = args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
      final phoneNumber = m['phoneNumber']?.toString() ?? '';
      if (phoneNumber.isEmpty) return {'success': false};
      try {
        final uri = Uri.parse('tel:$phoneNumber');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return {'success': true};
        }
        return {'success': false};
      } catch (e) {
        logger.w('[DeviceInfo] makePhoneCall failed: $e');
        return {'success': false};
      }
    });

    registerAsyncMethod('vibrate', (args) async {
      final m = args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
      final type = m['type']?.toString() ?? 'medium';
      switch (type) {
        case 'heavy':
          await HapticFeedback.heavyImpact();
          break;
        case 'light':
          await HapticFeedback.lightImpact();
          break;
        case 'medium':
        default:
          await HapticFeedback.mediumImpact();
          break;
      }
      return {'success': true};
    });

    registerAsyncMethod('getNetworkType', (args) async {
      try {
        final results = await Connectivity().checkConnectivity();
        final networkType = _connectivityResultToString(results);
        return {'networkType': networkType};
      } catch (e) {
        logger.w('[DeviceInfo] getNetworkType failed: $e');
        return {'networkType': 'unknown'};
      }
    });

    registerMethod('startNetworkListener', (args) {
      _connectivitySubscription?.cancel();
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
        // 回调可能在 service dispose 后才到达；此时 ctx 已不可用，必须先短路。
        if (isDisposed) return;
        try {
          final networkType = _connectivityResultToString(results);
          ctx.invoke('NativeEvent', 'receive', ['networkChange', {'networkType': networkType}]);
        } catch (e) {
          logger.w('[DeviceInfo] networkListener callback failed: $e');
        }
      });
      return true;
    });

    registerMethod('stopNetworkListener', (args) {
      _connectivitySubscription?.cancel();
      _connectivitySubscription = null;
      return true;
    });
  }

  String _connectivityResultToString(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return 'none';
    }
    if (results.contains(ConnectivityResult.wifi)) {
      return 'wifi';
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return 'cellular';
    }
    if (results.contains(ConnectivityResult.ethernet)) {
      return 'ethernet';
    }
    return 'unknown';
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    super.dispose();
  }
}