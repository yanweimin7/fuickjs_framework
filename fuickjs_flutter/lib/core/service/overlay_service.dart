import 'package:flutter/material.dart' hide widgetFactory;

import '../container/fuick_app_controller.dart';
import '../container/fuick_page_view.dart';
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
    final List listArgs = args is List ? args : [args];
    if (listArgs.isEmpty) return false;

    final Map params = listArgs[0] as Map;
    final String key = params['key'];
    final Map<String, dynamic> dsl = Map<String, dynamic>.from(params['dsl']);
    final int? pageId = params['pageId'];

    if (controller == null) return false;

    // Determine the target navigator/overlay
    // If pageId is provided, try to find that page's context or navigator
    // Otherwise use the top-most navigator
    final navKey = controller!.navigation.getNavigatorKey(pageId);
    final navState = navKey?.currentState;

    if (navState == null) {
      debugPrint('[OverlayService] No navigator found for pageId: $pageId');
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

    navState.overlay?.insert(entry);
    _entries[key] = entry;
    return true;
  }

  bool _hide(dynamic args) {
    final List listArgs = args is List ? args : [args];
    if (listArgs.isEmpty) return false;

    final String key = listArgs[0].toString();
    final entry = _entries.remove(key);

    if (entry != null) {
      entry.remove();
      return true;
    }
    return false;
  }
}
