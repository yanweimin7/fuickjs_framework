import 'package:flutter/material.dart';

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

    return AppBar(
      automaticallyImplyLeading: false,
      title: titleDsl != null ? factory.build(context, titleDsl) : null,
      leading: leadingDsl != null
          ? factory.build(context, leadingDsl)
          : (ModalRoute.of(context)?.canPop ?? false
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null),
      actions: actions,
      bottom: bottom,
      backgroundColor: WidgetUtils.colorFromHex(
        props['backgroundColor'] as String?,
      ),
      foregroundColor: WidgetUtils.colorFromHex(
        props['foregroundColor'] as String?,
      ),
      centerTitle: props['centerTitle'] as bool?,
      elevation: WidgetUtils.sizeNum(props['elevation']),
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
  _PreferredSizeKeyedSubtree({
    required Key? key,
    required PreferredSizeWidget child,
  }) : super(key: key, child: child);

  @override
  Size get preferredSize => (child as PreferredSizeWidget).preferredSize;
}
