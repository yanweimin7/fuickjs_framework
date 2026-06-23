import 'package:flutter/material.dart';

import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

/// AnimatedSize：子节点尺寸变化时自动插值过渡。
/// 对应 CSS `transition: width/height` 的部分语义（但需要子节点显式改变 size）。
class AnimatedSizeParser extends WidgetParser {
  @override
  String get type => 'AnimatedSize';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final durationMs = asInt(props['duration'] ?? 300);
    final reverseDurationMs = asIntOrNull(props['reverseDuration']);
    final curve = WidgetUtils.parseCurve(props['curve'] as String?);
    final alignment = WidgetUtils.alignment(props['alignment'] as String?);

    // 注：`axis` 字段在 Flutter 3.30+ 才被加入 AnimatedSize 构造器。
    // 当前框架以 Flutter 3.27.3 为基准，构造时不传入 axis，
    // 业务方传入的 axis 字段会被忽略（保留 DSL 以便后续升级）。
    return AnimatedSize(
      duration: Duration(milliseconds: durationMs),
      reverseDuration: reverseDurationMs != null
          ? Duration(milliseconds: reverseDurationMs)
          : null,
      curve: curve,
      alignment: alignment ?? Alignment.center,
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
