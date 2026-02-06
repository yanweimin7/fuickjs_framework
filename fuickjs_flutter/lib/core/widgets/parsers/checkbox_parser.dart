import 'package:flutter/material.dart';
import '../../container/fuick_action.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class CheckboxParser extends WidgetParser {
  @override
  String get type => 'Checkbox';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final bool? value = props['value'] as bool?;
    final bool tristate = props['tristate'] == true;

    return Checkbox(
      value: value,
      tristate: tristate,
      onChanged: props['onChanged'] != null
          ? (bool? newValue) {
              FuickAction.event(context, props['onChanged'], value: newValue);
            }
          : null,
      activeColor: WidgetUtils.colorFromHex(props['activeColor'] as String?),
      checkColor: WidgetUtils.colorFromHex(props['checkColor'] as String?),
    );
  }
}
