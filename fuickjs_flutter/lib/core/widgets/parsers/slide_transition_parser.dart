import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class SlideTransitionParser extends WidgetParser {
  @override
  String get type => 'SlideTransition';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final offsetMap = props['position'] as Map?;
    final offset = Offset(
      asDoubleOrNull(offsetMap?['dx']) ?? 0.0,
      asDoubleOrNull(offsetMap?['dy']) ?? 0.0,
    );
    final durationMs = asIntOrNull(props['duration']);
    final transformHitTests = props['transformHitTests'] as bool? ?? true;
    final child = factory.buildFirstChild(context, children, type);

    if (durationMs == null || durationMs <= 0) {
      return SlideTransition(
        position: AlwaysStoppedAnimation<Offset>(offset),
        transformHitTests: transformHitTests,
        child: child,
      );
    }

    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(begin: offset, end: offset),
      duration: Duration(milliseconds: durationMs),
      curve: WidgetUtils.parseCurve(props['curve'] as String?),
      builder: (context, value, _) {
        return SlideTransition(
          position: AlwaysStoppedAnimation<Offset>(value),
          transformHitTests: transformHitTests,
          child: child,
        );
      },
    );
  }
}
