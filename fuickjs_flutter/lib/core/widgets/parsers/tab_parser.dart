import 'package:flutter/material.dart';
import '../widget_factory.dart';
import 'widget_parser.dart';

class TabParser extends WidgetParser {
  @override
  String get type => 'Tab';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    return Tab(
      text: props['text'],
      icon: props['icon'] != null ? factory.build(context, props['icon']) : null,
      child: props['child'] != null ? factory.build(context, props['child']) : null,
    );
  }
}
