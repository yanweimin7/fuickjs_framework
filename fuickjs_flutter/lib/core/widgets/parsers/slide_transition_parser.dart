import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class SlideTransitionParser extends WidgetParser {
  @override
  String get type => 'SlideTransition';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final offsetMap = props['position'] as Map?;
    final offset = Offset(
      asDoubleOrNull(offsetMap?['dx']) ?? 0.0,
      asDoubleOrNull(offsetMap?['dy']) ?? 0.0,
    );

    return SlideTransition(
      position: AlwaysStoppedAnimation(offset),
      transformHitTests: props['transformHitTests'] as bool? ?? true,
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
