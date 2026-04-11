import 'package:flutter/material.dart';

import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class FractionallySizedBoxParser extends WidgetParser {
  @override
  String get type => 'FractionallySizedBox';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    return FractionallySizedBox(
      widthFactor: asDoubleOrNull(props['widthFactor']),
      heightFactor: asDoubleOrNull(props['heightFactor']),
      alignment: WidgetUtils.alignment(props['alignment'] as String?) ?? Alignment.center,
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
