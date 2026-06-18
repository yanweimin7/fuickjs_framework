import 'package:flutter/material.dart';

import '../../container/fuick_action.dart';
import '../../container/fuick_app_controller.dart';
import '../../container/fuick_page_view.dart';
import '../../utils/extensions.dart';
import '../fuick_command_listener_mixin.dart';
import '../fuick_dsl_cache_mixin.dart';
import '../fuick_state_widgets.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class ListViewParser extends WidgetParser {
  @override
  String get type => 'ListView';

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
    final bool hasBuilder = props['hasBuilder'] ?? false;
    final int? itemCount = asIntOrNull(props['itemCount']);
    final bool shrinkWrap = props['shrinkWrap'] ?? true;
    final String? physicsProp = props['physics'] as String?;
    final dynamic paddingProp = props['padding'];
    final String? scrollDirectionProp =
        props['scrollDirection'] as String? ?? props['orientation'] as String?;
    final onScrollEvent = props['onScroll'];
    final onScrollStartReachedEvent = props['onScrollStartReached'];
    final onScrollEndReachedEvent = props['onScrollEndReached'];
    final startThreshold = asDoubleOrNull(props['startThreshold']) ?? 50.0;
    final endThreshold = asDoubleOrNull(props['endThreshold']) ?? 50.0;

    Widget listView = WidgetUtils.wrapPadding(
      props,
      FuickListView(
        refId: refId,
        cacheKey: cacheKey,
        itemCount: itemCount,
        shrinkWrap: shrinkWrap,
        physics: WidgetUtils.scrollPhysics(physicsProp),
        padding: WidgetUtils.edgeInsets(paddingProp),
        scrollDirection: WidgetUtils.axis(scrollDirectionProp),
        itemBuilder: hasBuilder
            ? (context, index) {
                if (refId == null) return Container();

                final appScope = FuickAppScope.of(context);
                final pageScope = FuickPageScope.of(context);
                if (appScope == null || pageScope == null) return Container();

                // Check local cache first
                final state = FuickListView.of(context);
                dynamic dslOrFuture;
                if (state != null) {
                  dslOrFuture = state.getCachedDsl(index);
                }

                dslOrFuture ??= appScope.getItemDSL(
                  pageScope.pageId,
                  refId,
                  index,
                );

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
              }
            : null,
        children: hasBuilder ? null : factory.buildChildren(context, children),
      ),
    );

    if (onScrollEvent != null ||
        onScrollStartReachedEvent != null ||
        onScrollEndReachedEvent != null) {
      listView = FuickScrollEdgeNotifier(
        startThreshold: startThreshold,
        endThreshold: endThreshold,
        onScroll: onScrollEvent != null
            ? (metrics) {
                FuickAction.event(context, onScrollEvent, value: {
                  'pixels': metrics.pixels,
                  'axis':
                      metrics.axis == Axis.vertical ? 'vertical' : 'horizontal',
                  'maxScrollExtent': metrics.maxScrollExtent,
                });
              }
            : null,
        onStartReached: onScrollStartReachedEvent != null
            ? () => FuickAction.event(context, onScrollStartReachedEvent)
            : null,
        onEndReached: onScrollEndReachedEvent != null
            ? () => FuickAction.event(context, onScrollEndReachedEvent)
            : null,
        child: listView,
      );
    }

    return listView;
  }

  Widget _buildItem(BuildContext context, WidgetFactory factory, dynamic dsl) {
    final manager = FuickNodeManagerProvider.of(context);
    if (dsl is Map && dsl.containsKey('id')) {
      // Create/Update node in manager to ensure it receives incremental updates
      final node = manager.createNode(asMap(dsl), manager);
      // Force wrap in _FuickNodeWidget to listen for updates
      return factory.buildFromNode(context, node, forceWrap: true);
    }
    return factory.build(context, dsl);
  }
}

class FuickListView extends StatefulWidget implements FuickDslWidget {
  @override
  final String? refId;
  @override
  final int? itemCount;
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

  const FuickListView({
    super.key,
    this.refId,
    this.itemCount,
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
  State<FuickListView> createState() => FuickListViewState();

  static FuickListViewState? of(BuildContext context) {
    return context.findAncestorStateOfType<FuickListViewState>();
  }
}

class FuickListViewState extends State<FuickListView>
    with
        AutomaticKeepAliveClientMixin,
        FuickCommandListenerMixin<FuickListView>,
        FuickDslCacheMixin<FuickListView> {
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
  void didUpdateWidget(FuickListView oldWidget) {
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
      return ListView.builder(
        controller: _controller,
        itemCount: widget.itemCount,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        padding: widget.padding,
        scrollDirection: widget.scrollDirection,
        itemBuilder: widget.itemBuilder!,
      );
    }
    return ListView(
      controller: _controller,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      padding: widget.padding,
      scrollDirection: widget.scrollDirection,
      children: widget.children ?? [],
    );
  }
}
