import 'package:flutter/material.dart';
import '../../container/fuick_action.dart';
import '../../utils/extensions.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class CheckboxParser extends WidgetParser {
  @override
  String get type => 'Checkbox';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final bool tristate = asBool(props['tristate']);
    final bool? rawValue = asBoolOrNull(props['value']);
    final bool? value = tristate ? rawValue : (rawValue ?? false);

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
