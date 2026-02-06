import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class CustomScrollViewParser extends WidgetParser {
  @override
  String get type => 'CustomScrollView';

  @override
  void dispose(int nodeId) {}

  @override
  void onCommand(String refId, String method, dynamic args) {}

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    return CustomScrollView(
      scrollDirection: WidgetUtils.axis(props['scrollDirection'] as String?),
      reverse: props['reverse'] ?? false,
      shrinkWrap: props['shrinkWrap'] ?? false,
      physics: WidgetUtils.scrollPhysics(props['physics'] as String?),
      slivers: factory.buildChildren(context, children),
    );
  }
}
