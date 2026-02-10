import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class PositionedParser extends WidgetParser {
  @override
  String get type => 'Positioned';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final leftProp = props['left'];
    final topProp = props['top'];
    final rightProp = props['right'];
    final bottomProp = props['bottom'];
    final widthProp = props['width'];
    final heightProp = props['height'];

    final left = WidgetUtils.sizeNum(leftProp);
    final top = WidgetUtils.sizeNum(topProp);
    final right = WidgetUtils.sizeNum(rightProp);
    final bottom = WidgetUtils.sizeNum(bottomProp);
    final width = WidgetUtils.sizeNum(widthProp);
    final height = WidgetUtils.sizeNum(heightProp);

    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: width,
      height: height,
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
