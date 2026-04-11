import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class ConstrainedBoxParser extends WidgetParser {
  @override
  String get type => 'ConstrainedBox';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    return ConstrainedBox(
      constraints: WidgetUtils.boxConstraints(props['constraints']) ??
          const BoxConstraints(),
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
