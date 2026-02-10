import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class AlertDialogParser extends WidgetParser {
  @override
  String get type => 'AlertDialog';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    return AlertDialog(
      title: props['title'] != null
          ? factory.build(context, props['title'])
          : null,
      content: props['content'] != null
          ? factory.build(context, props['content'])
          : null,
      actions: props['actions'] != null
          ? factory.buildChildren(context, props['actions'])
          : null,
      actionsPadding: WidgetUtils.edgeInsets(props['actionsPadding']),
      actionsAlignment: WidgetUtils.mainAxis(props['actionsAlignment']),
      backgroundColor:
          WidgetUtils.colorFromHex(props['backgroundColor'] as String?),
      elevation: props['elevation']?.asDoubleOrNull,
    );
  }
}
