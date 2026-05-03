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

  /// 首次构建：先 inflate+layout（Opacity 0 不可见），下一帧再 paint（Opacity 1）
  /// 将 inflate+layout 和 paint 分到不同帧，减少单帧峰值
  bool _offstage = true;

  @override
  void didUpdateWidget(FuickPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.pageId != widget.pageId) {
      _cachedChild = null;
      _lastBuiltNode = null;
      _offstage = true;
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

  /// 非预渲染路径下，是否需要延迟 1 帧再 setState，
  /// 将 createNode 和 build 分到不同帧，避免单帧峰值卡顿
  bool _deferSetState = false;

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
      if (_deferSetState) {
        // 非预渲染路径：延迟 1 帧再 setState，将 createNode 和 build 分帧
        _deferSetState = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      } else {
        setState(() {});
      }
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
    if (prewarm != null) {
      _hasRendered = true;
      if (prewarm.hasPrebuiltNodes) {
        // 预构建 Node 树就绪：直接复用，跳过动画期间的 createNode
        nodeManager = prewarm.prebuiltNodeManager!;
        rootNode = prewarm.prebuiltRootNode!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      } else if (prewarm.hasDsl) {
        // DSL 已就绪但 Node 未构建（兜底）
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _handleRenderDsl(prewarm.dsl!);
        });
      } else {
        // JS 渲染还在飞行中：等 future，DSL 到达时延迟 1 帧 setState
        _deferSetState = true;
        prewarm.future.then((dsl) {
          if (mounted) _handleRenderDsl(dsl);
        });
      }
      widget.controller.isBundleLoaded.addListener(_checkAndRender);
      return;
    }

    // 普通路径（无预渲染）：DSL 到达时延迟 1 帧 setState，分摊 createNode 和 build 的帧压力
    _deferSetState = true;
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
      // 测量 Widget 构建时间
      final widgetBuildStart = DateTime.now();

      _lastBuiltNode = rootNode;
      // 最外层 RepaintBoundary：push 动画时旧页被隔离为独立合成层，
      // 避免旧页跟随动画每帧重绘，节省 UI 线程时间。
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

      final widgetBuildCost = DateTime.now().difference(widgetBuildStart).inMilliseconds;

      if (_isFirstRender && _receiveDataTime != null) {
        _isFirstRender = false;
        widgetFactory.resetParseCost();
        final buildEndTime = DateTime.now();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final frameEndTime = DateTime.now();
          final totalCost =
              frameEndTime.difference(_receiveDataTime!).inMilliseconds;
          final inflateCost =
              frameEndTime.difference(buildEndTime).inMilliseconds;
          final parseCostMs =
              (widgetFactory.parseCostMicros / 1000).round();

          logger.d(
              '[Performance] Page First Render (ID: ${widget.pageId}, Path: ${widget.routeInfo.path}):');
          logger.d('  - Total Cost: ${totalCost}ms');
          logger.d('  - DSL Parse Cost: ${_dslParseCost}ms (createNode)');
          logger.d('  - Node→Widget Cost: ${parseCostMs}ms (parser.parse × N)');
          logger.d('  - Widget Build Cost: ${widgetBuildCost}ms (config assembly)');
          logger.d(
              '  - Layout Cost: ${inflateCost - parseCostMs}ms');
        });
      }

      // 首次构建：inflate+layout 在本帧（不可见），下一帧切换为可见（仅 paint）
      if (_offstage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() { _offstage = false; });
        });
      }
    }

    // _offstage=true: Opacity(0) 保持占位+layout 但不 paint
    // _offstage=false: 正常显示
    return Opacity(opacity: _offstage ? 0.0 : 1.0, child: _cachedChild!);
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
