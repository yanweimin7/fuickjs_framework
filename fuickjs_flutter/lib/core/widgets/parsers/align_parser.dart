import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class AlignParser extends WidgetParser {
  @override
  String get type => 'Align';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    return Align(
      alignment: WidgetUtils.alignment(props['alignment'] as String?) ??
          Alignment.center,
      widthFactor: asDoubleOrNull(props['widthFactor']),
      heightFactor: asDoubleOrNull(props['heightFactor']),
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
