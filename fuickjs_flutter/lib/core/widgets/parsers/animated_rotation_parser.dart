import 'package:flutter/material.dart';

import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class AnimatedRotationParser extends WidgetParser {
  @override
  String get type => 'AnimatedRotation';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    return AnimatedRotation(
      turns: asDoubleOrNull(props['turns']) ?? 0.0,
      duration: Duration(milliseconds: asInt(props['duration'] ?? 300)),
      curve: WidgetUtils.parseCurve(props['curve'] as String?),
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
