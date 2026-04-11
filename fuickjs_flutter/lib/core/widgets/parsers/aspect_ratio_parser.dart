import 'package:flutter/material.dart';

import '../widget_factory.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class AspectRatioParser extends WidgetParser {
  @override
  String get type => 'AspectRatio';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final ratio = (asDoubleOrNull(props['aspectRatio']) ?? 1.0).clamp(0.01, double.infinity);
    return AspectRatio(
      aspectRatio: ratio,
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
