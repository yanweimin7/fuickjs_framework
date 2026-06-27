import '../container/fuick_app_controller.dart';
import '../logger.dart';
import '../utils/extensions.dart';
import '../widgets/fuick_media_query_provider.dart';
import '../widgets/fuick_theme_provider.dart';
import 'base_fuick_service.dart';

class UIService extends BaseFuickService {
  @override
  String get name => 'UI';

  UIService() {
    registerMethod('renderUI', (args) {
      final sw = Stopwatch()..start();
      final List listArgs = args is List ? args : [args];
      if (listArgs.length == 1 && listArgs[0] is Map) {
        final m = listArgs[0] as Map;
        final pageId = asIntOrNull(m['pageId']);
        final renderData = asMap(m['renderData']);
        if (pageId != null) {
          controller?.render(pageId, renderData);
          sw.stop();
          logger.i(
              '[Perf] Flutter renderUI page=$pageId dartSide=${sw.elapsedMilliseconds}ms');
          return true;
        }
      }
      return false;
    });

    registerMethod('patchUI', (args) {
      final List listArgs = args is List ? args : [args];
      if (listArgs.length == 1 && listArgs[0] is Map) {
        final m = listArgs[0] as Map;
        final pageId = asIntOrNull(m['pageId']);
        final patches = (m['patches'] as List?) ?? [];
        if (pageId != null) {
          controller?.patch(pageId, patches);
          return true;
        }
      }
      return false;
    });

    registerMethod('patchOps', (args) {
      final sw = Stopwatch()..start();
      final List listArgs = args is List ? args : [args];
      if (listArgs.length == 1 && listArgs[0] is Map) {
        final m = listArgs[0] as Map;
        final pageId = asIntOrNull(m['pageId']);
        final ops = (m['ops'] as List?) ?? [];
        if (pageId != null) {
          controller?.patchOps(pageId, ops);
          sw.stop();
          logger.i(
              '[Perf] Flutter patchOps page=$pageId ops=${ops.length} dartSide=${sw.elapsedMilliseconds}ms');
          return true;
        }
      }
      return false;
    });

    registerMethod('componentCommand', (args) {
      final List listArgs = args is List ? args : [args];
      if (listArgs.length == 1 && listArgs[0] is Map) {
        final m = listArgs[0] as Map;
        final refId = m['refId']?.toString();
        final method = m['method']?.toString();
        final commandArgs = m['args'];

        if (refId != null && method != null) {
          controller?.commandBus.dispatch(refId, method, commandArgs);
          return true;
        }
      }
      return false;
    });

    registerMethod('isWidgetRegistered', (args) {
      final List listArgs = args is List ? args : [args];
      if (listArgs.isNotEmpty && listArgs[0] is String) {
        final type = listArgs[0] as String;
        return widgetFactory.hasWidget(type);
      }
      return false;
    });

    registerMethod('getRegisteredWidgets', (args) {
      return widgetFactory.registeredTypes;
    });

    // 返回当前页面的主题快照（来自 FuickThemeProvider）。
    // JS 端 useTheme() hook 通过此同步调用拿当前主题，并在主题变化时
    // 由 _maybeEmitThemeChange 推送 'themeChange' 事件触发重新渲染。
    registerMethod('getTheme', (args) {
      final pageId = _extractPageId(args);
      final ctx = controller?.navigation.findPageContext(pageId);
      if (ctx == null) return null;
      final data = FuickThemeProvider.of(ctx);
      return data?.toMap();
    });

    // 返回当前页面的 MediaQuery 快照（来自 FuickMediaQueryProvider）。
    registerMethod('getMediaQuery', (args) {
      final pageId = _extractPageId(args);
      final ctx = controller?.navigation.findPageContext(pageId);
      if (ctx == null) return null;
      final data = FuickMediaQueryProvider.of(ctx);
      return data?.toMap();
    });
  }

  int? _extractPageId(dynamic args) {
    if (args is Map) return asIntOrNull(args['pageId']);
    if (args is List && args.isNotEmpty) {
      final first = args.first;
      if (first is int) return first;
      if (first is Map) return asIntOrNull(first['pageId']);
    }
    if (args is int) return args;
    return null;
  }
}
