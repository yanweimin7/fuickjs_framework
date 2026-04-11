import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class WrapParser extends WidgetParser {
  @override
  String get type => 'Wrap';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final String? directionStr = props['direction'] as String?;
    final String? alignmentStr = props['alignment'] as String?;
    final dynamic spacingProp = props['spacing'];
    final String? runAlignmentStr = props['runAlignment'] as String?;
    final dynamic runSpacingProp = props['runSpacing'];
    final String? crossAxisAlignmentStr = props['crossAxisAlignment'] as String?;
    final String? textDirectionStr = props['textDirection'] as String?;
    final String? verticalDirectionStr = props['verticalDirection'] as String?;
    final String? clipBehaviorStr = props['clipBehavior'] as String?;

    return Wrap(
      direction: WidgetUtils.axis(directionStr, defaultAxis: Axis.horizontal),
      alignment: _wrapAlignment(alignmentStr),
      spacing: asDouble(spacingProp),
      runAlignment: _wrapAlignment(runAlignmentStr),
      runSpacing: asDouble(runSpacingProp),
      crossAxisAlignment:
          _wrapCrossAlignment(crossAxisAlignmentStr),
      textDirection: _textDirection(textDirectionStr),
      verticalDirection:
          _verticalDirection(verticalDirectionStr),
      clipBehavior: _clipBehavior(clipBehaviorStr),
      children: factory.buildChildren(context, children),
    );
  }

  WrapAlignment _wrapAlignment(String? v) {
    switch (v) {
      case 'start':
        return WrapAlignment.start;
      case 'end':
        return WrapAlignment.end;
      case 'center':
        return WrapAlignment.center;
      case 'spaceBetween':
        return WrapAlignment.spaceBetween;
      case 'spaceAround':
        return WrapAlignment.spaceAround;
      case 'spaceEvenly':
        return WrapAlignment.spaceEvenly;
      default:
        return WrapAlignment.start;
    }
  }

  WrapCrossAlignment _wrapCrossAlignment(String? v) {
    switch (v) {
      case 'start':
        return WrapCrossAlignment.start;
      case 'end':
        return WrapCrossAlignment.end;
      case 'center':
        return WrapCrossAlignment.center;
      default:
        return WrapCrossAlignment.start;
    }
  }

  TextDirection? _textDirection(String? v) {
    switch (v) {
      case 'rtl':
        return TextDirection.rtl;
      case 'ltr':
        return TextDirection.ltr;
      default:
        return null;
    }
  }

  VerticalDirection _verticalDirection(String? v) {
    switch (v) {
      case 'up':
        return VerticalDirection.up;
      case 'down':
      default:
        return VerticalDirection.down;
    }
  }

  Clip _clipBehavior(String? v) {
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
        return Clip.none;
    }
  }
}
