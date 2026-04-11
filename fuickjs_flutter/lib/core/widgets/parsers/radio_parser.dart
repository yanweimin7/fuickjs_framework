import 'package:flutter/material.dart';
import '../../container/fuick_action.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class RadioParser extends WidgetParser {
  @override
  String get type => 'Radio';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final value = props['value'] as String? ?? '';
    final groupValue = props['groupValue'] as String? ?? '';
    final activeColor =
        WidgetUtils.colorFromHex(props['activeColor'] as String?);
    final onChangedEvent = props['onChanged'];

    return WidgetUtils.wrapPadding(
      props,
      Radio<String>(
        value: value,
        groupValue: groupValue,
        activeColor: activeColor,
        onChanged: onChangedEvent != null
            ? (v) => FuickAction.event(context, onChangedEvent, value: v)
            : null,
      ),
    );
  }
}
