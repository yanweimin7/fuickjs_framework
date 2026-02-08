import '../fuick_config.dart';
import '../utils/extensions.dart';
import 'BaseFuickService.dart';

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
      final rootNavigator = m['rootNavigator'] == true;

      if (rootNavigator && path.isNotEmpty) {
        // TODO: Support result for root navigator if needed
        final result = await FuickConfig.onRootPush
            ?.call(path, Map<String, dynamic>.from(params));
        return result;
      }

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
      // final rootNavigator = m['rootNavigator'] == true;

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
      final rootNavigator = m['rootNavigator'] == true;
      final result = m['result'];

      if (rootNavigator) {
        if (result != null && FuickConfig.onRootPopWithResult != null) {
          FuickConfig.onRootPopWithResult?.call(result);
        } else {
          FuickConfig.onRootPop?.call();
        }
        return true;
      }

      controller?.pop(pageId: pageId, result: result);
      return true;
    });
  }
}
