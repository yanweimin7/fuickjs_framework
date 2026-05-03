import 'package:flutter/material.dart';

import 'fuick_app_controller.dart';
import 'fuick_page_view.dart';

class FuickPage extends StatefulWidget {
  final int pageId;
  final FuickAppController controller;
  final RouteInfo routeInfo;
  final Color loadingBackgroundColor;

  const FuickPage({
    super.key,
    required this.pageId,
    required this.controller,
    required this.routeInfo,
    this.loadingBackgroundColor = const Color(0xFFFFFFFF),
  });

  @override
  State<FuickPage> createState() => _FuickAppPageState();
}

class _FuickAppPageState extends State<FuickPage> {
  @override
  void dispose() {
    widget.controller.unregisterNavigator(widget.pageId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.controller.registerPageContext(widget.pageId, context);
    return FuickPageView(
      pageId: widget.pageId,
      controller: widget.controller,
      routeInfo: widget.routeInfo,
      loadingBackgroundColor: widget.loadingBackgroundColor,
    );
  }
}
