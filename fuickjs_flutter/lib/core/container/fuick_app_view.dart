import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../engine/fuick_app_context.dart';
import '../engine/fuick_app_context_manager.dart';
import '../fuick_config.dart';
import '../logger.dart';
import '../widgets/memory_monitor_overlay.dart';
import '../widgets/red_box.dart';
import 'fuick_app_controller.dart';
import 'fuick_navigation_delegate.dart';
import 'fuick_page.dart';
import 'fuick_page_view.dart';

class FuickAppView extends StatefulWidget {
  final String appName;
  final String? debugBusinessCode;
  final Map<String, dynamic>? sourceMap;
  final String? cachedBundleRoot;
  final String? initialRoute;
  final Map<String, dynamic>? initialParams;
  final FuickPageTransition pageTransition;
  final Color loadingBackgroundColor;
  final bool useAotCode;

  /// 是否在右上角叠加 QuickJS 内存监控浮层。
  /// 开启后每 500ms 拉取一次 runtime 内存快照(malloc/used/jsFuncCode/atom/obj 等),
  /// 便于调试 JS 堆与引擎占用的变化。生产环境应保持 false。
  final bool showMemoryMonitor;

  const FuickAppView({
    super.key,
    required this.appName,
    this.debugBusinessCode,
    this.sourceMap,
    this.cachedBundleRoot,
    this.initialRoute,
    this.initialParams,
    this.pageTransition = FuickPageTransition.cupertino,
    this.loadingBackgroundColor = const Color(0xFFFFFFFF),
    this.useAotCode = true,
    this.showMemoryMonitor = false,
  });

  @override
  State<FuickAppView> createState() => _FuickAppViewState();
}

class _FuickAppViewState extends State<FuickAppView> {
  late int rootPageId = nextPageId;
  final ValueNotifier<bool> _canInnerPop = ValueNotifier(false);
  bool _isReady = false;
  FuickAppContext? appContext;

  VoidCallback? _isReadyListener;
  FuickAppContext? _pendingListenContext;

  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  // 每个 FuickAppView 持有自己的 RouteObserver 实例。
  // 历史上挂在 FuickAppController 单例上,导致两个 view 共享同一 observer 时
  // 触发 Navigator.initState 断言 'observer.navigator == null'。
  // 1 个 observer 只对应 1 个 Navigator(per-view 分配)。
  final RouteObserver<Route<dynamic>> _routeObserver =
      RouteObserver<Route<dynamic>>();

  late final NavigatorObserver _observer = _FuickNavigatorObserver(() {
    if (!mounted) return;
    final canPop = _canInnerNavigatorPop();
    if (canPop == _canInnerPop.value) return;
    if (mounted && canPop != _canInnerPop.value) {
      _canInnerPop.value = canPop;
    }
  });

  bool _canInnerNavigatorPop() {
    final nav = _navKey.currentState;
    if (nav == null) return false;
    if (!nav.canPop()) return false;
    Route<dynamic>? currentRoute;
    nav.popUntil((route) {
      currentRoute = route;
      return true;
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
        sourceMap: widget.sourceMap,
        cachedBundleRoot: widget.cachedBundleRoot,
        useAotCode: widget.useAotCode,
      );
      FuickAppContextManager().registerContext(widget.appName, appContext!);
    } else {
      FuickAppContextManager().retainContext(widget.appName);
    }

    if (!appContext!.isReady.value) {
      await appContext!.init();
    }

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
    final app = ValueListenableBuilder(
      valueListenable: _canInnerPop,
      builder: (_, __, child) => PopScope(
          canPop: !_canInnerPop.value,
          onPopInvokedWithResult: (bool didPop, dynamic result) async {
            if (didPop) return;
            final NavigatorState? nav = _navKey.currentState;
            if (nav == null) return;
            if (nav.canPop()) {
              nav.maybePop();
            }
          },
          child: child!),
      child: HeroControllerScope(
        // 必须：内层 Navigator 显式创建 HeroController。
        // 即使宿主 MaterialApp 已提供 HeroController，
        // 由于 inner Navigator 位于 MaterialApp 之内但不在其 heroController 管辖范围
        // （这是 Flutter Hero 实现的边界），push 时源/目标 Hero 无法匹配，
        // 表现就是 cupertino 滑动而 Hero 不飞。
        controller: HeroController(),
        child: FuickPageScope(
          pageId: rootPageId,
          routeObserver: _routeObserver,
          child: Navigator(
            key: _navKey,
            observers: [_observer, _routeObserver],
            onGenerateInitialRoutes: (NavigatorState nav, String initialRoute) {
              // 初始路由必须用带 transitionDuration 的 PageRoute，
              // 不能用 PageRouteBuilder(transitionDuration: zero)，
              // 否则 Hero flight 拿不到源路由 transition 曲线。
              return [
                CupertinoPageRoute<void>(
                  settings: RouteSettings(name: initialRoute),
                  builder: (_) => FuickPage(
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
        ),
      ),
    );
    // debug 模式下叠加红屏错误提示
    Widget result = FuickConfig().debug ? RedBoxOverlay(child: app) : app;
    if (widget.showMemoryMonitor) {
      result = Stack(
        children: [
          result,
          MemoryMonitorOverlay(appName: widget.appName),
        ],
      );
    }
    return result;
  }

  @override
  void dispose() {
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

// 放在你的路由文件里
class SimpleCupertinoPageRoute<T> extends PageRoute<T> {
  SimpleCupertinoPageRoute({
    required this.builder,
    super.settings,
    this.title,
  });

  final WidgetBuilder builder;
  final String? title;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return builder(context);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    // 关键修改：新页面滑入，旧页面不再有视差效果
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0), // 从右侧开始
        end: Offset.zero,
      ).animate(animation),
      child: child,
    );
  }
}
