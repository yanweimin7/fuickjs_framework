import 'package:flutter/material.dart';
import '../../container/fuick_action.dart';
import '../widget_factory.dart';
import 'widget_parser.dart';

class PointerListenerParser extends WidgetParser {
  @override
  String get type => 'PointerListener';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final dynamic onPointerDownProp = props['onPointerDown'];
    final dynamic onPointerMoveProp = props['onPointerMove'];
    final dynamic onPointerUpProp = props['onPointerUp'];
    final dynamic onPointerCancelProp = props['onPointerCancel'];
    final String? behaviorStr = props['behavior'];

    HitTestBehavior behavior = HitTestBehavior.deferToChild;
    if (behaviorStr == 'opaque') {
      behavior = HitTestBehavior.opaque;
    } else if (behaviorStr == 'translucent') {
      behavior = HitTestBehavior.translucent;
    }

    Map<String, dynamic> eventToMap(PointerEvent event) {
      return {
        'position': {'dx': event.position.dx, 'dy': event.position.dy},
        'localPosition': {
          'dx': event.localPosition.dx,
          'dy': event.localPosition.dy
        },
        'pressure': event.pressure,
        'delta': {'dx': event.delta.dx, 'dy': event.delta.dy},
      };
    }

    return Listener(
      behavior: behavior,
      onPointerDown: onPointerDownProp != null
          ? (event) => FuickAction.event(context, onPointerDownProp,
              value: eventToMap(event))
          : null,
      onPointerMove: onPointerMoveProp != null
          ? (event) => FuickAction.event(context, onPointerMoveProp,
              value: eventToMap(event))
          : null,
      onPointerUp: onPointerUpProp != null
          ? (event) =>
              FuickAction.event(context, onPointerUpProp, value: eventToMap(event))
          : null,
      onPointerCancel: onPointerCancelProp != null
          ? (event) => FuickAction.event(context, onPointerCancelProp,
              value: eventToMap(event))
          : null,
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
