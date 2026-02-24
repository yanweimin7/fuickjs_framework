import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../engine/fuick_app_context.dart';
import '../engine/fuick_app_context_manager.dart';
import '../logger.dart';
import 'fuick_app_controller.dart';
import 'fuick_page_view.dart';

class FuickAppView extends StatefulWidget {
  final String appName;
  final String? debugBusinessCode;
  final String? initialRoute;
  final Map<String, dynamic>? initialParams;

  const FuickAppView({
    super.key,
    required this.appName,
    this.debugBusinessCode,
    this.initialRoute,
    this.initialParams,
  });

  @override
  State<FuickAppView> createState() => _FuickAppViewState();
}

class _FuickAppViewState extends State<FuickAppView> {
  late int rootPageId = nextPageId;
  bool _canInnerPop = false;
  bool _isReady = false;
  FuickAppContext? appContext;

  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  late final NavigatorObserver _observer = _FuickNavigatorObserver(() {
    if (mounted) {
      final canPop = _navKey.currentState?.canPop() ?? false;
      if (canPop != _canInnerPop) {
        setState(() {
          _canInnerPop = canPop;
        });
      }
    }
  });

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
      currentContext.isReady.addListener(() {
        if (mounted && currentContext.isReady.value) {
          _setupWithContext(currentContext);
        }
      });
    }
  }

  void _setupWithContext(FuickAppContext context) {
    if (!mounted) return;
    context.appController.registerNavigator(rootPageId, _navKey);
    context.appController.onCloseContainer[rootPageId] = (result) {
      if (mounted) {
        Navigator.of(this.context).pop(result);
      }
    };
    setState(() {
      _isReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Center(child: CupertinoActivityIndicator());
    }
    return PopScope(
      canPop: !_canInnerPop,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final NavigatorState? nav = _navKey.currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        }
      },
      child: Navigator(
        key: _navKey,
        observers: [_observer],
        onGenerateInitialRoutes: (NavigatorState nav, String initialRoute) {
          return [
            CupertinoPageRoute(
              builder: (_) => FuickPageView(
                pageId: rootPageId,
                controller: appContext!.appController,
                routeInfo: RouteInfo(
                    widget.initialRoute ?? '/', widget.initialParams ?? {}),
              ),
            ),
          ];
        },
      ),
    );
  }

  @override
  void dispose() {
    appContext?.appController.unregisterNavigator(rootPageId);
    appContext?.appController.onCloseContainer.remove(rootPageId);
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
