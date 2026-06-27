import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

/// PositionedTransition：支持静态终态（默认）与隐式动画（传 duration 时）。
///
/// - 未传 `duration`：把 `end` RelativeRect 用 `AlwaysStoppedAnimation` 包装，
///   常显 end 位置（向后兼容）。
/// - 传 `duration`：通过 `TweenAnimationBuilder` 在 `begin` 与 `end` 之间插值，
///   实现 RelativeRect 平滑过渡。
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
    final end = _parseRect(props['end']);
    final beginMap = props['begin'];
    final begin = beginMap is Map ? _parseRect(beginMap) : end;
    final durationMs = asIntOrNull(props['duration']);
    final child = factory.buildFirstChild(context, children, type);

    if (durationMs == null || durationMs <= 0) {
      return PositionedTransition(
        rect: AlwaysStoppedAnimation<RelativeRect>(end),
        child: child,
      );
    }

    return TweenAnimationBuilder<RelativeRect>(
      tween: RelativeRectTween(begin: begin, end: end),
      duration: Duration(milliseconds: durationMs),
      curve: WidgetUtils.parseCurve(props['curve'] as String?),
      builder: (context, value, _) {
        return PositionedTransition(
          rect: AlwaysStoppedAnimation<RelativeRect>(value),
          child: child,
        );
      },
    );
  }

  static RelativeRect _parseRect(dynamic v) {
    if (v is! Map) return const RelativeRect.fromLTRB(0, 0, 0, 0);
    return RelativeRect.fromLTRB(
      asDoubleOrNull(v['left']) ?? 0.0,
      asDoubleOrNull(v['top']) ?? 0.0,
      asDoubleOrNull(v['right']) ?? 0.0,
      asDoubleOrNull(v['bottom']) ?? 0.0,
    );
  }
}
