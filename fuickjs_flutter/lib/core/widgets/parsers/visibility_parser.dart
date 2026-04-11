import 'package:flutter/material.dart';
import '../widget_factory.dart';
import 'widget_parser.dart';

class VisibilityParser extends WidgetParser {
  @override
  String get type => 'Visibility';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props, dynamic children, WidgetFactory factory) {
    return Visibility(
      visible: props['visible'] ?? true,
      maintainState: props['maintainState'] ?? false,
      maintainAnimation: props['maintainAnimation'] ?? false,
      maintainSize: props['maintainSize'] ?? false,
      maintainSemantics: props['maintainSemantics'] ?? false,
      maintainInteractivity: props['maintainInteractivity'] ?? false,
      replacement: props['replacement'] != null
          ? factory.build(context, props['replacement'])
          : const SizedBox.shrink(),
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
