import 'package:flutter/material.dart' hide widgetFactory;

import '../container/fuick_app_controller.dart';
import '../container/fuick_page_view.dart';
import '../logger.dart';
import '../utils/extensions.dart';
import '../widgets/fuick_node.dart';
import '../widgets/widget_factory.dart';
import 'base_fuick_service.dart';

class OverlayService extends BaseFuickService {
  @override
  String get name => 'Overlay';

  final Map<String, OverlayEntry> _entries = {};

  OverlayService() {
    registerMethod('show', _show);
    registerMethod('hide', _hide);
  }

  bool _show(dynamic args) {
    // 支持两种调用格式：
    // 1. Map args: { key, dsl, pageId } 或 { key, type, message, pageId }
    // 2. List args: [{ key, dsl, pageId }]
    final Map params;
    if (args is Map) {
      params = args;
    } else if (args is List && args.isNotEmpty && args[0] is Map) {
      params = args[0] as Map;
    } else {
      return false;
    }

    final String? key = params['key']?.toString();
    if (key == null) return false;

    final Map<String, dynamic>? dsl =
        params['dsl'] != null ? Map<String, dynamic>.from(params['dsl']) : null;
    final String? type = params['type']?.toString();
    final String message = params['message']?.toString() ?? '';
    final int? pageId = asIntOrNull(params['pageId']);

    // 如果没有 DSL 但有 type，使用内置 loading 样式
    if (dsl == null && type == 'loading') {
      return _showLoadingOverlay(key, message, pageId);
    }
    if (dsl == null) return false;

    if (controller == null) return false;

    // Determine the target navigator/overlay
    // If pageId is provided, try to find that page's context or navigator
    // Otherwise use the top-most navigator
    final navKey = controller!.navigation.getNavigatorKey(pageId);
    final navState = navKey?.currentState;

    if (navState == null) {
      logger.w('[OverlayService] No navigator found for pageId: $pageId');
      return false;
    }

    // Remove existing entry with same key
    _hide([key]);

    // Parse DSL
    final nodeManager = FuickNodeManager();
    final rootNode = nodeManager.createNode(dsl, nodeManager);

    // Create OverlayEntry
    final entry = OverlayEntry(
      builder: (context) {
        // We need to provide the necessary scopes for the Fuick widgets to work
        return FuickNodeManagerProvider(
          manager: nodeManager,
          child: FuickAppScope(
            controller: controller!,
            child: FuickPageScope(
              pageId: pageId ?? -1, // Use -1 or valid pageId
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
    );

    final overlay = navState.overlay;
    if (overlay == null) {
      logger.w('[OverlayService] No overlay found for pageId: $pageId');
      return false;
    }
    overlay.insert(entry);
    _entries[key] = entry;
    return true;
  }

  /// 显示内置 Loading 浮层（无需 DSL）
  bool _showLoadingOverlay(String key, String message, int? pageId) {
    if (controller == null) return false;
    final navKey = controller!.navigation.getNavigatorKey(pageId);
    final navState = navKey?.currentState;
    if (navState == null) return false;

    _hide(key);

    final entry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    final overlay = navState.overlay;
    if (overlay == null) return false;
    overlay.insert(entry);
    _entries[key] = entry;
    return true;
  }

  bool _hide(dynamic args) {
    final String key;
    if (args is String) {
      key = args;
    } else if (args is Map) {
      key = args['key']?.toString() ?? '';
    } else {
      final List listArgs = args is List ? args : [args];
      if (listArgs.isEmpty) return false;
      key = listArgs[0].toString();
    }

    if (key.isEmpty) return false;
    final entry = _entries.remove(key);
    if (entry != null) {
      entry.remove();
      return true;
    }
    return false;
  }
}
