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

    return RichText(
      textAlign: _textAlign(textAlignStr) ?? TextAlign.start,
      textDirection: _textDirection(textDirectionStr),
      softWrap: softWrap,
      overflow: _textOverflow(overflowStr) ?? TextOverflow.clip,
      maxLines: asIntOrNull(maxLinesProp),
      text: _parseInlineSpan(context, textProp),
    );
  }

  InlineSpan _parseInlineSpan(BuildContext context, dynamic map) {
    if (map is! Map) return const TextSpan(text: '');
    final Map<String, dynamic> m = map is Map<String, dynamic> ? map : Map<String, dynamic>.from(map);
    final String? text = m['text']?.toString();
    final dynamic childrenProp = m['children'];
    final List<InlineSpan> children = [];
    if (childrenProp is List) {
      for (var c in childrenProp) {
        children.add(_parseInlineSpan(context, c));
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

      style = TextStyle(
        color: WidgetUtils.colorFromHex(colorStr),
        fontSize: asDoubleOrNull(fontSizeProp),
        fontWeight:
            fontWeightStr == 'bold' ? FontWeight.bold : FontWeight.normal,
        fontStyle:
            fontStyleStr == 'italic' ? FontStyle.italic : FontStyle.normal,
        decoration: _textDecoration(decorationProp),
        height: asDoubleOrNull(heightProp),
      );
    }

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
