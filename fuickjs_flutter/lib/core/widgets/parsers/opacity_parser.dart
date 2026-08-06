import 'package:flutter/material.dart';
import '../../utils/extensions.dart';
import '../fuick_animation.dart';
import '../widget_factory.dart';
import 'widget_parser.dart';

class OpacityParser extends WidgetParser {
  @override
  String get type => 'Opacity';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final dynamic opacityProp = props['opacity'];
    final Widget child = factory.buildFirstChild(context, children, type);

    // 动画引用：`{ "@anim": id, "spec": {...} }` → Flutter 端 AnimationController 驱动
    final animated = FuickAnim.wrapIfRef(
      context,
      opacityProp,
      builder: (context, animation) => Opacity(
        opacity: animation.value.clamp(0.0, 1.0),
        child: child,
      ),
    );
    if (animated != null) return animated;

    final double opacity = (asDoubleOrNull(opacityProp) ?? 1.0).clamp(0.0, 1.0);
    // Skip wrapping when opacity == 1.0 to avoid inserting an extra Layer
    if (opacity >= 1.0) return child;
    return Opacity(
      opacity: opacity,
      child: child,
    );
  }
}
