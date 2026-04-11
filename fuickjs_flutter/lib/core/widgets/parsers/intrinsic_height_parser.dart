import 'package:flutter/material.dart';
import '../widget_factory.dart';
import 'widget_parser.dart';

class IntrinsicHeightParser extends WidgetParser {
  @override
  String get type => 'IntrinsicHeight';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    return IntrinsicHeight(
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
