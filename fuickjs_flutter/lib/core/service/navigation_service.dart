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
      final rootNavigator = m['rootNavigator'] == true;

      if (path.isNotEmpty) {
        final result = await controller?.pushWithPath(
            path, Map<String, dynamic>.from(params),
            pageId: pageId, rootNavigator: rootNavigator);
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
      final rootNavigator = m['rootNavigator'] == true;

      if (path.isNotEmpty) {
        final result = await controller?.pushReplacementWithPath(
            path, Map<String, dynamic>.from(params),
            pageId: pageId, rootNavigator: rootNavigator);
        return result;
      }
      return null;
    });

    registerMethod('pop', (args) {
      final m = args is Map ? args : {};
      final pageId = asIntOrNull(m['pageId']);
      // final rootNavigator = m['rootNavigator'] == true;
      final result = m['result'];

      controller?.pop(pageId: pageId, result: result);
      return true;
    });

    // reLaunch: 清空路由栈并跳转到指定页面
    registerMethod('reLaunch', (args) async {
      final m =
          args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
      final path = (m['path'] ?? '') as String;
      final params = m['params'] ?? {};

      if (path.isNotEmpty) {
        // 先 pop 所有页面，再 push 新页面
        controller?.popAll();
        final result = await controller?.pushWithPath(
            path, Map<String, dynamic>.from(params));
        return result;
      }
      return null;
    });

    // switchTab: 切换 TabBar 选中项（通过路径）
    registerMethod('switchTab', (args) {
      final m = args is Map ? args : {};
      final path = m['path']?.toString() ?? '';
      // 触发 TabBar 切换事件，由 Flutter 侧 TabBar 组件监听处理
      controller?.switchTab(path);
      return true;
    });
  }
}
