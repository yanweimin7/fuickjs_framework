import 'package:flutter/material.dart';

import '../../container/fuick_action.dart';
import '../../utils/extensions.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class AnimatedContainerParser extends WidgetParser {
  @override
  String get type => 'AnimatedContainer';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final decoration = WidgetUtils.boxDecorationFromProps(props);
    final constraints = WidgetUtils.boxConstraints(props['constraints']);
    Widget container = AnimatedContainer(
      duration: Duration(milliseconds: asInt(props['duration'] ?? 300)),
      curve: WidgetUtils.parseCurve(props['curve'] as String?),
      width: WidgetUtils.sizeNum(props['width']),
      height: WidgetUtils.sizeNum(props['height']),
      constraints: constraints,
      alignment: WidgetUtils.alignment(props['alignment'] as String?),
      padding: WidgetUtils.edgeInsets(props['padding']),
      margin: WidgetUtils.edgeInsets(props['margin']),
      decoration: decoration,
      child: factory.buildFirstChild(context, children, type),
    );

    // 手势支持：onTap / onLongPress
    final dynamic onTapProp = props['onTap'];
    final dynamic onLongPressProp = props['onLongPress'];
    if (onTapProp != null || onLongPressProp != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTapProp != null ? () => FuickAction.event(context, onTapProp) : null,
        onLongPress: onLongPressProp != null ? () => FuickAction.event(context, onLongPressProp) : null,
        child: container,
      );
    }

    return container;
  }
}
