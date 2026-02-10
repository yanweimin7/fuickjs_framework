import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class StackParser extends WidgetParser {
  @override
  String get type => 'Stack';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final String? alignmentStr = props['alignment'] as String?;
    final alignment = WidgetUtils.stackAlignment(alignmentStr);

    return WidgetUtils.wrapPadding(
      props,
      Stack(
        alignment: alignment,
        children: factory.buildChildren(context, children),
      ),
    );
  }
}
