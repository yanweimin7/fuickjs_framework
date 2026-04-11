import 'package:flutter/material.dart';
import '../../utils/extensions.dart';
import '../fuick_node.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class RowParser extends WidgetParser {
  @override
  String get type => 'Row';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final String? mainAxisAlignmentStr = props['mainAxisAlignment'] as String?;
    final String? crossAxisAlignmentStr =
        props['crossAxisAlignment'] as String?;
    final String? mainAxisSizeStr = props['mainAxisSize'] as String?;
    final double? spacing = asDoubleOrNull(props['spacing']);

    final mainAxisAlignment = WidgetUtils.mainAxis(mainAxisAlignmentStr);
    final crossAxisAlignment = WidgetUtils.crossAxis(crossAxisAlignmentStr);
    final mainAxisSize = WidgetUtils.mainAxisSize(mainAxisSizeStr);

    List<Widget> childWidgets = _buildChildrenWithAlignSelf(context, children, factory);
    if (spacing != null && spacing > 0 && childWidgets.length > 1) {
      childWidgets = _interleaveSpacing(childWidgets, spacing);
    }

    return WidgetUtils.wrapPadding(
      props,
      Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        textBaseline: crossAxisAlignment == CrossAxisAlignment.baseline
            ? TextBaseline.alphabetic
            : null,
        children: childWidgets,
      ),
    );
  }

  /// 构建子 Widget，检查每个子节点的 alignSelf prop，
  /// Row 中 alignSelf 控制垂直方向（y 轴）
  List<Widget> _buildChildrenWithAlignSelf(
      BuildContext context, dynamic children, WidgetFactory factory) {
    if (children is! List) return factory.buildChildren(context, children);
    final result = <Widget>[];
    for (final child in children) {
      final Widget w;
      if (child is FuickNode) {
        w = factory.buildFromNode(context, child);
      } else {
        w = factory.build(context, child);
      }
      final alignSelf = _alignSelfProp(child);
      if (alignSelf != null) {
        result.add(Align(alignment: _rowAlignSelf(alignSelf), child: w));
      } else {
        result.add(w);
      }
    }
    return result;
  }

  String? _alignSelfProp(dynamic child) {
    if (child is FuickNode) return child.props['alignSelf'] as String?;
    if (child is Map && child['props'] is Map) {
      return child['props']['alignSelf'] as String?;
    }
    return null;
  }

  /// Row 子元素：alignSelf 控制 y 轴（垂直对齐）
  Alignment _rowAlignSelf(String alignSelf) {
    switch (alignSelf) {
      case 'flexStart': case 'start': return Alignment.topCenter;
      case 'flexEnd': case 'end': return Alignment.bottomCenter;
      case 'center': return Alignment.center;
      default: return Alignment.topCenter;
    }
  }

  List<Widget> _interleaveSpacing(List<Widget> children, double spacing) {
    final result = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(SizedBox(width: spacing));
      }
    }
    return result;
  }
}
