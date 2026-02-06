import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class SliverPersistentHeaderParser extends WidgetParser {
  @override
  String get type => 'SliverPersistentHeader';

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
    final double minExtent = WidgetUtils.sizeNum(props['minExtent']) ?? 0;
    final double maxExtent = WidgetUtils.sizeNum(props['maxExtent']) ?? minExtent;
    final bool pinned = props['pinned'] ?? false;
    final bool floating = props['floating'] ?? false;

    return SliverPersistentHeader(
      pinned: pinned,
      floating: floating,
      delegate: _FuickPersistentHeaderDelegate(
        minExtent: minExtent,
        maxExtent: maxExtent,
        child: factory.buildFirstChild(context, children, type),
      ),
    );
  }
}

class _FuickPersistentHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minExtent;
  final double maxExtent;
  final Widget child;

  _FuickPersistentHeaderDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.child,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _FuickPersistentHeaderDelegate oldDelegate) {
    return oldDelegate.minExtent != minExtent ||
        oldDelegate.maxExtent != maxExtent ||
        oldDelegate.child != child;
  }
}
