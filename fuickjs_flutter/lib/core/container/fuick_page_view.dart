import 'package:flutter/cupertino.dart' hide widgetFactory;
import 'package:flutter/material.dart' show Theme;

import '../logger.dart';
import '../widgets/fuick_media_query_provider.dart';
import '../widgets/fuick_node.dart';
import '../widgets/fuick_theme_provider.dart';
import '../widgets/widget_factory.dart';
import 'fuick_app_controller.dart';

class RouteInfo {
  final String path;
  final Map<String, dynamic> params;

  RouteInfo(this.path, this.params);
}

class FuickPageView extends StatefulWidget {
  final int pageId;
  final FuickAppController controller;
  final RouteInfo routeInfo;
  final Color loadingBackgroundColor;

  const FuickPageView({
    super.key,
    required this.pageId,
    required this.controller,
    required this.routeInfo,
    this.loadingBackgroundColor = const Color(0xFFFFFFFF),
  });

  @override
  State<FuickPageView> createState() => _JsUiHostState();
}

class _JsUiHostState extends State<FuickPageView> with RouteAware {
  FuickNodeManager nodeManager = FuickNodeManager();
  FuickNode? rootNode;
  bool _hasRendered = false;
  bool _isVisible = false;
  bool _isFirstRender = true;
  bool _routeSubscribed = false;
  RouteObserver<Route<dynamic>>? _routeObserverRef;

  Widget? _cachedChild;
  FuickNode? _lastBuiltNode;

  @override
  void didUpdateWidget(FuickPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.pageId != widget.pageId) {
      _cachedChild = null;
      _lastBuiltNode = null;
      _routeSubscribed = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_routeSubscribed) {
      _routeSubscribed = true;
      _routeObserverRef = FuickPageScope.of(context)!.routeObserver;
      _routeObserverRef!.subscribe(this, ModalRoute.of(context)!);
    }
  }

  @override
  void dispose() {
    _routeObserverRef?.unsubscribe(this);
    _routeObserverRef = null;
    widget.controller.isBundleLoaded.removeListener(_checkAndRender);
    widget.controller.destroyPage(widget.pageId);
    widget.controller.onPageRender.remove(widget.pageId);
    widget.controller.onPagePatch.remove(widget.pageId);
    widget.controller.onPagePatchOps.remove(widget.pageId);
    widget.controller.page.removePendingUpdates(widget.pageId);
    super.dispose();
  }

  @override
  void didPush() {
    // 页面被推入时触发
    _notifyVisible();
  }

  @override
  void didPopNext() {
    // 上层页面出栈，当前页面重新可见
    _notifyVisible();
  }

  @override
  void didPushNext() {
    // 推入新页面，当前页面变得不可见
    _notifyInvisible();
  }

  @override
  void didPop() {
    // 当前页面出栈，变得不可见
    _notifyInvisible();
  }

  void _notifyVisible() {
    if (!_isVisible) {
      _isVisible = true;
      widget.controller.notifyLifecycle(widget.pageId, 'visible');
    }
  }

  void _notifyInvisible() {
    if (_isVisible) {
      _isVisible = false;
      widget.controller.notifyLifecycle(widget.pageId, 'invisible');
    }
  }

  void _handleRenderDsl(Map<String, dynamic> dsl) {
    final sw = Stopwatch()..start();
    if (mounted && _isVisible) {
      widget.controller.notifyLifecycle(widget.pageId, 'visible');
    }

    final newNode = nodeManager.createNode(dsl, nodeManager);
    sw.stop();

    if (rootNode != newNode && mounted) {
      rootNode = newNode;
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();

    // 先消费 prewarm entry，确定正确的 nodeManager
    final prewarm = widget.controller.page.consumeByPageId(widget.pageId);
    if (prewarm != null) {
      _hasRendered = true;
      if (prewarm.hasPrebuiltNodes) {
        nodeManager = prewarm.prebuiltNodeManager!;
        rootNode = prewarm.prebuiltRootNode!;
      } else if (prewarm.hasDsl) {
        final newNode = nodeManager.createNode(prewarm.dsl!, nodeManager);
        rootNode = newNode;
      } else {
        // 关键：等 prewarm 完成后，必须复用 prebuilt 节点（用于 Hero flight）。
        // 不能直接调 _handleRenderDsl，因为它会用新建的 nodeManager，
        // 浪费 prewarm 已经构建好的 prebuilt 节点。
        prewarm.future.then((_) {
          if (!mounted) return;
          if (prewarm.hasPrebuiltNodes) {
            setState(() {
              nodeManager = prewarm.prebuiltNodeManager!;
              rootNode = prewarm.prebuiltRootNode!;
            });
          } else if (prewarm.hasDsl) {
            _handleRenderDsl(prewarm.dsl!);
          }
        });
      }
    }

    // patch 回调：闭包捕获正确的 nodeManager
    widget.controller.onPagePatch[widget.pageId] = (patches) {
      nodeManager.applyPatches(patches, nodeManager);
    };
    widget.controller.onPagePatchOps[widget.pageId] = (ops) {
      nodeManager.applyOps(ops, nodeManager);
    };

    // 注册 render 回调（覆盖预渲染阶段的临时回调）
    widget.controller.onPageRender[widget.pageId] = _handleRenderDsl;

    widget.controller.page.flushPendingUpdates(widget.pageId);

    if (prewarm != null) {
      widget.controller.isBundleLoaded.addListener(_checkAndRender);
      return;
    }

    widget.controller.isBundleLoaded.addListener(_checkAndRender);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRender();
    });
  }

  void _checkAndRender() {
    if (_hasRendered) return;
    if (!widget.controller.isBundleLoaded.value) return;
    if (!mounted) return;
    _hasRendered = true;
    widget.controller.renderPage(
      widget.pageId,
      widget.routeInfo.path,
      widget.routeInfo.params,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (rootNode == null) {
      return ColoredBox(
        color: widget.loadingBackgroundColor,
        child: Center(
          child: CupertinoActivityIndicator(
            radius: 14,
          ),
        ),
      );
    }
    final notCached = _cachedChild == null || _lastBuiltNode != rootNode;
    if (notCached) {
      _lastBuiltNode = rootNode;
      _cachedChild = FuickNodeManagerProvider(
        manager: nodeManager,
        child: FuickAppScope(
          controller: widget.controller,
          child: FuickPageScope(
            pageId: widget.pageId,
            routeObserver:
                _routeObserverRef ?? FuickPageScope.of(context)!.routeObserver,
            child: _FuickScopeProviders(
              child: widgetFactory.buildFromNode(
                context,
                rootNode!,
                forceWrap: true,
              ),
            ),
          ),
        ),
      );

      if (_isFirstRender) {
        _isFirstRender = false;
      }
    }
    return _cachedChild!;
  }
}

class FuickPageScope extends InheritedWidget {
  final int pageId;
  final RouteObserver<Route<dynamic>> routeObserver;

  const FuickPageScope({
    super.key,
    required this.pageId,
    required this.routeObserver,
    required super.child,
  });

  static FuickPageScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FuickPageScope>();
  }

  static FuickPageScope? find(BuildContext context) {
    return context
        .getElementForInheritedWidgetOfExactType<FuickPageScope>()
        ?.widget as FuickPageScope?;
  }

  @override
  bool updateShouldNotify(FuickPageScope oldWidget) {
    return pageId != oldWidget.pageId ||
        !identical(routeObserver, oldWidget.routeObserver);
  }
}

/// 在 JS 根 Widget 上方注入 [FuickThemeProvider] 与 [FuickMediaQueryProvider]。
///
/// - 监听宿主 [Theme] / [MediaQuery] 变化，自动重建下层的 DSL 树。
/// - Theme/MediaQuery 变化时通过 NativeEvent 推送 'themeChange' / 'mediaQueryChange'
///   事件，JS 端 `useTheme()` / `useMediaQuery()` hook 订阅后刷新 state。
class _FuickScopeProviders extends StatefulWidget {
  final Widget child;

  const _FuickScopeProviders({required this.child});

  @override
  State<_FuickScopeProviders> createState() => _FuickScopeProvidersState();
}

class _FuickScopeProvidersState extends State<_FuickScopeProviders> {
  FuickThemeData? _lastTheme;
  FuickMediaQueryData? _lastMq;
  bool _pageContextRegistered = false;

  void _maybeEmitThemeChange(FuickThemeData data) {
    if (_lastTheme != null && _lastTheme != data) {
      _emitToJs('themeChange', data.toMap());
    }
    _lastTheme = data;
  }

  void _maybeEmitMediaQueryChange(FuickMediaQueryData data) {
    if (_lastMq != null && _lastMq != data) {
      _emitToJs('mediaQueryChange', data.toMap());
    }
    _lastMq = data;
  }

  void _emitToJs(String event, Map<String, dynamic> data) {
    // 通过当前 BuildContext 找到 FuickAppController.commandBus → jsProxy.ctx.invoke。
    // 简化处理：使用全 App 共享的 NativeEventService 单例通道。
    try {
      final controller = FuickAppScope.of(context);
      controller?.jsProxy.ctx.invoke('NativeEvent', 'receive', [event, data]);
    } catch (e) {
      logger.e('emit $event failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final themeData = FuickThemeData.fromThemeData(theme);
    final mqData = FuickMediaQueryData.fromMediaQuery(mq);

    _maybeEmitThemeChange(themeData);
    _maybeEmitMediaQueryChange(mqData);

    return FuickThemeProvider(
      data: themeData,
      child: FuickMediaQueryProvider(
        data: mqData,
        // Builder 的 context 是 FuickThemeProvider / FuickMediaQueryProvider 的子孙，
        // 用它注册 page context，使得 UIService.getTheme / getMediaQuery 中
        // 调用的 FuickThemeProvider.of / FuickMediaQueryProvider.of 能沿父链找到 provider。
        child: Builder(
          builder: (innerContext) {
            if (!_pageContextRegistered) {
              _pageContextRegistered = true;
              final controller = FuickAppScope.of(innerContext);
              final pageScope = FuickPageScope.of(innerContext);
              if (controller != null && pageScope != null) {
                controller.registerPageContext(
                  pageScope.pageId,
                  innerContext,
                );
              }
            }
            return widget.child;
          },
        ),
      ),
    );
  }
}
