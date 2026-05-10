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
  final FuickPageTransition pageTransition;
  final Color loadingBackgroundColor;
  final bool useAotCode;

  const FuickAppView({
    super.key,
    required this.appName,
    this.debugBusinessCode,
    this.initialRoute,
    this.initialParams,
    this.pageTransition = FuickPageTransition.cupertino,
    this.loadingBackgroundColor = const Color(0xFFFFFFFF),
    this.useAotCode = true,
  });

  @override
  State<FuickAppView> createState() => _FuickAppViewState();
}

class _FuickAppViewState extends State<FuickAppView> {
  late int rootPageId = nextPageId;
  bool _canInnerPop = false;
  bool _isReady = false;
  FuickAppContext? appContext;

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
    print('wine app view build');
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
      canPop: !_canInnerPop,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final NavigatorState? nav = _navKey.currentState;
        if (nav == null) return;
        if (nav.canPop()) {
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
