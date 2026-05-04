import '../logger.dart';
import '../utils/extensions.dart';
import 'base_fuick_service.dart';

class NavigationService extends BaseFuickService {
  @override
  String get name => 'Navigator';

  NavigationService() {
    registerAsyncMethod('push', (args) async {
      final m =
          args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
      final path = (m['path'] ?? '') as String;
      final params = Map<String, dynamic>.from(m['params'] ?? {});
      final pageId = asIntOrNull(m['pageId']);
      final rootNavigator = m['rootNavigator'] == true;
      final prewarmMs = asIntOrNull(m['prewarmMs']);

      if (path.isNotEmpty) {
        if (prewarmMs != null && prewarmMs > 0) {
          controller?.page.prewarmPage(path, params);
          final entry = controller?.page.getPrewarmEntry(path);
          if (entry != null && !entry.hasDsl) {
            final sw = Stopwatch()..start();
            bool timedOut = false;
            await entry.future.timeout(
              Duration(milliseconds: prewarmMs),
              onTimeout: () { timedOut = true; return {}; },
            );
            if (timedOut) {
              logger.w('[Prewarm] $path exceeded ${prewarmMs}ms (${sw.elapsedMilliseconds}ms)');
            } else {
              logger.d('[Prewarm] $path ready in ${sw.elapsedMilliseconds}ms');
            }
          }
        }

        final result = await controller?.pushWithPath(
            path, params,
            pageId: pageId, rootNavigator: rootNavigator);
        return result;
      }
      return null;
    });

    // prewarm：预热目标页面，最多等待 prewarmMs 毫秒后返回
    // JS 侧先 await prewarm，再调 push，确保 DSL 在动画开始前就绪
    registerAsyncMethod('prewarm', (args) async {
      final m = args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
      final path = (m['path'] ?? '') as String;
      final params = Map<String, dynamic>.from(m['params'] ?? {});
      final prewarmMs = asIntOrNull(m['prewarmMs']) ?? 20;

      if (path.isEmpty) return null;

      controller?.page.prewarmPage(path, params);
      final entry = controller?.page.getPrewarmEntry(path);
      if (entry != null && !entry.hasDsl) {
        final sw = Stopwatch()..start();
        bool timedOut = false;
        await entry.future.timeout(
          Duration(milliseconds: prewarmMs),
          onTimeout: () { timedOut = true; return {}; },
        );
        if (timedOut) {
          logger.w('[Prewarm] $path exceeded ${prewarmMs}ms (${sw.elapsedMilliseconds}ms)');
        } else {
          logger.d('[Prewarm] $path ready in ${sw.elapsedMilliseconds}ms');
        }
      }
      return null;
    });

    // cancelPrewarm：取消预热，清理缓存，避免 tap cancel 后残留 DSL
    registerMethod('cancelPrewarm', (args) {
      final m = args is Map ? args : {};
      final path = m['path']?.toString() ?? '';
      if (path.isNotEmpty) {
        controller?.page.cancelPrewarm(path);
        logger.d('[Prewarm] cancelled for $path');
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
