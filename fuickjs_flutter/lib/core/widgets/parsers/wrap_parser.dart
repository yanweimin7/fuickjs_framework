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
    return Wrap(
      direction: WidgetUtils.axis(props['direction'] as String?),
      alignment: _wrapAlignment(props['alignment'] as String?),
      spacing: asDouble(props['spacing']),
      runAlignment: _wrapAlignment(props['runAlignment'] as String?),
      runSpacing: asDouble(props['runSpacing']),
      crossAxisAlignment:
          _wrapCrossAlignment(props['crossAxisAlignment'] as String?),
      textDirection: _textDirection(props['textDirection'] as String?),
      verticalDirection:
          _verticalDirection(props['verticalDirection'] as String?),
      clipBehavior: _clipBehavior(props['clipBehavior'] as String?),
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
