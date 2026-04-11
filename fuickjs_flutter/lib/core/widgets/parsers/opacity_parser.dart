import 'package:flutter/material.dart';
import '../../utils/extensions.dart';
import '../widget_factory.dart';
import 'widget_parser.dart';

class OpacityParser extends WidgetParser {
  @override
  String get type => 'Opacity';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final dynamic opacityProp = props['opacity'];
    final double opacity = (asDoubleOrNull(opacityProp) ?? 1.0).clamp(0.0, 1.0);
    // Skip wrapping when opacity == 1.0 to avoid inserting an extra Layer
    if (opacity >= 1.0) return factory.buildFirstChild(context, children, type);
    return Opacity(
      opacity: opacity,
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
