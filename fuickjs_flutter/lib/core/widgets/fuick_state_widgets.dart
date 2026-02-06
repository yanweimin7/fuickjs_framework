import 'package:flutter/material.dart';

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
  final ValueChanged<int>? onPageChanged;
  final List<Widget> children;
  final ControllerCallback<PageController>? onControllerCreated;
  final ControllerCallback<PageController>? onDispose;

  const FuickPageView({
    super.key,
    this.refId,
    required this.initialPage,
    required this.scrollDirection,
    this.onPageChanged,
    required this.children,
    this.onControllerCreated,
    this.onDispose,
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
    print(
        '[FuickPageView] initState refId=${widget.refId} initialPage=${widget.initialPage}');
    _controller = PageController(initialPage: widget.initialPage);
    widget.onControllerCreated?.call(_controller);
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
  }

  @override
  void dispose() {
    print('[FuickPageView] dispose refId=${widget.refId}');
    widget.onDispose?.call(_controller);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PageView(
      controller: _controller,
      scrollDirection: widget.scrollDirection,
      onPageChanged: widget.onPageChanged,
      children: widget.children,
    );
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
