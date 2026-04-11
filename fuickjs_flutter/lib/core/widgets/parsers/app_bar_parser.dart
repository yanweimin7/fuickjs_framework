import 'package:flutter/material.dart';

import '../../container/fuick_app_controller.dart';
import '../../container/fuick_page_view.dart';
import '../../logger.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class AppBarParser extends WidgetParser {
  @override
  String get type => 'AppBar';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final titleDsl = props['title'];
    final leadingDsl = props['leading'];
    final actionsDsl = props['actions'];
    final bottomDsl = props['bottom'];
    final String? backgroundColorProp = props['backgroundColor'] as String?;
    final String? foregroundColorProp = props['foregroundColor'] as String?;
    final bool? centerTitleProp = props['centerTitle'] as bool?;
    final dynamic elevationProp = props['elevation'];

    List<Widget>? actions;
    if (actionsDsl is List) {
      actions = actionsDsl
          .map((e) => e != null ? factory.build(context, e) : null)
          .whereType<Widget>()
          .toList();
    } else if (actionsDsl != null) {
      final action = factory.build(context, actionsDsl);
      actions = [action];
    }

    PreferredSizeWidget? bottom;
    if (bottomDsl != null) {
      final bottomWidget = factory.build(context, bottomDsl);
      bottom = _wrapPreferredSize(bottomWidget);
    }

    final ctrl = FuickAppScope.find(context);
    final pageScope = FuickPageScope.find(context);
    final innerNav =
        ctrl?.navigation.getNavigatorKey(pageScope?.pageId)?.currentState;
    final canInnerPop = innerNav?.canPop() ?? false;
    final canPopRoot = Navigator.of(context, rootNavigator: true).canPop();

    return AppBar(
      automaticallyImplyLeading: true,
      title: titleDsl != null ? factory.build(context, titleDsl) : null,
      leading: leadingDsl != null
          ? factory.build(context, leadingDsl)

              : null,
      actions: actions,
      bottom: bottom,
      backgroundColor: WidgetUtils.colorFromHex(backgroundColorProp),
      foregroundColor: WidgetUtils.colorFromHex(foregroundColorProp),
      centerTitle: centerTitleProp,
      elevation: WidgetUtils.sizeNum(elevationProp),
    );
  }

  PreferredSizeWidget? _wrapPreferredSize(Widget widget) {
    if (widget is PreferredSizeWidget) {
      return widget;
    }
    if (widget is KeyedSubtree) {
      final child = widget.child;
      if (child is PreferredSizeWidget) {
        return _PreferredSizeKeyedSubtree(key: widget.key, child: child);
      }
    }
    // If it's not a PreferredSizeWidget, wrap it with a default size
    // TabBar default height with icon and text is usually around 72.0
    return PreferredSize(
      preferredSize: const Size.fromHeight(48.0),
      child: widget,
    );
  }
}

class _PreferredSizeKeyedSubtree extends KeyedSubtree
    implements PreferredSizeWidget {
  const _PreferredSizeKeyedSubtree({
    super.key,
    required PreferredSizeWidget super.child,
  });

  @override
  Size get preferredSize => (child as PreferredSizeWidget).preferredSize;
}
