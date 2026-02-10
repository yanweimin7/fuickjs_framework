import 'package:flutter/material.dart';
import '../../container/fuick_action.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class GestureDetectorParser extends WidgetParser {
  @override
  String get type => 'GestureDetector';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final dynamic onTapProp = props['onTap'];
    final dynamic onDoubleTapProp = props['onDoubleTap'];
    final dynamic onLongPressProp = props['onLongPress'];
    final dynamic onPanStartProp = props['onPanStart'];
    final dynamic onPanUpdateProp = props['onPanUpdate'];
    final dynamic onPanEndProp = props['onPanEnd'];

    return WidgetUtils.wrapPadding(
      props,
      GestureDetector(
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
        onPanStart: onPanStartProp != null
            ? (details) => FuickAction.event(context, onPanStartProp, value: {
                  'dx': details.localPosition.dx,
                  'dy': details.localPosition.dy
                })
            : null,
        onPanUpdate: onPanUpdateProp != null
            ? (details) => FuickAction.event(context, onPanUpdateProp, value: {
                  'dx': details.localPosition.dx,
                  'dy': details.localPosition.dy
                })
            : null,
        onPanEnd: onPanEndProp != null
            ? (details) => FuickAction.event(context, onPanEndProp)
            : null,
        child: factory.buildFirstChild(context, children, type),
      ),
    );
  }
}
