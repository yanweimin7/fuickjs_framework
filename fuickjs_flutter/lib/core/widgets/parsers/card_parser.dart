import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class CardParser extends WidgetParser {
  @override
  String get type => 'Card';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    return Card(
      color: WidgetUtils.colorFromHex(props['color'] as String?),
      shadowColor: WidgetUtils.colorFromHex(props['shadowColor'] as String?),
      surfaceTintColor:
          WidgetUtils.colorFromHex(props['surfaceTintColor'] as String?),
      elevation: asDoubleOrNull(props['elevation']),
      margin: WidgetUtils.edgeInsets(props['margin']),
      clipBehavior: _clipBehavior(props['clipBehavior'] as String?),
      child: factory.buildFirstChild(context, children, type),
    );
  }

  Clip? _clipBehavior(String? v) {
    switch (v) {
      case 'none':
        return Clip.none;
      case 'hardEdge':
        return Clip.hardEdge;
      case 'antiAlias':
        return Clip.antiAlias;
      case 'antiAliasWithSaveLayer':
        return Clip.antiAliasWithSaveLayer;
      default:
        return null;
    }
  }
}
