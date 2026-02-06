import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class AnimatedPositionedParser extends WidgetParser {
  @override
  String get type => 'AnimatedPositioned';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    return AnimatedPositioned(
      left: asDoubleOrNull(props['left']),
      top: asDoubleOrNull(props['top']),
      right: asDoubleOrNull(props['right']),
      bottom: asDoubleOrNull(props['bottom']),
      width: asDoubleOrNull(props['width']),
      height: asDoubleOrNull(props['height']),
      duration: Duration(milliseconds: asInt(props['duration'] ?? 300)),
      curve: WidgetUtils.parseCurve(props['curve'] as String?),
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
