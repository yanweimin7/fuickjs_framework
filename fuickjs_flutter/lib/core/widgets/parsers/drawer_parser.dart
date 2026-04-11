import 'package:flutter/material.dart';

import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class DrawerParser extends WidgetParser {
  @override
  String get type => 'Drawer';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    return Drawer(
      backgroundColor: WidgetUtils.colorFromHex(props['backgroundColor'] as String?),
      elevation: asDoubleOrNull(props['elevation']),
      width: asDoubleOrNull(props['width']),
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
