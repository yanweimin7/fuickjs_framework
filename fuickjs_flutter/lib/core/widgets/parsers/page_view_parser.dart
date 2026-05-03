import 'package:flutter/material.dart';

import '../../container/fuick_action.dart';
import '../../utils/extensions.dart';
import '../fuick_state_widgets.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class PageViewParser extends WidgetParser {
  @override
  String get type => 'PageView';

  @override
  void onCommand(String refId, String method, dynamic args) {}

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final int? initialPage = asIntOrNull(props['initialPage']);
    final String? refId = props['refId']?.toString();
    final ScrollPhysics? physics = WidgetUtils.physics(props['physics']);
    final bool autoplay = props['autoplay'] == true;
    final int autoplayInterval = asInt(props['autoplayInterval'] ?? 5000);
    final bool circular = props['circular'] == true;
    final bool indicatorDots = props['indicatorDots'] == true;
    final String? indicatorColor = props['indicatorColor'] as String?;
    final String? indicatorActiveColor =
        props['indicatorActiveColor'] as String?;

    final childWidgets = factory.buildChildren(context, children);

    return WidgetUtils.wrapPadding(
      props,
      FuickPageView(
        key: refId != null ? ValueKey(refId) : null,
        refId: refId,
        initialPage: initialPage ?? 0,
        scrollDirection: props['scrollDirection'] == 'vertical'
            ? Axis.vertical
            : Axis.horizontal,
        physics: physics,
        autoplay: autoplay,
        autoplayInterval: autoplayInterval,
        circular: circular,
        indicatorDots: indicatorDots,
        indicatorColor: WidgetUtils.colorFromHex(indicatorColor),
        indicatorActiveColor: WidgetUtils.colorFromHex(indicatorActiveColor),
        onPageChanged: (index) {
          if (props['onPageChanged'] != null) {
            FuickAction.event(context, props['onPageChanged'], value: index);
          }
        },
        children: childWidgets,
      ),
    );
  }

  @override
  void dispose(int nodeId) {}
}
