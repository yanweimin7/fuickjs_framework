import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class FadeTransitionParser extends WidgetParser {
  @override
  String get type => 'FadeTransition';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final opacity = asDoubleOrNull(props['opacity']) ?? 1.0;
    final durationMs = asIntOrNull(props['duration']);
    final child = factory.buildFirstChild(context, children, type);

    // 未传 duration：保持静态终态（向后兼容）。
    if (durationMs == null || durationMs <= 0) {
      return FadeTransition(
        opacity: AlwaysStoppedAnimation<double>(opacity),
        child: child,
      );
    }

    // 传 duration：走 TweenAnimationBuilder 隐式动画驱动。
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: opacity, end: opacity),
      duration: Duration(milliseconds: durationMs),
      curve: WidgetUtils.parseCurve(props['curve'] as String?),
      builder: (context, value, _) {
        return FadeTransition(
          opacity: AlwaysStoppedAnimation<double>(value),
          child: child,
        );
      },
    );
  }
}
