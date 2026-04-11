import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../container/fuick_action.dart';
import '../../utils/extensions.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class RichTextParser extends WidgetParser {
  @override
  String get type => 'RichText';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final String? textAlignStr = props['textAlign'] as String?;
    final String? textDirectionStr = props['textDirection'] as String?;
    final bool softWrap = props['softWrap'] as bool? ?? true;
    final String? overflowStr = props['overflow'] as String?;
    final dynamic maxLinesProp = props['maxLines'];
    final dynamic textProp = props['text'];

    final defaultStyle = DefaultTextStyle.of(context).style;

    return RichText(
      textAlign: _textAlign(textAlignStr) ?? TextAlign.start,
      textDirection: _textDirection(textDirectionStr),
      softWrap: softWrap,
      overflow: _textOverflow(overflowStr) ?? TextOverflow.clip,
      maxLines: asIntOrNull(maxLinesProp),
      text: _parseInlineSpan(context, textProp, defaultStyle, factory),
    );
  }

  InlineSpan _parseInlineSpan(
      BuildContext context, dynamic map,
      [TextStyle? parentStyle, WidgetFactory? factory]) {
    if (map is! Map) return const TextSpan(text: '');
    final Map<String, dynamic> m =
        map is Map<String, dynamic> ? map : Map<String, dynamic>.from(map);

    // ── WidgetSpan: 内嵌 widget（图片、Icon 等）──
    final String? spanType = m['type'] as String?;
    if (spanType == 'widget' && m['widget'] is Map && factory != null) {
      final widgetMap = Map<String, dynamic>.from(m['widget'] as Map);
      final widgetType = widgetMap['type'] as String? ?? '';
      final widgetProps = widgetMap['props'] is Map
          ? Map<String, dynamic>.from(widgetMap['props'] as Map)
          : <String, dynamic>{};
      final widgetChildren = widgetMap['children'];

      final child = factory.build(context, {
        'type': widgetType,
        'props': widgetProps,
        'children': widgetChildren,
      });

      final alignStr = m['alignment'] as String?;
      return WidgetSpan(
        alignment: _placeholderAlignment(alignStr),
        child: child,
      );
    }

    // ── 普通 TextSpan ──
    final String? text = m['text']?.toString();
    final dynamic childrenProp = m['children'];
    final List<InlineSpan> children = [];
    if (childrenProp is List) {
      for (var c in childrenProp) {
        children.add(_parseInlineSpan(context, c, parentStyle, factory));
      }
    }

    TextStyle? style;
    final dynamic styleMap = m['style'];
    if (styleMap is Map) {
      final String? colorStr = styleMap['color'] as String?;
      final dynamic fontSizeProp = styleMap['fontSize'];
      final String? fontWeightStr = styleMap['fontWeight'] as String?;
      final String? fontStyleStr = styleMap['fontStyle'] as String?;
      final dynamic decorationProp = styleMap['decoration'];
      final dynamic heightProp = styleMap['height'];
      final dynamic letterSpacingProp = styleMap['letterSpacing'];
      final String? backgroundColorStr = styleMap['backgroundColor'] as String?;

      style = TextStyle(
        color: WidgetUtils.colorFromHex(colorStr),
        fontSize: asDoubleOrNull(fontSizeProp),
        fontWeight:
            fontWeightStr == 'bold' ? FontWeight.bold : (fontWeightStr != null ? WidgetUtils.fontWeight(fontWeightStr) : null),
        fontStyle:
            fontStyleStr == 'italic' ? FontStyle.italic : (fontStyleStr != null ? FontStyle.normal : null),
        decoration: _textDecoration(decorationProp),
        height: asDoubleOrNull(heightProp),
        letterSpacing: asDoubleOrNull(letterSpacingProp),
        backgroundColor: WidgetUtils.colorFromHex(backgroundColorStr),
      );
    }

    // 根节点使用 parentStyle 作为默认样式，确保文字可见
    style = style ?? parentStyle;

    GestureRecognizer? recognizer;
    final dynamic onTapProp = m['onTap'];
    if (onTapProp != null) {
      recognizer = TapGestureRecognizer()
        ..onTap = () {
          FuickAction.event(context, onTapProp);
        };
    }

    return TextSpan(
      text: text,
      children: children,
      style: style,
      recognizer: recognizer,
    );
  }

  PlaceholderAlignment _placeholderAlignment(String? v) {
    switch (v) {
      case 'top':
        return PlaceholderAlignment.top;
      case 'bottom':
        return PlaceholderAlignment.bottom;
      case 'middle':
        return PlaceholderAlignment.middle;
      case 'aboveBaseline':
        return PlaceholderAlignment.aboveBaseline;
      case 'belowBaseline':
        return PlaceholderAlignment.belowBaseline;
      case 'baseline':
        return PlaceholderAlignment.baseline;
      default:
        return PlaceholderAlignment.middle;
    }
  }

  TextAlign? _textAlign(String? v) {
    switch (v) {
      case 'center':
        return TextAlign.center;
      case 'end':
        return TextAlign.end;
      case 'justify':
        return TextAlign.justify;
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      case 'start':
        return TextAlign.start;
      default:
        return null;
    }
  }

  TextDirection? _textDirection(String? v) {
    if (v == 'rtl') return TextDirection.rtl;
    if (v == 'ltr') return TextDirection.ltr;
    return null;
  }

  TextOverflow? _textOverflow(String? v) {
    if (v == 'ellipsis') return TextOverflow.ellipsis;
    if (v == 'fade') return TextOverflow.fade;
    if (v == 'visible') return TextOverflow.visible;
    return TextOverflow.clip;
  }

  TextDecoration? _textDecoration(String? v) {
    if (v == 'underline') return TextDecoration.underline;
    if (v == 'lineThrough') return TextDecoration.lineThrough;
    if (v == 'overline') return TextDecoration.overline;
    return TextDecoration.none;
  }
}
