import 'package:flutter/material.dart';
import '../../container/fuick_action.dart';
import '../widget_factory.dart';
import 'widget_parser.dart';

class PopScopeParser extends WidgetParser {
  @override
  String get type => 'PopScope';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final bool canPop = props['canPop'] ?? true;
    final dynamic onPopInvokedProp = props['onPopInvoked'];

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: onPopInvokedProp != null
          ? (bool didPop, dynamic result) {
              FuickAction.event(context, onPopInvokedProp, value: didPop);
            }
          : null,
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
