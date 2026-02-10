import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class ColumnParser extends WidgetParser {
  @override
  String get type => 'Column';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final String? mainAxisAlignmentStr = props['mainAxisAlignment'] as String?;
    final String? crossAxisAlignmentStr =
        props['crossAxisAlignment'] as String?;
    final String? mainAxisSizeStr = props['mainAxisSize'] as String?;

    final mainAxisAlignment = WidgetUtils.mainAxis(mainAxisAlignmentStr);
    final crossAxisAlignment = WidgetUtils.crossAxis(crossAxisAlignmentStr);
    final mainAxisSize = WidgetUtils.mainAxisSize(mainAxisSizeStr);

    return WidgetUtils.wrapPadding(
      props,
      Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: factory.buildChildren(context, children),
      ),
    );
  }
}
