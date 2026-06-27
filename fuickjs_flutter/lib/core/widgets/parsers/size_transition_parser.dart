// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class SizeTransitionParser extends WidgetParser {
  @override
  String get type => 'SizeTransition';

  /// 将 UI 侧的 axisAlignment 字符串转为 SizeTransition.axisAlignment (0.0~1.0)。
  static double _parseAxisAlignment(dynamic v, double defaultValue) {
    if (v is num) return v.toDouble().clamp(0.0, 1.0);
    if (v is String) {
      switch (v) {
        case 'topLeft':
        case 'topCenter':
        case 'topRight':
          return 0.0;
        case 'centerLeft':
        case 'center':
        case 'centerRight':
          return 0.5;
        case 'bottomLeft':
        case 'bottomCenter':
        case 'bottomRight':
          return 1.0;
      }
    }
    return defaultValue;
  }

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final sizeFactor = asDoubleOrNull(props['sizeFactor']) ?? 1.0;
    final durationMs = asIntOrNull(props['duration']);
    final axis = WidgetUtils.axis(props['axis'] as String?,
        defaultAxis: Axis.vertical);
    final axisAlignment = _parseAxisAlignment(props['axisAlignment'], 0.0);
    final child = factory.buildFirstChild(context, children, type);

    if (durationMs == null || durationMs <= 0) {
      return SizeTransition(
        sizeFactor: AlwaysStoppedAnimation<double>(sizeFactor),
        axis: axis,
        axisAlignment: axisAlignment,
        child: child,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: sizeFactor, end: sizeFactor),
      duration: Duration(milliseconds: durationMs),
      curve: WidgetUtils.parseCurve(props['curve'] as String?),
      builder: (context, value, _) {
        return SizeTransition(
          sizeFactor: AlwaysStoppedAnimation<double>(value),
          axis: axis,
          axisAlignment: axisAlignment,
          child: child,
        );
      },
    );
  }
}
