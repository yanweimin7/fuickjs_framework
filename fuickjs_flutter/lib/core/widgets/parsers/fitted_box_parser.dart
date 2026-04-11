import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class FittedBoxParser extends WidgetParser {
  @override
  String get type => 'FittedBox';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    return FittedBox(
      fit: WidgetUtils.boxFit(props['fit'] as String?) ?? BoxFit.contain,
      alignment: WidgetUtils.alignment(props['alignment'] as String?) ??
          Alignment.center,
      clipBehavior: WidgetUtils.clipBehavior(props['clipBehavior'] as String?) ??
          Clip.none,
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
