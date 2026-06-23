import 'package:flutter/material.dart';

import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

/// IndexedStack：所有子节点都构建，但只显示指定 index 的那个。
/// 适合做"切换不重建"型的 Tab 内容（与 PageView 配对时常用于底部 Tab）。
class IndexedStackParser extends WidgetParser {
  @override
  String get type => 'IndexedStack';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final index = asIntOrNull(props['index']) ?? 0;
    final alignment = WidgetUtils.alignment(props['alignment'] as String?);
    final sizing = props['sizing'] as String? ?? 'stack';
    final StackFit fit = sizing == 'loose' ? StackFit.loose : StackFit.expand;

    return IndexedStack(
      index: index,
      alignment: alignment ?? AlignmentDirectional.topStart,
      sizing: fit,
      children: factory.buildChildren(context, children),
    );
  }
}
