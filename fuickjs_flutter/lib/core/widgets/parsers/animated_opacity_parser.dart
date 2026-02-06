import 'package:flutter/material.dart';

import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class AnimatedOpacityParser extends WidgetParser {
  @override
  String get type => 'AnimatedOpacity';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    return AnimatedOpacity(
      opacity: asDoubleOrNull(props['opacity']) ?? 1.0,
      duration: Duration(milliseconds: asInt(props['duration'] ?? 300)),
      curve: WidgetUtils.parseCurve(props['curve'] as String?),
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
