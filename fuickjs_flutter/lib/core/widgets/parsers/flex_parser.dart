import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class FlexParser extends WidgetParser {
  @override
  String get type => 'Flex';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final String? directionStr = props['direction'] as String?;
    final String? mainAxisAlignmentStr = props['mainAxisAlignment'] as String?;
    final String? crossAxisAlignmentStr =
        props['crossAxisAlignment'] as String?;
    final String? mainAxisSizeStr = props['mainAxisSize'] as String?;
    final String? textDirectionStr = props['textDirection'] as String?;
    final String? verticalDirectionStr = props['verticalDirection'] as String?;
    final String? textBaselineStr = props['textBaseline'] as String?;
    final String? clipBehaviorStr = props['clipBehavior'] as String?;

    final direction = WidgetUtils.axis(directionStr);
    final mainAxisAlignment = WidgetUtils.mainAxis(mainAxisAlignmentStr);
    final crossAxisAlignment = WidgetUtils.crossAxis(crossAxisAlignmentStr);
    final mainAxisSize = WidgetUtils.mainAxisSize(mainAxisSizeStr);

    TextDirection? textDirection;
    if (textDirectionStr == 'rtl') textDirection = TextDirection.rtl;
    if (textDirectionStr == 'ltr') textDirection = TextDirection.ltr;

    VerticalDirection verticalDirection = VerticalDirection.down;
    if (verticalDirectionStr == 'up') verticalDirection = VerticalDirection.up;

    TextBaseline? textBaseline;
    if (textBaselineStr == 'alphabetic') {
      textBaseline = TextBaseline.alphabetic;
    } else if (textBaselineStr == 'ideographic') {
      textBaseline = TextBaseline.ideographic;
    }

    final clipBehavior = WidgetUtils.clipBehavior(clipBehaviorStr) ?? Clip.none;

    return WidgetUtils.wrapPadding(
      props,
      Flex(
        direction: direction,
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        textDirection: textDirection,
        verticalDirection: verticalDirection,
        textBaseline: textBaseline,
        clipBehavior: clipBehavior,
        children: factory.buildChildren(context, children),
      ),
    );
  }
}
