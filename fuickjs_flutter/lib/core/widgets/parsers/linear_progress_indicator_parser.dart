import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class LinearProgressIndicatorParser extends WidgetParser {
  @override
  String get type => 'LinearProgressIndicator';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final value = asDoubleOrNull(props['value']);
    final color = WidgetUtils.colorFromHex(props['color'] as String?);
    final backgroundColor =
        WidgetUtils.colorFromHex(props['backgroundColor'] as String?);
    final minHeight = asDoubleOrNull(props['strokeWidth']) ?? 4.0;
    final borderRadius = asDoubleOrNull(props['borderRadius']) ?? 0.0;

    return WidgetUtils.wrapPadding(
      props,
      ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: LinearProgressIndicator(
          value: value,
          color: color,
          backgroundColor: backgroundColor,
          minHeight: minHeight,
        ),
      ),
    );
  }
}
