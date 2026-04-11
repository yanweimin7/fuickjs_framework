import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class IntrinsicWidthParser extends WidgetParser {
  @override
  String get type => 'IntrinsicWidth';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    return IntrinsicWidth(
      stepWidth: asDoubleOrNull(props['stepWidth']),
      stepHeight: asDoubleOrNull(props['stepHeight']),
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
