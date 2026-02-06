import 'package:flutter/material.dart';
import '../../container/fuick_action.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class FloatingActionButtonParser extends WidgetParser {
  @override
  String get type => 'FloatingActionButton';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final event = props['onPressed'];
    final child = factory.buildFirstChild(context, children, type);

    return WidgetUtils.wrapPadding(
      props,
      FloatingActionButton(
        onPressed: event != null
            ? () {
                FuickAction.event(context, event);
              }
            : null,
        child: child,
      ),
    );
  }
}
