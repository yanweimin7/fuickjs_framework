import 'package:flutter/material.dart';
import '../../utils/extensions.dart';
import '../widget_factory.dart';
import 'widget_parser.dart';

/// writing-mode: vertical → RotatedBox
class RotatedBoxParser extends WidgetParser {
  @override
  String get type => 'RotatedBox';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final quarterTurns = asIntOrNull(props['quarterTurns']) ?? 1;
    return RotatedBox(
      quarterTurns: quarterTurns,
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
