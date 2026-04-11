import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class PaddingParser extends WidgetParser {
  @override
  String get type => 'Padding';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final dynamic paddingProp = props['padding'];
    final padding = WidgetUtils.edgeInsets(paddingProp) ?? EdgeInsets.zero;

    return Padding(
      padding: padding,
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
