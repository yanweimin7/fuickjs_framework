import 'package:flutter/material.dart';
import '../../container/fuick_action.dart';
import '../fuick_animation.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class ContainerParser extends WidgetParser {
  @override
  String get type => 'Container';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final widthProp = props['width'];
    final heightProp = props['height'];
    final constraintsProp = props['constraints'];
    final alignmentStr = props['alignment'] as String?;
    final paddingProp = props['padding'];
    final marginProp = props['margin'];

    final width = WidgetUtils.sizeNum(widthProp);
    final height = WidgetUtils.sizeNum(heightProp);
    final constraints = WidgetUtils.boxConstraints(constraintsProp);
    final alignment = WidgetUtils.alignment(alignmentStr);
    final padding = WidgetUtils.edgeInsets(paddingProp);
    final margin = WidgetUtils.edgeInsets(marginProp);
    final decoration = WidgetUtils.boxDecorationFromProps(props);

    final Widget child = factory.buildFirstChild(context, children, type);

    // 尺寸动画引用：`<Container width={anim.value} />`
    if (FuickAnim.isRef(widthProp) || FuickAnim.isRef(heightProp)) {
      final bool animWidth = FuickAnim.isRef(widthProp);
      final bool animHeight = FuickAnim.isRef(heightProp);
      final ref = animWidth ? widthProp : heightProp;
      final animated = FuickAnim.wrapIfRef(
        context,
        ref,
        builder: (context, animation) => Container(
          width: animWidth ? animation.value : width,
          height: animHeight ? animation.value : height,
          constraints: constraints,
          alignment: alignment,
          padding: padding,
          margin: margin,
          decoration: decoration,
          child: child,
        ),
      );

      if (animated != null) {
        return _wrapTap(props, context, animated);
      }
    }

    final container = Container(
      width: width,
      height: height,
      constraints: constraints,
      alignment: alignment,
      padding: padding,
      margin: margin,
      decoration: decoration,
      child: child,
    );

    return _wrapTap(props, context, container);
  }

  Widget _wrapTap(
      Map<String, dynamic> props, BuildContext context, Widget child) {
    // 手势支持：onTap / onLongPress
    final dynamic onTapProp = props['onTap'];
    final dynamic onLongPressProp = props['onLongPress'];
    if (onTapProp != null || onLongPressProp != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTapProp != null ? () => FuickAction.event(context, onTapProp) : null,
        onLongPress: onLongPressProp != null ? () => FuickAction.event(context, onLongPressProp) : null,
        child: child,
      );
    }

    return child;
  }
}
