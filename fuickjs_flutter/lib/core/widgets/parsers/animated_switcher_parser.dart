import 'package:flutter/material.dart';

import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class AnimatedSwitcherParser extends WidgetParser {
  @override
  String get type => 'AnimatedSwitcher';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final durationMs = asInt(props['duration'] ?? 300);
    final reverseDurationMs = asIntOrNull(props['reverseDuration']);

    return AnimatedSwitcher(
      duration: Duration(milliseconds: durationMs),
      reverseDuration: reverseDurationMs != null
          ? Duration(milliseconds: reverseDurationMs)
          : null,
      switchInCurve: WidgetUtils.parseCurve(props['switchInCurve'] as String?),
      switchOutCurve: WidgetUtils.parseCurve(props['switchOutCurve'] as String?),
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
