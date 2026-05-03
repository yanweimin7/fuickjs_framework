import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class DialogParser extends WidgetParser {
  @override
  String get type => 'Dialog';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final childWidgets = factory.buildChildren(context, children);
    final child = childWidgets.isNotEmpty
        ? Column(mainAxisSize: MainAxisSize.min, children: childWidgets)
        : const SizedBox.shrink();

    final insetPadding = props['insetPadding'];
    EdgeInsets inset;
    if (insetPadding is num) {
      inset = EdgeInsets.all(insetPadding.toDouble());
    } else if (insetPadding is Map) {
      inset = EdgeInsets.symmetric(
        horizontal: (insetPadding['horizontal'] as num?)?.toDouble() ?? 40.0,
        vertical: (insetPadding['vertical'] as num?)?.toDouble() ?? 24.0,
      );
    } else {
      inset = const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0);
    }

    return Dialog(
      elevation: (props['elevation'] as num?)?.toDouble() ?? 8.0,
      backgroundColor:
          WidgetUtils.colorFromHex(props['backgroundColor'] as String?),
      insetPadding: inset,
      shape: RoundedRectangleBorder(
        borderRadius: WidgetUtils.getBorderRadius(props['borderRadius']) ??
            BorderRadius.circular(28),
      ),
      child: child,
    );
  }
}
