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
    final dynamic fontSizeProp = props['fontSize'];
    final String? colorProp = props['color'] as String?;
    final String? fontWeightProp = props['fontWeight'] as String?;
    final String? fontStyleProp = props['fontStyle'] as String?;
    final String? fontFamilyProp = props['fontFamily'] as String?;
    final bool selectionDisabled = props['selectionDisabled'] == true;
    final String? textAlignProp = props['textAlign'] as String?;
    final String? overflowProp = props['overflow'] as String?;
    final dynamic maxLinesProp = props['maxLines'];
    final String? textDecorationProp = props['textDecoration'] as String?;
    final String? textTransformProp = props['textTransform'] as String?;
    final dynamic textShadowProp = props['textShadow'];
    final dynamic letterSpacingProp = props['letterSpacing'];
    final dynamic lineHeightProp = props['lineHeight'];
    final bool? softWrapProp = props['softWrap'] as bool?;

    final fontSize = WidgetUtils.asDoubleOrNull(fontSizeProp);
    final color = WidgetUtils.colorFromHex(colorProp);
    final fontWeight = WidgetUtils.fontWeight(fontWeightProp);
    final selectable = props['selectable'] == true;
    final fontStyle = fontStyleProp == 'italic' ? FontStyle.italic : FontStyle.normal;
    final decoration = WidgetUtils.textDecoration(textDecorationProp);
    final shadows = WidgetUtils.getTextShadow(textShadowProp);
    final letterSpacing = WidgetUtils.asDoubleOrNull(letterSpacingProp);
    final lineHeight = WidgetUtils.asDoubleOrNull(lineHeightProp);
    final lineHeightIsAbsolute = props['_lineHeightIsAbsolute'] == true;
    final wordSpacing = WidgetUtils.asDoubleOrNull(props['wordSpacing']);

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

    final style = TextStyle(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      fontFamily: fontFamilyProp,
      decoration: decoration,
      shadows: shadows,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      // lineHeightIsAbsolute=true: line-height:24px → 需要除以 fontSize 得倍数
      // lineHeightIsAbsolute=false: line-height:1.5 → 直接作为倍数
      height: lineHeight != null
          ? (lineHeightIsAbsolute && fontSize != null ? lineHeight / fontSize : lineHeight)
          : null,
    );

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
