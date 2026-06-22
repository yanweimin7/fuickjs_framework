import 'package:flutter/material.dart';
import '../widget_factory.dart';
import 'widget_parser.dart';

class HeroParser extends WidgetParser {
  @override
  String get type => 'Hero';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final tag = (props['tag'] as String?) ?? '';
    var child = factory.buildFirstChild(context, children, type);
    if (tag.isEmpty) {
      // tag 缺失时，Hero 无法匹配，退化为渲染首个子节点，避免抛错。
      return child;
    }
    // 关键：用 Material(透明) 包裹子节点，确保 Hero 飞行体（flightShuttle）
    // 渲染时永远处在 Material 上下文中。
    // 若没有 Material，Hero 在某些页面（特别是 Scaffolds 没有 body 时、
    // 或自定义透明容器树中）会抛 'No Material widget found' 异常或静默失效。
    child = Material(type: MaterialType.transparency, child: child);
    return Hero(tag: tag, child: child);
  }
}
