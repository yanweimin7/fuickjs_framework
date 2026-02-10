import 'package:flutter/material.dart';

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

    return WidgetUtils.wrapPadding(
      props,
      FuickScrollable(
        key: refId != null ? ValueKey(refId) : null,
        refId: refId,
        builder: (context, controller) {
          return SingleChildScrollView(
            controller: controller,
            physics: WidgetUtils.scrollPhysics(physicsStr),
            padding: WidgetUtils.edgeInsets(paddingProp),
            scrollDirection: WidgetUtils.axis(scrollDirectionStr),
            child: factory.buildFirstChild(context, children, type),
          );
        },
      ),
    );
  }
}
