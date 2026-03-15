import '../offline.dart';

void logger(String Function() msg, {String tag = 'offline'}) {
  try {
    if (Offline.config.debug) {
      final message = msg();
      _callLogger(Offline.config.logger, tag, message);
    }
  } catch (_) {}
}

void _callLogger(void Function(String, String?) fn, String tag, String message) {
  fn(tag, message);
}
