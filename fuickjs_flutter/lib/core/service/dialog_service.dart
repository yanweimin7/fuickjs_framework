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
    registerAsyncMethod('showModal', _showModal);
    registerAsyncMethod('showActionSheet', _showActionSheet);
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

  /// showModal: 显示系统风格的 AlertDialog（不需要 DSL）
  Future<bool> _showModal(dynamic args) async {
    final Map params = args is Map ? args : {};
    final String title = params['title']?.toString() ?? '';
    final String content = params['content']?.toString() ?? '';
    final bool showCancel = params['showCancel'] ?? true;
    final String cancelText = params['cancelText']?.toString() ?? '取消';
    final String confirmText = params['confirmText']?.toString() ?? '确定';

    if (controller == null) return false;
    final contexts = controller!.navigation.pageContexts;
    if (contexts.isEmpty) return false;
    final context = contexts.last;
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: title.isNotEmpty ? Text(title) : null,
        content: content.isNotEmpty ? Text(content) : null,
        actions: [
          if (showCancel)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelText),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// showActionSheet: 显示底部动作菜单
  Future<int> _showActionSheet(dynamic args) async {
    final Map params = args is Map ? args : {};
    final List items = params['items'] is List ? params['items'] as List : [];

    if (controller == null) return -1;
    final contexts = controller!.navigation.pageContexts;
    if (contexts.isEmpty) return -1;
    final context = contexts.last;
    if (!context.mounted) return -1;

    final result = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...items.asMap().entries.map((entry) => ListTile(
              title: Text(entry.value.toString()),
              onTap: () => Navigator.of(ctx).pop(entry.key),
            )),
            const Divider(height: 1),
            ListTile(
              title: const Text('取消', textAlign: TextAlign.center),
              onTap: () => Navigator.of(ctx).pop(-1),
            ),
          ],
        ),
      ),
    );
    return result ?? -1;
  }

  bool _dismiss(dynamic args) {
    // Remove stale unmounted contexts first
    _dialogContexts.removeWhere((ctx) => !ctx.mounted);

    if (_dialogContexts.isNotEmpty) {
      final context = _dialogContexts.removeLast();
      Navigator.of(context).pop(args);
      return true;
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
