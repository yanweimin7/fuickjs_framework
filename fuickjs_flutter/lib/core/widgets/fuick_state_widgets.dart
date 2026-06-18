import 'dart:async';

import 'package:flutter/material.dart';

import '../logger.dart';
import '../utils/extensions.dart';
import 'fuick_command_listener_mixin.dart';
import 'fuick_dsl_cache_mixin.dart';
import 'widget_utils.dart';

typedef ControllerCallback<T> = void Function(T controller);

class FuickPageView extends StatefulWidget implements FuickDslWidget {
  @override
  final String? refId;
  final int initialPage;
  final Axis scrollDirection;
  final ScrollPhysics? physics;
  final ValueChanged<int>? onPageChanged;
  final List<Widget> children;
  final ControllerCallback<PageController>? onControllerCreated;
  final ControllerCallback<PageController>? onDispose;
  final bool autoplay;
  final int autoplayInterval;
  final bool circular;
  final bool indicatorDots;
  final Color? indicatorColor;
  final Color? indicatorActiveColor;

  const FuickPageView({
    super.key,
    this.refId,
    required this.initialPage,
    required this.scrollDirection,
    this.physics,
    this.onPageChanged,
    required this.children,
    this.onControllerCreated,
    this.onDispose,
    this.autoplay = false,
    this.autoplayInterval = 5000,
    this.circular = false,
    this.indicatorDots = false,
    this.indicatorColor,
    this.indicatorActiveColor,
  });

  @override
  dynamic get cacheKey => null;

  @override
  int? get itemCount => null;

  @override
  State<FuickPageView> createState() => _FuickPageViewState();
}

class _FuickPageViewState extends State<FuickPageView>
    with
        AutomaticKeepAliveClientMixin,
        FuickCommandListenerMixin<FuickPageView>,
        FuickDslCacheMixin<FuickPageView> {
  late PageController _controller;
  Timer? _autoplayTimer;
  int _currentPage = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  String? get refId => widget.refId;
  @override
  dynamic get cacheKey => widget.cacheKey;
  @override
  int? get itemCount => widget.itemCount;

  @override
  void initState() {
    super.initState();
    logger.d(
        '[FuickPageView] initState refId=${widget.refId} initialPage=${widget.initialPage}');
    _currentPage = widget.initialPage;
    _controller = PageController(initialPage: widget.initialPage);
    widget.onControllerCreated?.call(_controller);
    _startAutoplay();
  }

  @override
  void onCustomCommand(String method, dynamic args) async {
    if (!_controller.hasClients) return;

    if (method == 'animateToPage') {
      final page = asInt(args['page']);
      final duration = asIntOrNull(args['duration']) ?? 300;
      final curveName = args['curve'] as String? ?? 'easeInOut';
      final curve = WidgetUtils.curve(curveName);
      await _controller.animateToPage(
        page,
        duration: Duration(milliseconds: duration),
        curve: curve,
      );
    } else if (method == 'jumpToPage' || method == 'setPageIndex') {
      final page = asInt(args['page'] ?? args['index']);
      _controller.jumpToPage(page);
    }
  }

  void _startAutoplay() {
    if (!widget.autoplay || widget.children.length <= 1) return;
    _autoplayTimer = Timer.periodic(
      Duration(milliseconds: widget.autoplayInterval),
      (_) => _nextPage(),
    );
  }

  void _stopAutoplay() {
    _autoplayTimer?.cancel();
    _autoplayTimer = null;
  }

  void _nextPage() {
    if (!mounted) return;
    final pageCount = widget.children.length;
    final nextPage = _currentPage + 1;
    if (widget.circular || nextPage < pageCount) {
      _controller.animateToPage(
        nextPage % pageCount,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void didUpdateWidget(FuickPageView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.refId != oldWidget.refId) {
      if (oldWidget.refId != null) {
        oldWidget.onDispose?.call(_controller);
      }
      if (widget.refId != null) {
        widget.onControllerCreated?.call(_controller);
      }
    }

    if (widget.autoplay != oldWidget.autoplay ||
        widget.autoplayInterval != oldWidget.autoplayInterval) {
      _stopAutoplay();
      _startAutoplay();
    }
  }

  @override
  void dispose() {
    _stopAutoplay();
    widget.onDispose?.call(_controller);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    void onPageChanged(int index) {
      setState(() => _currentPage = index);
      widget.onPageChanged?.call(index);
    }

    Widget pageView = PageView(
      controller: _controller,
      scrollDirection: widget.scrollDirection,
      physics: widget.physics,
      onPageChanged: onPageChanged,
      children: widget.children,
    );

    if (widget.indicatorDots && widget.children.length > 1) {
      final isVertical = widget.scrollDirection == Axis.vertical;
      final indicatorColor =
          widget.indicatorColor ?? Colors.black.withValues(alpha: 0.3);
      final indicatorActiveColor = widget.indicatorActiveColor ?? Colors.black;

      pageView = Stack(
        alignment: isVertical ? Alignment.centerRight : Alignment.bottomCenter,
        children: [
          pageView,
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: isVertical
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _buildDots(widget.children.length, indicatorColor,
                        indicatorActiveColor),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _buildDots(widget.children.length, indicatorColor,
                        indicatorActiveColor),
                  ),
          ),
        ],
      );
    }

    return pageView;
  }

  List<Widget> _buildDots(int count, Color color, Color activeColor) {
    return List.generate(count, (i) {
      return Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: i == _currentPage ? activeColor : color,
        ),
      );
    });
  }
}

typedef ScrollWidgetBuilder = Widget Function(
    BuildContext context, ScrollController controller);

class FuickScrollable extends StatefulWidget implements FuickDslWidget {
  @override
  final String? refId;
  final ScrollWidgetBuilder builder;
  final ControllerCallback<ScrollController>? onControllerCreated;
  final ControllerCallback<ScrollController>? onDispose;

  const FuickScrollable({
    super.key,
    this.refId,
    required this.builder,
    this.onControllerCreated,
    this.onDispose,
  });

  @override
  dynamic get cacheKey => null;

  @override
  int? get itemCount => null;

  @override
  State<FuickScrollable> createState() => _FuickScrollableState();
}

class _FuickScrollableState extends State<FuickScrollable>
    with
        AutomaticKeepAliveClientMixin,
        FuickCommandListenerMixin<FuickScrollable>,
        FuickDslCacheMixin<FuickScrollable> {
  late ScrollController _controller;

  @override
  bool get wantKeepAlive => true;

  @override
  String? get refId => widget.refId;
  @override
  dynamic get cacheKey => widget.cacheKey;
  @override
  int? get itemCount => widget.itemCount;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    widget.onControllerCreated?.call(_controller);
  }

  @override
  void onCustomCommand(String method, dynamic args) {
    if (!_controller.hasClients) return;

    if (method == 'animateTo') {
      final offset = asDouble(args['offset']);
      final duration = asIntOrNull(args['duration']) ?? 300;
      final curveName = args['curve'] as String? ?? 'easeInOut';
      final curve = WidgetUtils.curve(curveName);

      _controller.animateTo(
        offset,
        duration: Duration(milliseconds: duration),
        curve: curve,
      );
    } else if (method == 'jumpTo') {
      final offset = asDouble(args['offset']);
      _controller.jumpTo(offset);
    }
  }

  @override
  void didUpdateWidget(FuickScrollable oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.refId != oldWidget.refId) {
      if (oldWidget.refId != null) {
        oldWidget.onDispose?.call(_controller);
      }
      if (widget.refId != null) {
        widget.onControllerCreated?.call(_controller);
      }
    }
  }

  @override
  void dispose() {
    widget.onDispose?.call(_controller);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.builder(context, _controller);
  }
}

class FuickItemDSLBuilder extends StatefulWidget {
  final dynamic dslOrFuture;
  final Widget Function(BuildContext context, dynamic dsl) builder;

  const FuickItemDSLBuilder({
    super.key,
    required this.dslOrFuture,
    required this.builder,
  });

  @override
  State<FuickItemDSLBuilder> createState() => _FuickItemDSLBuilderState();
}

class _FuickItemDSLBuilderState extends State<FuickItemDSLBuilder> {
  dynamic _dsl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _resolveDSL();
  }

  @override
  void didUpdateWidget(FuickItemDSLBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dslOrFuture != oldWidget.dslOrFuture) {
      _resolveDSL();
    }
  }

  void _resolveDSL() {
    if (widget.dslOrFuture is Future) {
      final future = widget.dslOrFuture as Future;
      // If we already have a DSL, don't set loading to true to avoid flickering
      if (_dsl == null) {
        _loading = true;
      }
      future.then((value) {
        if (mounted) {
          setState(() {
            _dsl = value;
            _loading = false;
          });
        }
      });
    } else {
      _dsl = widget.dslOrFuture;
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show loading if we don't have any DSL to show
    if (_loading && _dsl == null) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_dsl == null) return const SizedBox.shrink();
    return widget.builder(context, _dsl);
  }
}

/// 包裹滚动 Widget，只在边缘状态变化时触发 onStartReached / onEndReached，
/// 避免在阈值范围内重复回调。
class FuickScrollEdgeNotifier extends StatefulWidget {
  final Widget child;
  final void Function(ScrollMetrics metrics)? onScroll;
  final VoidCallback? onStartReached;
  final VoidCallback? onEndReached;
  final double startThreshold;
  final double endThreshold;

  const FuickScrollEdgeNotifier({
    super.key,
    required this.child,
    this.onScroll,
    this.onStartReached,
    this.onEndReached,
    this.startThreshold = 50.0,
    this.endThreshold = 50.0,
  });

  @override
  State<FuickScrollEdgeNotifier> createState() =>
      _FuickScrollEdgeNotifierState();
}

class _FuickScrollEdgeNotifierState extends State<FuickScrollEdgeNotifier> {
  bool _wasAtStart = false;
  bool _wasAtEnd = false;

  bool _isAtStart(ScrollMetrics m) => m.pixels <= widget.startThreshold;
  bool _isAtEnd(ScrollMetrics m) =>
      m.pixels >= m.maxScrollExtent - widget.endThreshold;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final metrics = notification.metrics;

        if (widget.onScroll != null &&
            notification is ScrollUpdateNotification) {
          widget.onScroll!(metrics);
        }

        if (widget.onStartReached != null &&
            notification is ScrollUpdateNotification) {
          final atStart = _isAtStart(metrics);
          if (atStart && !_wasAtStart) {
            widget.onStartReached!();
          }
          _wasAtStart = atStart;
        }

        if (widget.onEndReached != null &&
            notification is ScrollUpdateNotification) {
          final atEnd = _isAtEnd(metrics);
          if (atEnd && !_wasAtEnd) {
            widget.onEndReached!();
          }
          _wasAtEnd = atEnd;
        }

        return false;
      },
      child: widget.child,
    );
  }
}
