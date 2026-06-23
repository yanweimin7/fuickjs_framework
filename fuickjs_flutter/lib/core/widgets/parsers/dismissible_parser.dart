import 'package:flutter/material.dart';

import '../../container/fuick_action.dart';
import '../widget_factory.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

/// Dismissible：可滑动删除/归档的列表项。
/// 子节点必须是单一子 widget（通常是 Container/Card）。
class DismissibleParser extends WidgetParser {
  @override
  String get type => 'Dismissible';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final dynamic onDismissed = props['onDismissed'];
    final dynamic onConfirmDismiss = props['onConfirmDismiss'];
    final dynamic onResize = props['onResize'];
    final dynamic onUpdate = props['onUpdate'];

    final keyStr = props['key'] as String?;
    final key = keyStr != null ? ValueKey(keyStr) : UniqueKey();

    final direction = _dismissDirection(props['direction'] as String?);
    final resizeMs = asIntOrNull(props['resizeDuration']) ?? 300;
    final movementMs = asIntOrNull(props['movementDuration']) ?? 200;
    final crossAxisEnd = asDoubleOrNull(props['crossAxisEndOffset']) ?? 0.0;

    final background = _buildBackground(context, props['background'], factory);
    final secondaryBackground =
        _buildBackground(context, props['secondaryBackground'], factory);

    return Dismissible(
      key: key,
      direction: direction,
      resizeDuration: Duration(milliseconds: resizeMs),
      movementDuration: Duration(milliseconds: movementMs),
      crossAxisEndOffset: crossAxisEnd,
      background: background,
      secondaryBackground: secondaryBackground,
      onDismissed: onDismissed != null
          ? (DismissDirection dir) {
              FuickAction.event(context, onDismissed, value: dir.name);
            }
          : null,
      onUpdate: onUpdate != null
          ? (DismissUpdateDetails details) {
              // 注：`DismissUpdateDetails.reason` 在 Flutter 3.30+ 才有，
              // 旧版本仅暴露 direction/reached/progress 字段。
              // 兼容做法：把 direction.name 作为 reason 透传给业务方。
              FuickAction.event(context, onUpdate,
                  value: details.direction.name);
            }
          : null,
      onResize: onResize != null
          ? () => FuickAction.event(context, onResize)
          : null,
      confirmDismiss: onConfirmDismiss != null
          ? (DismissDirection dir) async {
              // Synchronous fallback: dispatch event, return true to dismiss.
              FuickAction.event(context, onConfirmDismiss, value: dir.name);
              return true;
            }
          : null,
      child: factory.buildFirstChild(context, children, type),
    );
  }

  DismissDirection _dismissDirection(String? v) {
    switch (v) {
      case 'horizontal':
        return DismissDirection.horizontal;
      case 'vertical':
        return DismissDirection.vertical;
      case 'endToStart':
        return DismissDirection.endToStart;
      case 'startToEnd':
        return DismissDirection.startToEnd;
      case 'up':
        return DismissDirection.up;
      case 'down':
        return DismissDirection.down;
      case 'none':
        return DismissDirection.none;
      default:
        return DismissDirection.horizontal;
    }
  }

  /// `background` / `secondaryBackground` 是 DSL 子树，转成 Widget。
  Widget? _buildBackground(
      BuildContext context, dynamic dsl, WidgetFactory factory) {
    if (dsl == null) return null;
    if (dsl is Map) {
      return factory.build(context, dsl);
    }
    if (dsl is List && dsl.isNotEmpty) {
      return factory.build(context, dsl.first);
    }
    return null;
  }
}
