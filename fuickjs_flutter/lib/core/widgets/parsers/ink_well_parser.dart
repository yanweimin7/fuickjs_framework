import 'package:flutter/material.dart';
import '../../container/fuick_action.dart';
import '../widget_factory.dart';
import 'widget_parser.dart';

class InkWellParser extends WidgetParser {
  @override
  String get type => 'InkWell';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final dynamic onTapProp = props['onTap'];
    final dynamic onDoubleTapProp = props['onDoubleTap'];
    final dynamic onLongPressProp = props['onLongPress'];

    return InkWell(
      onTap: onTapProp != null
          ? () {
              FuickAction.event(context, onTapProp);
            }
          : null,
      onDoubleTap: onDoubleTapProp != null
          ? () => FuickAction.event(context, onDoubleTapProp)
          : null,
      onLongPress: onLongPressProp != null
          ? () => FuickAction.event(context, onLongPressProp)
          : null,
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
