import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class ScaleTransitionParser extends WidgetParser {
  @override
  String get type => 'ScaleTransition';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final scale = asDoubleOrNull(props['scale']) ?? 1.0;
    final durationMs = asIntOrNull(props['duration']);
    final alignment =
        WidgetUtils.alignment(props['alignment'] as String?) ??
            Alignment.center;
    final child = factory.buildFirstChild(context, children, type);

    if (durationMs == null || durationMs <= 0) {
      return ScaleTransition(
        scale: AlwaysStoppedAnimation<double>(scale),
        alignment: alignment,
        child: child,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: scale, end: scale),
      duration: Duration(milliseconds: durationMs),
      curve: WidgetUtils.parseCurve(props['curve'] as String?),
      builder: (context, value, _) {
        return ScaleTransition(
          scale: AlwaysStoppedAnimation<double>(value),
          alignment: alignment,
          child: child,
        );
      },
    );
  }
}
