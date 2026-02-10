import 'package:flutter/material.dart';

import '../../utils/extensions.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class IconParser extends WidgetParser {
  @override
  String get type => 'Icon';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final dynamic cpProp = props['codePoint'];
    final dynamic nameProp = props['name'];
    final String? colorProp = props['color'] as String?;
    final dynamic sizeProp = props['size'];

    final int? cp = asIntOrNull(cpProp);
    final String? name = nameProp?.toString();
    final Color? color = WidgetUtils.colorFromHex(colorProp);
    final double? size = WidgetUtils.sizeNum(sizeProp);

    IconData data;
    if (cp != null) {
      data = Icons.circle;
      // data = IconData(cp, fontFamily: 'MaterialIcons');
    } else if (name != null) {
      data = WidgetUtils.iconData(name);
    } else {
      data = Icons.circle;
    }

    return WidgetUtils.wrapPadding(props, Icon(data, color: color, size: size));
  }
}
