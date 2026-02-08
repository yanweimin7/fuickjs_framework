import 'package:flutter/services.dart';
import 'BaseFuickService.dart';

class ClipboardService extends BaseFuickService {
  @override
  String get name => 'Clipboard';

  ClipboardService() {
    registerAsyncMethod('setData', (args) async {
      final text = args is String ? args : (args['text'] as String?);
      if (text != null) {
        await Clipboard.setData(ClipboardData(text: text));
      }
      return null;
    });

    registerAsyncMethod('getData', (args) async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    });
  }
}
