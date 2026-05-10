import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../logger.dart';
import '../widgets/widget_utils.dart';
import 'fuick_app_controller.dart';
import 'fuick_page.dart';
import 'fuick_page_view.dart';

/// 宿主选择 FuickJS 页面路由的转场动画。
enum FuickPageTransition {
  /// iOS 原生右滑（默认，支持左滑返回手势）
  cupertino,

  /// Material 3 缩放+淡入（无左滑手势）
  materialZoom,

  /// Android 经典 Material 底部淡入上浮（无左滑手势）
  fadeUpwards,

  /// 跟随平台自适应（iOS → cupertino，Android → zoom）
  platformAdaptive,

  /// 无动画
  none,
}

class FuickNavigationDelegate {
  final FuickAppController controller;
  final Map<int, GlobalKey<NavigatorState>> _navigators = {};
  final Map<int, BuildContext> _pageContexts = {};

  /// 宿主集成第三方路由（go_router / auto_route 等）时的 root push 钩子。
  /// 未设置时回退到 Navigator.of(context, rootNavigator: true)。
  /// 静态属性，宿主 app 启动时设置一次即可，不会被 FuickAppView 覆盖。
  static Future<dynamic> Function(String path, Map<String, dynamic> params)?
      onRootPush;

  /// 页面 DSL 尚未就绪时的占位背景色
  Color loadingBackgroundColor = const Color(0xFFFFFFFF);

  /// 页面转场动画类型，默认 cupertino（iOS 右滑，支持左滑返回手势）
  FuickPageTransition pageTransition = FuickPageTransition.cupertino;

  List<BuildContext> get pageContexts => _pageContexts.values.toList();

  FuickNavigationDelegate(this.controller);

  void registerNavigator(int pageId, GlobalKey<NavigatorState> key) {
    _navigators[pageId] = key;
  }

  void registerPageContext(int pageId, BuildContext context) {
    _pageContexts[pageId] = context;
  }

  void unregisterNavigator(int pageId) {
    _navigators.remove(pageId);
    _pageContexts.remove(pageId);
  }

  GlobalKey<NavigatorState>? getNavigatorKey(int? pageId) {
    if (pageId != null && _navigators.containsKey(pageId)) {
      return _navigators[pageId];
    }
    return _navigators.isNotEmpty ? _navigators.values.last : null;
  }

  Future<dynamic> pushWithPath(String path, Map<String, dynamic> params,
      {int? pageId, bool rootNavigator = false}) async {
    return _push(path, params, pageId: pageId, rootNavigator: rootNavigator);
  }

  Future<dynamic> pushReplacementWithPath(
      String path, Map<String, dynamic> params,
      {int? pageId, bool rootNavigator = false}) async {
    return _push(path, params,
        pageId: pageId, replacement: true, rootNavigator: rootNavigator);
  }

  Future<dynamic> _push(String path, Map<String, dynamic> params,
      {int? pageId,
      bool replacement = false,
      bool rootNavigator = false}) async {
    if (rootNavigator) {
      if (onRootPush != null) {
        try {
          return onRootPush!(path, params);
        } catch (e) {
          logger.w('onRootPush failed, fallback to root navigator: $e');
        }
      }
      final navKey = getNavigatorKey(pageId);
      final nav = navKey?.currentState;
      if (nav != null) {
        try {
          final rootNav = Navigator.of(nav.context, rootNavigator: true);
          final prewarmEntry = controller.claimPrewarm(path, params);
          final id = prewarmEntry?.pageId ?? nextPageId;
          controller.page.startTransition(id);
          final route = _createRoute(nav.context, path, params, id);
          final duration = const Duration(milliseconds: 350);
          Future.delayed(duration, () {
            controller.page.isTransitioning = false;
          });
          return replacement
              ? rootNav.pushReplacement(route)
              : rootNav.push(route);
        } catch (e) {
          logger.w('Failed to push to root navigator: $e');
        }
      }
      return null;
    }

    final navKey = getNavigatorKey(pageId);
    final nav = navKey?.currentState;
    if (nav == null) return null;

    final prewarmEntry = controller.claimPrewarm(path, params);
    final id = prewarmEntry?.pageId ?? nextPageId;
    controller.page.startTransition(id);
    registerNavigator(id, navKey!);

    final route = _createRoute(nav.context, path, params, id);
    final duration = const Duration(milliseconds: 350);
    Future.delayed(duration, () {
      controller.page.isTransitioning = false;
    });
    return replacement ? nav.pushReplacement(route) : nav.push(route);
  }

  Route _createRoute(BuildContext context, String path,
      Map<String, dynamic> params, int pageId) {
    final page = FuickPage(
      pageId: pageId,
      controller: controller,
      routeInfo: RouteInfo(path, params),
      loadingBackgroundColor: loadingBackgroundColor,
    );
    final settings = RouteSettings(name: path);
    final presentation = params['presentation'];

    if (presentation == 'dialog') {
      return DialogRoute(
          context: context,
          settings: settings,
          useSafeArea: false,
          builder: (_) => page);
    } else if (presentation == 'bottomSheet') {
      final screenHeight = MediaQuery.of(context).size.height;
      final rawMin = (params['minHeight'] as num?)?.toDouble();
      final rawMax = (params['maxHeight'] as num?)?.toDouble();
      final minHeight = rawMin != null
          ? (rawMin <= 1.0 ? screenHeight * rawMin : rawMin)
          : 0.0;
      final maxHeight = rawMax != null
          ? (rawMax <= 1.0 ? screenHeight * rawMax : rawMax)
          : screenHeight * 0.9;

      final bgColor = params['backgroundColor'] as String?;
      return ModalBottomSheetRoute(
        settings: settings,
        isScrollControlled: true,
        backgroundColor: bgColor != null
            ? WidgetUtils.colorFromHex(bgColor) ??
                Theme.of(context).dialogTheme.backgroundColor ??
                Theme.of(context).colorScheme.surface
            : Theme.of(context).dialogTheme.backgroundColor ??
                Theme.of(context).colorScheme.surface,
        constraints: BoxConstraints(
          minHeight: minHeight,
          maxHeight: maxHeight,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => SizedBox(
          width: MediaQuery.of(_).size.width,
          child: page,
        ),
      );
    }

    switch (pageTransition) {
      case FuickPageTransition.none:
        return PageRouteBuilder(
          settings: settings,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, __, ___) => page,
        );
      case FuickPageTransition.cupertino:
        return CupertinoPageRoute(settings: settings, builder: (_) => page);
      case FuickPageTransition.platformAdaptive:
        return MaterialPageRoute(settings: settings, builder: (_) => page);
      case FuickPageTransition.fadeUpwards:
        return _FuickPageRoute(
          settings: settings,
          child: page,
          builder: const FadeUpwardsPageTransitionsBuilder(),
        );
      case FuickPageTransition.materialZoom:
        return _FuickPageRoute(
          settings: settings,
          child: page,
          builder: const ZoomPageTransitionsBuilder(),
        );
    }
  }

  void pop({int? pageId, dynamic result}) {
    final nav = getNavigatorKey(pageId)?.currentState;
    if (nav == null) return;

    if (nav.canPop()) {
      nav.pop(result);
    } else {
      try {
        Navigator.of(nav.context, rootNavigator: true).pop(result);
      } catch (_) {}
    }
  }

  void popTo(String name, {int? pageId}) {
    getNavigatorKey(pageId)
        ?.currentState
        ?.popUntil((route) => route.settings.name == name);
  }

  /// 弹出所有路由，回到根页面（用于 reLaunch）
  void popAll({int? pageId}) {
    getNavigatorKey(pageId)?.currentState?.popUntil((route) => route.isFirst);
  }

  /// 切换 TabBar（通知 tabbar 状态变化，Phase 1 仅做 popAll + push）
  void switchTab(String path) {
    // 回到根路由
    popAll();
    // Phase 2: 支持真正的 TabBar 状态切换
  }
}

/// Material 系转场动画的通用 PageRoute（不受平台自适应影响，无左滑手势）
class _FuickPageRoute<T> extends PageRoute<T> {
  _FuickPageRoute({
    required this.child,
    required this.builder,
    super.settings,
  });

  final Widget child;
  final PageTransitionsBuilder builder;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) =>
      child;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget child) =>
      builder.buildTransitions(
          this, context, animation, secondaryAnimation, child);
}
