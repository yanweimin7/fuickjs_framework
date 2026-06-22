import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class FadeTransitionParser extends WidgetParser {
  @override
  String get type => 'FadeTransition';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    return FadeTransition(
      opacity:
          AlwaysStoppedAnimation(asDoubleOrNull(props['opacity']) ?? 1.0),
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
