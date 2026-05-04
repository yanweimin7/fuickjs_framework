import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../engine/fuick_app_context.dart';
import '../engine/fuick_app_context_manager.dart';
import '../logger.dart';
import 'fuick_app_controller.dart';
import 'fuick_navigation_delegate.dart';
import 'fuick_page.dart';
import 'fuick_page_view.dart';

class FuickAppView extends StatefulWidget {
  final String appName;
  final String? debugBusinessCode;
  final String? initialRoute;
  final Map<String, dynamic>? initialParams;
  /// 宿主集成第三方路由（go_router / auto_route 等）时的 root push 钩子，可选。
  final Future<dynamic> Function(String path, Map<String, dynamic> params)?
      onRootPush;

  /// 页面转场动画类型，默认 cupertino
  final FuickPageTransition pageTransition;

  /// 页面 DSL 尚未就绪时的占位背景色，默认白色
  final Color loadingBackgroundColor;

  const FuickAppView({
    super.key,
    required this.appName,
    this.debugBusinessCode,
    this.initialRoute,
    this.initialParams,
    this.onRootPush,
    this.pageTransition = FuickPageTransition.cupertino,
    this.loadingBackgroundColor = const Color(0xFFFFFFFF),
  });

  @override
  State<FuickAppView> createState() => _FuickAppViewState();
}

class _FuickAppViewState extends State<FuickAppView> {
  late int rootPageId = nextPageId;
  bool _canInnerPop = false;
  bool _isReady = false;
  FuickAppContext? appContext;

  // 保存 isReady listener 引用，以便在 dispose 时移除
  VoidCallback? _isReadyListener;
  FuickAppContext? _pendingListenContext;

  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  late final NavigatorObserver _observer = _FuickNavigatorObserver(() {
    if (mounted) {
      final canPop = _canInnerNavigatorPop();
      if (canPop != _canInnerPop) {
        setState(() {
          _canInnerPop = canPop;
        });
      }
    }
  });

  bool _canInnerNavigatorPop() {
    final nav = _navKey.currentState;
    if (nav == null) return false;
    if (!nav.canPop()) return false;
    // 检查内层当前 route 是否允许 pop。
    // PopScope(canPop:false) 会让 route.popDisposition == doNotPop，
    // 此时外层 PopScope 也不应该允许 pop（否则系统返回键绕过了内层 PopScope）。
    Route<dynamic>? currentRoute;
    nav.popUntil((route) {
      currentRoute = route;
      return true; // 立即停止，只是为了拿到当前 route
    });
    if (currentRoute != null &&
        currentRoute!.popDisposition == RoutePopDisposition.doNotPop) {
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _initContext();
  }

  Future<void> _initContext() async {
    appContext = FuickAppContextManager().getContext(widget.appName);
    if (appContext == null) {
      appContext = FuickAppContext(
        appName: widget.appName,
        debugBusinessCode: widget.debugBusinessCode,
      );
      FuickAppContextManager().registerContext(widget.appName, appContext!);
    } else {
      FuickAppContextManager().retainContext(widget.appName);
    }
    // 如果上下文未初始化，进行初始化
    if (!appContext!.isReady.value) {
      await appContext!.init();
    }

    // 2. 此时 context 已经不为空 (要么是外部传入，要么是 Manager 获取/创建)
    final currentContext = appContext;
    if (currentContext == null) {
      logger.e('[FuickAppView] Context is null after initialization');
      return;
    }

    if (currentContext.isReady.value) {
      _setupWithContext(currentContext);
    } else {
      _pendingListenContext = currentContext;
      void listener() {
        if (currentContext.isReady.value) {
          currentContext.isReady.removeListener(_isReadyListener!);
          _isReadyListener = null;
          _pendingListenContext = null;
          if (mounted) _setupWithContext(currentContext);
        }
      }
      _isReadyListener = listener;
      currentContext.isReady.addListener(listener);
    }
  }

  void _setupWithContext(FuickAppContext context) {
    if (!mounted) return;
    context.appController.registerNavigator(rootPageId, _navKey);
    context.appController.navigation.onRootPush = widget.onRootPush;
    context.appController.navigation.pageTransition = widget.pageTransition;
    context.appController.navigation.loadingBackgroundColor =
        widget.loadingBackgroundColor;
    setState(() {
      _isReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return ColoredBox(
        color: widget.loadingBackgroundColor,
        child: Center(
          child: CupertinoActivityIndicator(
            radius: 14,
          ),
        ),
      );
    }
    return PopScope(
      // 仅当内层 Navigator 没有可 pop 的页面时，才允许外层 pop（退出整个容器）
      canPop: !_canInnerPop,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final NavigatorState? nav = _navKey.currentState;
        if (nav == null) return;
        if (nav.canPop()) {
          // 用 maybePop 代替 pop，让内层 PopScope(canPop:false) 能拦截
          nav.maybePop();
        }
      },
      child: Navigator(
        key: _navKey,
        observers: [_observer],
        onGenerateInitialRoutes: (NavigatorState nav, String initialRoute) {
          return [
            PageRouteBuilder(
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              pageBuilder: (_, __, ___) => FuickPage(
                pageId: rootPageId,
                controller: appContext!.appController,
                routeInfo: RouteInfo(
                    widget.initialRoute ?? '/', widget.initialParams ?? {}),
                loadingBackgroundColor: widget.loadingBackgroundColor,
              ),
            ),
          ];
        },
      ),
    );
  }

  @override
  void dispose() {
    // 移除 isReady listener，防止在 context 未就绪时 widget 已被销毁后仍触发
    if (_isReadyListener != null) {
      _pendingListenContext?.isReady.removeListener(_isReadyListener!);
      _isReadyListener = null;
      _pendingListenContext = null;
    }
    appContext?.appController.unregisterNavigator(rootPageId);
    FuickAppContextManager().releaseContext(widget.appName);
    super.dispose();
  }
}

class _FuickNavigatorObserver extends NavigatorObserver {
  final VoidCallback onStateChanged;

  _FuickNavigatorObserver(this.onStateChanged);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    onStateChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    onStateChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    onStateChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    onStateChanged();
  }
}
