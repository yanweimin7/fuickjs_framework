import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class RotationTransitionParser extends WidgetParser {
  @override
  String get type => 'RotationTransition';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    return RotationTransition(
      turns: AlwaysStoppedAnimation(asDoubleOrNull(props['turns']) ?? 0.0),
      alignment: WidgetUtils.alignment(props['alignment'] as String?) ??
          Alignment.center,
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
