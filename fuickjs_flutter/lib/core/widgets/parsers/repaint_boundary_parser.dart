import 'package:flutter/material.dart';
import '../widget_factory.dart';
import 'widget_parser.dart';

class RepaintBoundaryParser extends WidgetParser {
  @override
  String get type => 'RepaintBoundary';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    return RepaintBoundary(
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
