import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class TextParser extends WidgetParser {
  @override
  String get type => 'Text';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    String text = (props['text'] ?? '').toString();
    final bool selectionDisabled = props['selectionDisabled'] == true;
    final String? textAlignProp = props['textAlign'] as String?;
    final String? overflowProp = props['overflow'] as String?;
    final dynamic maxLinesProp = props['maxLines'];
    final String? textTransformProp = props['textTransform'] as String?;
    final bool? softWrapProp = props['softWrap'] as bool?;

    final selectable = props['selectable'] == true;

    // TextStyle 仅依赖样式字段，按 props 实例缓存，避免每次 build 重新构造。
    final style = WidgetUtils.textStyleFromProps(props);

    // text-transform：构建时来不及处理的动态文本在运行时转换
    if (textTransformProp != null) {
      switch (textTransformProp) {
        case 'uppercase':
          text = text.toUpperCase();
          break;
        case 'lowercase':
          text = text.toLowerCase();
          break;
        case 'capitalize':
          text = text.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
          break;
      }
    }

    TextAlign? textAlign;
    switch (textAlignProp) {
      case 'left': textAlign = TextAlign.left; break;
      case 'right': textAlign = TextAlign.right; break;
      case 'center': textAlign = TextAlign.center; break;
      case 'justify': textAlign = TextAlign.justify; break;
      case 'start': textAlign = TextAlign.start; break;
      case 'end': textAlign = TextAlign.end; break;
    }

    TextOverflow? overflow;
    if (overflowProp == 'ellipsis') overflow = TextOverflow.ellipsis;
    if (overflowProp == 'fade') overflow = TextOverflow.fade;
    if (overflowProp == 'clip') overflow = TextOverflow.clip;

    final maxLines = maxLinesProp is num ? maxLinesProp.toInt() : null;
    final softWrap = softWrapProp ?? true;

    Widget textWidget = selectable
        ? SelectableText(
            text,
            style: style,
            textAlign: textAlign,
            maxLines: maxLines,
          )
        : Text(
            text,
            style: style,
            textAlign: textAlign,
            overflow: overflow,
            maxLines: maxLines,
            softWrap: softWrap,
          );
    if (selectionDisabled) {
      textWidget = SelectionContainer.disabled(child: textWidget);
    }

    return WidgetUtils.wrapPadding(props, textWidget);
  }
}
