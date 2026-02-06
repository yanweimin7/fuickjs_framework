import 'package:flutter/material.dart';

import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class AnimatedSlideParser extends WidgetParser {
  @override
  String get type => 'AnimatedSlide';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final offsetMap = props['offset'] as Map?;
    final offset = Offset(
      asDoubleOrNull(offsetMap?['dx']) ?? 0.0,
      asDoubleOrNull(offsetMap?['dy']) ?? 0.0,
    );

    return AnimatedSlide(
      offset: offset,
      duration: Duration(milliseconds: asInt(props['duration'] ?? 300)),
      curve: WidgetUtils.parseCurve(props['curve'] as String?),
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
