import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class ClipRRectParser extends WidgetParser {
  @override
  String get type => 'ClipRRect';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final dynamic borderRadiusProp = props['borderRadius'];
    final String? clipBehaviorStr = props['clipBehavior'] as String?;

    return ClipRRect(
      borderRadius: WidgetUtils.getBorderRadius(borderRadiusProp) ?? BorderRadius.zero,
      clipBehavior: WidgetUtils.clipBehavior(clipBehaviorStr) ?? Clip.antiAlias,
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
