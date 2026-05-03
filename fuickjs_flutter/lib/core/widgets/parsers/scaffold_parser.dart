import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class ScaffoldParser extends WidgetParser {
  @override
  String get type => 'Scaffold';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final appBarDsl = props['appBar'];
    final bodyDsl = props['body'];
    final fabDsl = props['floatingActionButton'];
    final drawerDsl = props['drawer'];
    final endDrawerDsl = props['endDrawer'];
    final bottomNavigationBarDsl = props['bottomNavigationBar'];
    final bottomSheetDsl = props['bottomSheet'];
    final String? backgroundColorProp = props['backgroundColor'] as String?;

    Widget? body = bodyDsl != null ? factory.build(context, bodyDsl) : null;
    if (body == null && children != null) {
      body = factory.buildFirstChild(context, children, type);
    }

    Widget? appBarWidget =
        appBarDsl != null ? factory.build(context, appBarDsl) : null;
    PreferredSizeWidget? appBar;
    if (appBarWidget is PreferredSizeWidget) {
      appBar = appBarWidget;
    } else if (appBarWidget != null) {
      appBar = PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: appBarWidget,
      );
    }

    final bgColor = WidgetUtils.colorFromHex(backgroundColorProp);
    final scaffold = Scaffold(
      backgroundColor: bgColor,
      appBar: appBar,
      body: body,
      floatingActionButton:
          fabDsl != null ? factory.build(context, fabDsl) : null,
      drawer: drawerDsl != null ? factory.build(context, drawerDsl) : null,
      endDrawer:
          endDrawerDsl != null ? factory.build(context, endDrawerDsl) : null,
      bottomNavigationBar: bottomNavigationBarDsl != null
          ? factory.build(context, bottomNavigationBarDsl)
          : null,
      bottomSheet: bottomSheetDsl != null
          ? factory.build(context, bottomSheetDsl)
          : null,
    );
    // 用 ColoredBox 包裹，确保首帧即有正确背景色，避免 Material 颜色动画造成白屏闪烁
    if (bgColor != null) {
      return ColoredBox(color: bgColor, child: scaffold);
    }
    return scaffold;
  }
}
