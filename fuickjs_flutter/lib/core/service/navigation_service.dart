import '../utils/extensions.dart';
import 'base_fuick_service.dart';

class NavigationService extends BaseFuickService {
  @override
  String get name => 'Navigator';

  NavigationService() {
    registerMethod('push', (args) async {
      final m =
          args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
      final path = (m['path'] ?? '') as String;
      final params = m['params'] ?? {};
      final pageId = asIntOrNull(m['pageId']);
      if (path.isNotEmpty) {
        final result = await controller?.pushWithPath(
            path, Map<String, dynamic>.from(params),
            pageId: pageId);
        return result;
      }
      return null;
    });

    registerMethod('pushReplace', (args) async {
      final m =
          args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
      final path = (m['path'] ?? '') as String;
      final params = m['params'] ?? {};
      final pageId = asIntOrNull(m['pageId']);

      if (path.isNotEmpty) {
        final result = await controller?.pushReplacementWithPath(
            path, Map<String, dynamic>.from(params),
            pageId: pageId);
        return result;
      }
      return null;
    });

    registerMethod('pop', (args) {
      final m = args is Map ? args : {};
      final pageId = asIntOrNull(m['pageId']);
      final result = m['result'];
      controller?.pop(pageId: pageId, result: result);
      return true;
    });
  }
}
