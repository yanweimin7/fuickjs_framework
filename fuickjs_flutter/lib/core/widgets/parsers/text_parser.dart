import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class TextParser extends WidgetParser {
  @override
  String get type => 'Text';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final text = (props['text'] ?? '').toString();
    final dynamic fontSizeProp = props['fontSize'];
    final String? colorProp = props['color'] as String?;
    final String? fontWeightProp = props['fontWeight'] as String?;

    final fontSize = WidgetUtils.asDoubleOrNull(fontSizeProp);
    final color = WidgetUtils.colorFromHex(colorProp);
    final fontWeight = fontWeightProp == 'bold' ? FontWeight.bold : FontWeight.normal;

    return WidgetUtils.wrapPadding(
      props,
      Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
        ),
      ),
    );
  }
}
