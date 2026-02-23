import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class MaterialParser extends WidgetParser {
  @override
  String get type => 'Material';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    return Material(
      type: _materialType(props['type'] as String?),
      elevation: WidgetUtils.asDouble(props['elevation']),
      color: WidgetUtils.colorFromHex(props['color'] as String?),
      shadowColor: WidgetUtils.colorFromHex(props['shadowColor'] as String?),
      surfaceTintColor:
          WidgetUtils.colorFromHex(props['surfaceTintColor'] as String?),
      textStyle: _textStyle(props['textStyle']),
      borderRadius: WidgetUtils.getBorderRadius(props['borderRadius']),
      borderOnForeground: props['borderOnForeground'] != false,
      clipBehavior:
          _clipBehavior(props['clipBehavior'] as String?) ?? Clip.none,
      animationDuration:
          Duration(milliseconds: asInt(props['animationDuration'] ?? 200)),
      child: factory.buildFirstChild(context, children, type),
    );
  }

  MaterialType _materialType(String? v) {
    switch (v) {
      case 'canvas':
        return MaterialType.canvas;
      case 'card':
        return MaterialType.card;
      case 'circle':
        return MaterialType.circle;
      case 'button':
        return MaterialType.button;
      case 'transparency':
        return MaterialType.transparency;
      default:
        return MaterialType.canvas;
    }
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

  TextStyle? _textStyle(dynamic map) {
    if (map is! Map) return null;
    final Map<String, dynamic> m =
        map is Map<String, dynamic> ? map : Map<String, dynamic>.from(map);

    return TextStyle(
      color: WidgetUtils.colorFromHex(m['color'] as String?),
      fontSize: WidgetUtils.asDoubleOrNull(m['fontSize']),
      fontWeight:
          m['fontWeight'] == 'bold' ? FontWeight.bold : FontWeight.normal,
      fontStyle:
          m['fontStyle'] == 'italic' ? FontStyle.italic : FontStyle.normal,
    );
  }
}
