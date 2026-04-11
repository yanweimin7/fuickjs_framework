import 'package:flutter/material.dart';
import '../widget_factory.dart';
import 'widget_parser.dart';

class SliverToBoxAdapterParser extends WidgetParser {
  @override
  String get type => 'SliverToBoxAdapter';

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
    final List<Widget> builtChildren = factory.buildChildren(context, children);
    return SliverToBoxAdapter(
      child: builtChildren.isNotEmpty ? builtChildren.first : null,
    );
  }
}
