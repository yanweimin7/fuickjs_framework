import 'package:flutter/material.dart';

import '../../utils/extensions.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

/// CSS `outline` 实现：在子 Widget 外侧绘制一圈边框。
/// Flutter 无原生 outline，用 Padding + DecoratedBox 模拟：
///   外层 DecoratedBox 绘制边框，内层 Padding 留出 offset 间距。
///
/// Props:
///   width  : double — 描边宽度（默认 1）
///   color  : String — 描边颜色（默认 #000000）
///   style  : String — 目前仅支持 solid（Flutter 限制）
///   offset : double — 描边与元素的间距（默认 0）
class DecoratedBoxOutlineParser extends WidgetParser {
  @override
  String get type => 'DecoratedBoxOutline';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final width = asDoubleOrNull(props['width']) ?? 1.0;
    final color = WidgetUtils.colorFromHex(props['color'] as String?) ?? Colors.black;
    final offset = asDoubleOrNull(props['offset']) ?? 0.0;

    final child = factory.buildFirstChild(context, children, type);

    // offset > 0 → Padding between child and outline border
    final inner = offset > 0 ? Padding(padding: EdgeInsets.all(offset), child: child) : child;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color, width: width),
      ),
      position: DecorationPosition.foreground,
      child: inner,
    );
  }
}
