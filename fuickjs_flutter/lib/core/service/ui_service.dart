import '../container/fuick_app_controller.dart';
import '../logger.dart';
import '../utils/extensions.dart';
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
        return widgetFactory.hasWidget(type) ?? false;
      }
      return false;
    });

    registerMethod('getRegisteredWidgets', (args) {
      return widgetFactory.registeredTypes;
    });
  }
}
