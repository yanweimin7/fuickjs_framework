import 'package:flutter/services.dart';

import 'base_fuick_service.dart';

class SoundService extends BaseFuickService {
  @override
  String get name => 'Sound';

  SoundService() {
    registerMethod('play', _play);
  }

  dynamic _play(dynamic args) {
    final type = args is Map ? (args['type']?.toString() ?? 'move') : 'move';
    switch (type) {
      case 'capture':
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);
        break;
      case 'check':
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.click);
        break;
      case 'win':
        HapticFeedback.heavyImpact();
        break;
      case 'move':
      default:
        HapticFeedback.lightImpact();
        SystemSound.play(SystemSoundType.click);
        break;
    }
    return null;
  }
}
