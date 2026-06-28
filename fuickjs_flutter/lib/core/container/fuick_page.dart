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
    // 注意：page context 的注册放在 _FuickScopeProviders.build 里（用 providers 下方的
    // Builder context 注册），这样 UIService.getTheme / getMediaQuery 中的
    // FuickThemeProvider.of / FuickMediaQueryProvider.of 才能沿父链命中 provider。
    return FuickPageView(
      pageId: widget.pageId,
      controller: widget.controller,
      routeInfo: widget.routeInfo,
      loadingBackgroundColor: widget.loadingBackgroundColor,
    );
  }
}
