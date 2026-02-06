import 'package:flutter/material.dart';

import '../../container/fuick_app_controller.dart';
import '../../container/fuick_page_view.dart';
import '../../utils/extensions.dart';
import '../fuick_command_listener_mixin.dart';
import '../fuick_dsl_cache_mixin.dart';
import '../fuick_node.dart';
import '../fuick_state_widgets.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class GridViewParser extends WidgetParser {
  @override
  String get type => 'GridView';

  @override
  void dispose(int nodeId) {}

  @override
  void onCommand(String refId, String method, dynamic args) {}

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final String? refId = props['refId']?.toString();
    final dynamic cacheKey = props['cacheKey'];

    final gridDelegate = WidgetUtils.gridDelegate(props);

    return WidgetUtils.wrapPadding(
      props,
      FuickGridView(
        refId: refId,
        gridDelegate: gridDelegate,
        cacheKey: cacheKey,
        itemCount: asIntOrNull(props['itemCount']),
        shrinkWrap: props['shrinkWrap'] ?? true,
        physics: WidgetUtils.scrollPhysics(props['physics'] as String?),
        padding: WidgetUtils.edgeInsets(props['padding']),
        scrollDirection: WidgetUtils.axis(props['scrollDirection'] as String?),
        itemBuilder: (context, index) {
          final bool hasBuilder = props['hasBuilder'] ?? false;
          if (!hasBuilder || refId == null) return Container();

          final appScope = FuickAppScope.of(context);
          final pageScope = FuickPageScope.of(context);
          if (appScope == null || pageScope == null) return Container();

          // Check local cache first
          final state = FuickGridView.of(context);
          dynamic dslOrFuture;
          if (state != null) {
            dslOrFuture = state.getCachedDsl(index);
          }

          if (dslOrFuture == null) {
            dslOrFuture = appScope.getItemDSL(pageScope.pageId, refId, index);
          }

          return FuickItemDSLBuilder(
            dslOrFuture: dslOrFuture,
            builder: (context, dsl) {
              // Store in local cache when resolved
              if (state != null) {
                state.setCachedDsl(index, dsl);
              }
              return _buildItem(context, factory, dsl);
            },
          );
        },
        children: props['hasBuilder'] == true
            ? null
            : factory.buildChildren(context, children),
      ),
    );
  }

  Widget _buildItem(BuildContext context, WidgetFactory factory, dynamic dsl) {
    final manager = FuickNodeManagerProvider.of(context);
    if (manager != null && dsl is Map && dsl.containsKey('id')) {
      // Create/Update node in manager to ensure it receives incremental updates
      final node = manager.createNode(Map<String, dynamic>.from(dsl), manager);
      // Force wrap in _FuickNodeWidget to listen for updates
      return factory.buildFromNode(context, node, forceWrap: true);
    }
    return factory.build(context, dsl);
  }
}

class FuickGridView extends StatefulWidget implements FuickDslWidget {
  @override
  final String? refId;
  @override
  final int? itemCount;
  final SliverGridDelegate gridDelegate;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final Axis scrollDirection;
  @override
  final dynamic cacheKey;
  final List<Widget>? children;
  final Widget Function(BuildContext context, int index)? itemBuilder;
  final ControllerCallback<ScrollController>? onControllerCreated;
  final ControllerCallback<ScrollController>? onDispose;

  const FuickGridView({
    super.key,
    this.refId,
    this.itemCount,
    required this.gridDelegate,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.scrollDirection = Axis.vertical,
    this.cacheKey,
    this.children,
    this.itemBuilder,
    this.onControllerCreated,
    this.onDispose,
  });

  @override
  State<FuickGridView> createState() => FuickGridViewState();

  static FuickGridViewState? of(BuildContext context) {
    return context.findAncestorStateOfType<FuickGridViewState>();
  }
}

class FuickGridViewState extends State<FuickGridView>
    with
        AutomaticKeepAliveClientMixin,
        FuickCommandListenerMixin<FuickGridView>,
        FuickDslCacheMixin<FuickGridView> {
  late ScrollController _controller;
  ScrollController get controller => _controller;

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
    if (method == 'animateTo') {
      if (!_controller.hasClients) return;
      final double offset = args['offset'].asDouble;
      final int duration = args['duration'].asIntOrNull ?? 300;
      final String curveStr = args['curve']?.toString() ?? 'easeInOut';
      final curve = WidgetUtils.curve(curveStr);
      _controller.animateTo(
        offset,
        duration: Duration(milliseconds: duration),
        curve: curve,
      );
    } else if (method == 'jumpTo') {
      if (!_controller.hasClients) return;
      final double offset = args['offset'].asDouble;
      _controller.jumpTo(offset);
    }
  }

  @override
  void didUpdateWidget(FuickGridView oldWidget) {
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
    if (widget.itemBuilder != null && widget.itemCount != null) {
      return GridView.builder(
        controller: _controller,
        gridDelegate: widget.gridDelegate,
        itemCount: widget.itemCount,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        padding: widget.padding,
        scrollDirection: widget.scrollDirection,
        itemBuilder: widget.itemBuilder!,
      );
    }

    return GridView(
      controller: _controller,
      gridDelegate: widget.gridDelegate,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      padding: widget.padding,
      scrollDirection: widget.scrollDirection,
      children: widget.children ?? [],
    );
  }
}
