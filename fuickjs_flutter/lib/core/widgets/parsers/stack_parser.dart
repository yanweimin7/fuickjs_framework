import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class StackParser extends WidgetParser {
  @override
  String get type => 'Stack';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final String? alignmentStr = props['alignment'] as String?;
    final alignment = WidgetUtils.stackAlignment(alignmentStr);

    final String? fitStr = props['fit'] as String?;
    final StackFit fit = fitStr == 'expand'
        ? StackFit.expand
        : fitStr == 'passthrough'
            ? StackFit.passthrough
            : StackFit.loose;

    return WidgetUtils.wrapPadding(
      props,
      Stack(
        alignment: alignment,
        fit: fit,
        children: factory.buildChildren(context, children),
      ),
    );
  }
}
