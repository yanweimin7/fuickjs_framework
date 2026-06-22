import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

/// 静态终态版的 PositionedTransition：把 UI 端传入的 `end` RelativeRect
/// 用 `AlwaysStoppedAnimation` 包装后交给 Flutter，常显 end 位置。
/// 真正的过渡动画请在外层用 TweenAnimationBuilder / AnimatedBuilder 包裹。
class PositionedTransitionParser extends WidgetParser {
  @override
  String get type => 'PositionedTransition';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    RelativeRect rect = const RelativeRect.fromLTRB(0, 0, 0, 0);
    final end = props['end'];
    if (end is Map) {
      rect = RelativeRect.fromLTRB(
        asDoubleOrNull(end['left']) ?? 0.0,
        asDoubleOrNull(end['top']) ?? 0.0,
        asDoubleOrNull(end['right']) ?? 0.0,
        asDoubleOrNull(end['bottom']) ?? 0.0,
      );
    }
    return PositionedTransition(
      rect: AlwaysStoppedAnimation<RelativeRect>(rect),
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
