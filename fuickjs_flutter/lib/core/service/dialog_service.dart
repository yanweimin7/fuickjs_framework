import 'package:flutter/material.dart' hide widgetFactory;

import '../container/fuick_app_controller.dart';
import '../container/fuick_page_view.dart';
import '../logger.dart';
import '../utils/extensions.dart';
import '../widgets/fuick_node.dart';
import '../widgets/widget_factory.dart';
import '../widgets/widget_utils.dart';
import 'base_fuick_service.dart';

class DialogService extends BaseFuickService {
  @override
  String get name => 'Dialog';

  /// Stack to manage multiple nested dialog contexts
  final List<BuildContext> _dialogContexts = [];

  DialogService() {
    registerAsyncMethod('show', _show);
    registerMethod('dismiss', _dismiss);
  }

  Future<dynamic> _show(dynamic args) async {
    final Map params = args is Map ? args : {};
    final Map<String, dynamic>? dsl =
        params['dsl'] != null ? Map<String, dynamic>.from(params['dsl']) : null;
    final int? pageId = asIntOrNull(params['pageId']);
    final bool barrierDismissible = params['barrierDismissible'] ?? true;
    final String? barrierColorHex = params['barrierColor'] as String?;

    if (dsl == null) {
      logger.w('[DialogService] DSL is null');
      return null;
    }

    if (controller == null) {
      logger.w('[DialogService] controller is null');
      return null;
    }

    final contexts = controller!.navigation.pageContexts;
    if (contexts.isEmpty) {
      logger.w('[DialogService] No page contexts available');
      return null;
    }

    final context = contexts.last;
    if (!context.mounted) return null;

    final nodeManager = FuickNodeManager();
    final rootNode = nodeManager.createNode(dsl, nodeManager);

    return await showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: WidgetUtils.colorFromHex(barrierColorHex),
      builder: (dialogContext) {
        // Track this dialog context
        _dialogContexts.add(dialogContext);

        return FuickNodeManagerProvider(
          manager: nodeManager,
          child: FuickAppScope(
            controller: controller!,
            child: FuickPageScope(
              pageId: pageId ?? -1,
              child: Builder(
                builder: (ctx) => widgetFactory.buildFromNode(
                  ctx,
                  rootNode,
                  forceWrap: true,
                ),
              ),
            ),
          ),
        );
      },
    ).then((result) {
      // Cleanup when dialog is closed (via barrier or pop)
      // Note: If dismiss() was called, it might have already been removed or will be here.
      // We use removeWhere to be safe.
      _dialogContexts.removeWhere((ctx) => !ctx.mounted);
      return result;
    });
  }

  bool _dismiss(dynamic args) {
    if (_dialogContexts.isNotEmpty) {
      final context = _dialogContexts.removeLast();
      if (context.mounted) {
        Navigator.of(context).pop(args);
        return true;
      }
    }

    // Fallback: if no tracked dialogs, try to pop from navigation stack
    if (controller != null) {
      final contexts = controller!.navigation.pageContexts;
      if (contexts.isNotEmpty) {
        final context = contexts.last;
        if (context.mounted) {
          Navigator.of(context).pop(args);
          return true;
        }
      }
    }
    return false;
  }
}
