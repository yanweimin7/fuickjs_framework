import '../offline.dart';

logger(String Function() msg, {String tag = 'offline'}) {
  if (Offline.config.debug) {
    Offline.config.logger(tag, msg());
  }
}
