import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class SliverAppBarParser extends WidgetParser {
  @override
  String get type => 'SliverAppBar';

  @override
  void dispose(int nodeId) {}

  @override
  void onCommand(String refId, String method, dynamic args) {}

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final bottomDsl = props['bottom'];
    PreferredSizeWidget? bottom;
    if (bottomDsl != null) {
      final bottomWidget = factory.build(context, bottomDsl);
      if (bottomWidget is PreferredSizeWidget) {
        bottom = bottomWidget;
      } else {
        // Fallback to PreferredSize if not a PreferredSizeWidget
        bottom = PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: bottomWidget,
        );
      }
    }

    return SliverAppBar(
      title: factory.build(context, props['title']),
      leading: factory.build(context, props['leading']),
      actions: factory.buildChildren(context, props['actions']),
      expandedHeight: WidgetUtils.sizeNum(props['expandedHeight']),
      toolbarHeight:
          WidgetUtils.sizeNum(props['toolbarHeight']) ?? kToolbarHeight,
      pinned: props['pinned'] ?? false,
      floating: props['floating'] ?? false,
      snap: props['snap'] ?? false,
      backgroundColor:
          WidgetUtils.colorFromHex(props['backgroundColor'] as String?),
      elevation: WidgetUtils.sizeNum(props['elevation']),
      bottom: bottom,
      flexibleSpace: children != null
          ? FlexibleSpaceBar(
              background: factory.buildChildren(context, children).firstOrNull,
            )
          : null,
    );
  }
}
