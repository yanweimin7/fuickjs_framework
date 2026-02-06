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
    return RichText(
      textAlign: _textAlign(props['textAlign'] as String?) ?? TextAlign.start,
      textDirection: _textDirection(props['textDirection'] as String?),
      softWrap: props['softWrap'] as bool? ?? true,
      overflow:
          _textOverflow(props['overflow'] as String?) ?? TextOverflow.clip,
      maxLines: asIntOrNull(props['maxLines']),
      text: _parseInlineSpan(context, props['text']),
    );
  }

  InlineSpan _parseInlineSpan(BuildContext context, dynamic map) {
    if (map is! Map) return const TextSpan(text: '');
    final m = Map<String, dynamic>.from(map);
    final String? text = m['text']?.toString();
    final List<InlineSpan> children = [];
    if (m['children'] is List) {
      for (var c in m['children']) {
        children.add(_parseInlineSpan(context, c));
      }
    }

    TextStyle? style;
    final styleMap = m['style'];
    if (styleMap is Map) {
      style = TextStyle(
        color: WidgetUtils.colorFromHex(styleMap['color']),
        fontSize: asDoubleOrNull(styleMap['fontSize']),
        fontWeight:
            styleMap['fontWeight'] == 'bold' ? FontWeight.bold : FontWeight.normal,
        fontStyle:
            styleMap['fontStyle'] == 'italic' ? FontStyle.italic : FontStyle.normal,
        decoration: _textDecoration(styleMap['decoration']),
        height: asDoubleOrNull(styleMap['height']),
      );
    }

    GestureRecognizer? recognizer;
    if (m['onTap'] != null) {
      recognizer = TapGestureRecognizer()
        ..onTap = () {
          FuickAction.event(context, m['onTap']);
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
