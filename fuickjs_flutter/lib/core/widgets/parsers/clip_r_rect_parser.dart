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
    return ClipRRect(
      borderRadius: WidgetUtils.getBorderRadius(props['borderRadius']) ?? BorderRadius.zero,
      clipBehavior: WidgetUtils.clipBehavior(props['clipBehavior'] as String?) ?? Clip.antiAlias,
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
