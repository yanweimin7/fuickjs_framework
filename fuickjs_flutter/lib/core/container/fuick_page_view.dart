import 'package:flutter/material.dart' hide widgetFactory;

import '../logger.dart';
import '../widgets/fuick_node.dart';
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
  DateTime? _receiveDataTime;
  bool _isFirstRender = true;
  int _dslParseCost = 0;

  Widget? _cachedChild;
  FuickNode? _lastBuiltNode;

  @override
  void didUpdateWidget(FuickPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.pageId != widget.pageId) {
      _cachedChild = null;
      _lastBuiltNode = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    widget.controller.routeObserver.unsubscribe(this);
    widget.controller.isBundleLoaded.removeListener(_checkAndRender);
    widget.controller.destroyPage(widget.pageId);
    widget.controller.onPageRender.remove(widget.pageId);
    widget.controller.onPagePatch.remove(widget.pageId);
    widget.controller.onPagePatchOps.remove(widget.pageId);
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

  /// 递归计算节点数量
  int _countNodes(FuickNode node) {
    int count = 1;
    for (final child in node.children) {
      count += _countNodes(child);
    }
    return count;
  }

  void _handleRenderDsl(Map<String, dynamic> dsl) {
    _receiveDataTime = DateTime.now();

    if (mounted && _isVisible) {
      widget.controller.notifyLifecycle(widget.pageId, 'visible');
    }

    final dslParseStart = DateTime.now();
    final newNode = nodeManager.createNode(dsl, nodeManager);
    _dslParseCost = DateTime.now().difference(dslParseStart).inMilliseconds;
    logger.d(
        '[Performance] DSL Parse Cost: ${_dslParseCost}ms (nodes: ${_countNodes(newNode)})');

    if (rootNode != newNode && mounted) {
      rootNode = newNode;
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();

    // patch 回调：两条路径（预渲染 / 普通）都需要
    widget.controller.onPagePatch[widget.pageId] = (patches) {
      nodeManager.applyPatches(patches, nodeManager);
    };
    widget.controller.onPagePatchOps[widget.pageId] = (ops) {
      nodeManager.applyOps(ops, nodeManager);
    };

    // 注册 render 回调（覆盖预渲染阶段的临时回调）
    widget.controller.onPageRender[widget.pageId] = _handleRenderDsl;

    // 检查是否有预渲染的 DSL 缓存（navigation delegate 已认领并复用了 pageId）
    final prewarm = widget.controller.page.consumeByPageId(widget.pageId);
    logger.d(
        '[Prewarm] pageId=${widget.pageId}, prewarm=${prewarm != null}, hasPrebuiltNodes=${prewarm?.hasPrebuiltNodes ?? false}');
    if (prewarm != null) {
      _hasRendered = true;
      if (prewarm.hasPrebuiltNodes) {
        nodeManager = prewarm.prebuiltNodeManager!;
        rootNode = prewarm.prebuiltRootNode!;
      } else if (prewarm.hasDsl) {
        final newNode = nodeManager.createNode(prewarm.dsl!, nodeManager);
        rootNode = newNode;
      } else {
        prewarm.future.then((dsl) {
          if (mounted) _handleRenderDsl(dsl);
        });
      }
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
      return ColoredBox(color: widget.loadingBackgroundColor);
    }

    if (_cachedChild == null || _lastBuiltNode != rootNode) {
      _lastBuiltNode = rootNode;
      _cachedChild = RepaintBoundary(
        child: FuickNodeManagerProvider(
          manager: nodeManager,
          child: FuickAppScope(
            controller: widget.controller,
            child: FuickPageScope(
              pageId: widget.pageId,
              child: widgetFactory.buildFromNode(
                context,
                rootNode!,
                forceWrap: true,
              ),
            ),
          ),
        ),
      );

      if (_isFirstRender && _receiveDataTime != null) {
        _isFirstRender = false;
        final parseCostMicros = widgetFactory.parseCostMicros;
        widgetFactory.resetParseCost();
        final buildEndTime = DateTime.now();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final frameEndTime = DateTime.now();
          final totalCost =
              frameEndTime.difference(_receiveDataTime!).inMilliseconds;
          final layoutCost =
              frameEndTime.difference(buildEndTime).inMilliseconds;
          final parseCostMs = (parseCostMicros / 1000).toStringAsFixed(1);

          logger.d(
              '[Performance] Page First Render (ID: ${widget.pageId}, Path: ${widget.routeInfo.path}):');
          logger.d('  - Total Cost: ${totalCost}ms');
          logger.d('  - DSL Parse Cost: ${_dslParseCost}ms (createNode)');
          logger.d('  - Node→Widget Cost: ${parseCostMs}ms (parser.parse × N)');
          logger.d('  - Layout Cost: ${layoutCost}ms');
        });
      }
    }

    return _cachedChild!;
  }
}

class FuickPageScope extends InheritedWidget {
  final int pageId;

  const FuickPageScope({super.key, required this.pageId, required super.child});

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
    return pageId != oldWidget.pageId;
  }
}
