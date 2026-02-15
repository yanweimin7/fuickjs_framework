import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../container/fuick_action.dart';
import '../../container/fuick_app_controller.dart';
import '../widget_factory.dart';
import 'widget_parser.dart';

class VisibilityDetectorParser extends WidgetParser {
  @override
  String get type => 'VisibilityDetector';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final keyStr = props['key'] ?? props['refId'];
    if (keyStr == null) {
      // VisibilityDetector requires a Key.
      // If none provided, we might fail or generate one, but generating one on every build is bad.
      // It should ideally be provided by the user.
      // For now, if no key, we can't use VisibilityDetector effectively as it loses state/tracking.
      // But maybe we return a warning or just a unique key (which might cause issues).
      // Let's assume the user MUST provide a key or refId.
      return factory.buildFirstChild(context, children, type);
    }

    // Capture the controller to use it in the callback even if the widget is unmounted.
    final controller = FuickAppScope.of(context);

    return VisibilityDetector(
      key: Key(keyStr.toString()),
      onVisibilityChanged: (VisibilityInfo info) {
        if (props['onVisibilityChanged'] != null) {
          FuickAction.event(context, props['onVisibilityChanged'],
              value: {
                'visibleFraction': info.visibleFraction,
                'size': {'width': info.size.width, 'height': info.size.height},
                'visibleBounds': {
                  'left': info.visibleBounds.left,
                  'top': info.visibleBounds.top,
                  'width': info.visibleBounds.width,
                  'height': info.visibleBounds.height,
                }
              },
              controller: controller);
        }
      },
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
