import 'package:flutter/material.dart';
import '../widget_factory.dart';
import 'widget_parser.dart';

class IgnorePointerParser extends WidgetParser {
  @override
  String get type => 'IgnorePointer';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props, dynamic children, WidgetFactory factory) {
    return IgnorePointer(
      ignoring: props['ignoring'] as bool? ?? true,
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
