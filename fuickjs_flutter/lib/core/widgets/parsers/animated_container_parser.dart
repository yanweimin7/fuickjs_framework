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
    final durationMs = asInt(props['duration'] ?? 300);
    final width = WidgetUtils.sizeNum(props['width']);
    final height = WidgetUtils.sizeNum(props['height']);
    final alignment = WidgetUtils.alignment(props['alignment'] as String?);
    final padding = WidgetUtils.edgeInsets(props['padding']);
    final margin = WidgetUtils.edgeInsets(props['margin']);
    final child = factory.buildFirstChild(context, children, type);
    // duration<=0 时跳过 implicit animation 控制器，避免每帧空转 ticker。
    Widget container = durationMs <= 0
        ? Container(
            width: width,
            height: height,
            constraints: constraints,
            alignment: alignment,
            padding: padding,
            margin: margin,
            decoration: decoration,
            child: child,
          )
        : AnimatedContainer(
            duration: Duration(milliseconds: durationMs),
            curve: WidgetUtils.parseCurve(props['curve'] as String?),
            width: width,
            height: height,
            constraints: constraints,
            alignment: alignment,
            padding: padding,
            margin: margin,
            decoration: decoration,
            child: child,
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
