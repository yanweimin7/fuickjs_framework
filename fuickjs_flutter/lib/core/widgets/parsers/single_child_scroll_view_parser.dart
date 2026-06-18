import 'package:flutter/material.dart';

import '../../container/fuick_action.dart';
import '../../utils/extensions.dart';
import '../fuick_state_widgets.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class SingleChildScrollViewParser extends WidgetParser {
  @override
  String get type => 'SingleChildScrollView';

  @override
  void onCommand(String refId, String method, dynamic args) {}

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final String? refId = props['refId']?.toString();
    final String? physicsStr = props['physics'] as String?;
    final dynamic paddingProp = props['padding'];
    final String? scrollDirectionStr = props['scrollDirection'] as String?;
    final onScrollEvent = props['onScroll'];
    final onScrollStartReachedEvent = props['onScrollStartReached'];
    final onScrollEndReachedEvent = props['onScrollEndReached'];
    final startThreshold = asDoubleOrNull(props['startThreshold']) ?? 50.0;
    final endThreshold = asDoubleOrNull(props['endThreshold']) ?? 50.0;

    return WidgetUtils.wrapPadding(
      props,
      FuickScrollable(
        key: refId != null ? ValueKey(refId) : null,
        refId: refId,
        builder: (context, controller) {
          Widget scrollView = SingleChildScrollView(
            controller: controller,
            physics: WidgetUtils.scrollPhysics(physicsStr),
            padding: WidgetUtils.edgeInsets(paddingProp),
            scrollDirection: WidgetUtils.axis(scrollDirectionStr),
            child: factory.buildFirstChild(context, children, type),
          );

          if (onScrollEvent != null ||
              onScrollStartReachedEvent != null ||
              onScrollEndReachedEvent != null) {
            scrollView = FuickScrollEdgeNotifier(
              startThreshold: startThreshold,
              endThreshold: endThreshold,
              onScroll: onScrollEvent != null
                  ? (metrics) {
                      FuickAction.event(context, onScrollEvent, value: {
                        'pixels': metrics.pixels,
                        'axis': metrics.axis == Axis.vertical
                            ? 'vertical'
                            : 'horizontal',
                        'maxScrollExtent': metrics.maxScrollExtent,
                      });
                    }
                  : null,
              onStartReached: onScrollStartReachedEvent != null
                  ? () => FuickAction.event(context, onScrollStartReachedEvent)
                  : null,
              onEndReached: onScrollEndReachedEvent != null
                  ? () => FuickAction.event(context, onScrollEndReachedEvent)
                  : null,
              child: scrollView,
            );
          }

          return scrollView;
        },
      ),
    );
  }
}
