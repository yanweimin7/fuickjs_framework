import 'package:flutter/material.dart';
import '../../container/fuick_action.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class SliderParser extends WidgetParser {
  @override
  String get type => 'Slider';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final value = asDouble(props['value']);
    final min = asDouble(props['min'] ?? 0);
    final max = asDouble(props['max'] ?? 100);
    final divisions = props['step'] != null
        ? ((max - min) / asDouble(props['step'])).round()
        : null;
    final activeColor = WidgetUtils.colorFromHex(props['activeColor'] as String?);
    final inactiveColor = WidgetUtils.colorFromHex(props['inactiveColor'] as String?);
    final onChangedEvent = props['onChanged'];
    final onChangingEvent = props['onChanging'];

    return WidgetUtils.wrapPadding(
      props,
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        onChanged: onChangedEvent != null
            ? (v) => FuickAction.event(context, onChangedEvent, value: v)
            : null,
        onChangeEnd: onChangingEvent != null
            ? (v) => FuickAction.event(context, onChangingEvent, value: v)
            : null,
      ),
    );
  }
}
