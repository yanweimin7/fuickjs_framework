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
    return SizeTransition(
      sizeFactor:
          AlwaysStoppedAnimation(asDoubleOrNull(props['sizeFactor']) ?? 1.0),
      axis: WidgetUtils.axis(props['axis'] as String?,
          defaultAxis: Axis.vertical),
      // axisAlignment 已在最新 Flutter 中标记为 deprecated（被 alignment 取代），
      // 项目 SDK 下限仍保留该 API。
      axisAlignment: _parseAxisAlignment(props['axisAlignment'], 0.0),
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
