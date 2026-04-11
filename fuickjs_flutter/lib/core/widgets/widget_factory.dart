import 'package:flutter/material.dart';

import '../logger.dart';
import 'fuick_node.dart';
import 'parsers/alert_dialog_parser.dart';
import 'parsers/animated_align_parser.dart';
import 'parsers/animated_container_parser.dart';
import 'parsers/animated_opacity_parser.dart';
import 'parsers/animated_padding_parser.dart';
import 'parsers/animated_positioned_parser.dart';
import 'parsers/animated_rotation_parser.dart';
import 'parsers/animated_scale_parser.dart';
import 'parsers/animated_slide_parser.dart';
import 'parsers/app_bar_parser.dart';
import 'parsers/bottom_navigation_bar_parser.dart';
import 'parsers/button_parser.dart';
import 'parsers/card_parser.dart';
import 'parsers/center_parser.dart';
import 'parsers/checkbox_parser.dart';
import 'parsers/circular_progress_indicator_parser.dart';
import 'parsers/clip_r_rect_parser.dart';
import 'parsers/column_parser.dart';
import 'parsers/constrained_box_parser.dart';
import 'parsers/container_parser.dart';
import 'parsers/custom_paint_parser.dart';
import 'parsers/custom_scroll_view_parser.dart';
import 'parsers/divider_parser.dart';
import 'parsers/expanded_parser.dart';
import 'parsers/fitted_box_parser.dart';
import 'parsers/flex_parser.dart';
import 'parsers/flexible_parser.dart';
import 'parsers/floating_action_button_parser.dart';
import 'parsers/gesture_detector_parser.dart';
import 'parsers/ignore_pointer_parser.dart';
import 'parsers/grid_view_parser.dart';
import 'parsers/icon_parser.dart';
import 'parsers/image_filtered_parser.dart';
import 'parsers/image_parser.dart';
import 'parsers/ink_well_parser.dart';
import 'parsers/intrinsic_height_parser.dart';
import 'parsers/intrinsic_width_parser.dart';
import 'parsers/keep_alive_parser.dart';
import 'parsers/list_tile_parser.dart';
import 'parsers/list_view_parser.dart';
import 'parsers/material_parser.dart';
import 'parsers/opacity_parser.dart';
import 'parsers/padding_parser.dart';
import 'parsers/page_view_parser.dart';
import 'parsers/pop_scope_parser.dart';
import 'parsers/pointer_listener_parser.dart';
import 'parsers/positioned_parser.dart';
import 'parsers/refresh_indicator_parser.dart';
import 'parsers/repaint_boundary_parser.dart';
import 'parsers/rich_text_parser.dart';
import 'parsers/rotated_box_parser.dart';
import 'parsers/rotation_transition_parser.dart';
import 'parsers/row_parser.dart';
import 'parsers/safe_area_parser.dart';
import 'parsers/scaffold_parser.dart';
import 'parsers/scale_transition_parser.dart';
import 'parsers/single_child_scroll_view_parser.dart';
import 'parsers/sized_box_parser.dart';
import 'parsers/slide_transition_parser.dart';
import 'parsers/sliver_app_bar_parser.dart';
import 'parsers/sliver_grid_parser.dart';
import 'parsers/sliver_list_parser.dart';
import 'parsers/sliver_persistent_header_parser.dart';
import 'parsers/sliver_to_box_adapter_parser.dart';
import 'parsers/stack_parser.dart';
import 'parsers/switch_parser.dart';
import 'parsers/tab_parser.dart';
import 'parsers/tabs_parser.dart';
import 'parsers/text_field_parser.dart';
import 'parsers/text_parser.dart';
import 'parsers/transform_parser.dart';
import 'parsers/video_player_parser.dart';
import 'parsers/visibility_detector_parser.dart';
import 'parsers/visibility_parser.dart';
import 'parsers/widget_parser.dart';
import 'parsers/wrap_parser.dart';
import 'parsers/slider_parser.dart';
import 'parsers/linear_progress_indicator_parser.dart';
import 'parsers/radio_parser.dart';
import 'parsers/aspect_ratio_parser.dart';
import 'parsers/fractionally_sized_box_parser.dart';
import 'parsers/drawer_parser.dart';
import 'parsers/backdrop_filter_parser.dart';
import 'parsers/animated_switcher_parser.dart';
import 'parsers/animated_cross_fade_parser.dart';
import 'parsers/nested_scroll_view_parser.dart';
import 'parsers/decorated_box_outline_parser.dart';
import 'parsers/clip_path_parser.dart';
import 'parsers/color_filtered_parser.dart';

class WidgetFactory {
  WidgetFactory() {
    _registerDefaultParsers();
  }

  final Map<String, WidgetParser> _parsers = {};

  void _registerDefaultParsers() {
    register(VisibilityParser());
    register(PointerListenerParser());
    register(ColumnParser());
    register(RowParser());
    register(FlexParser());
    register(TextParser());
    register(ContainerParser());
    register(ScaffoldParser());
    register(AppBarParser());
    register(ButtonParser());
    register(FloatingActionButtonParser());
    register(TextFieldParser());
    register(SwitchParser());
    register(ImageParser());
    register(PaddingParser());
    register(SizedBoxParser());
    register(MaterialParser());
    register(DividerParser());
    register(SingleChildScrollViewParser());
    register(IconParser());
    register(ListViewParser());
    register(StackParser());
    register(PositionedParser());
    register(OpacityParser());
    register(CenterParser());
    register(ExpandedParser());
    register(FlexibleParser());
    register(GestureDetectorParser());
    register(IgnorePointerParser());
    register(InkWellParser());
    register(CircularProgressIndicatorParser());
    register(SafeAreaParser());
    register(PageViewParser());
    register(PopScopeParser());
    register(GridViewParser());
    register(CustomPaintParser());
    register(ListTileParser());
    register(BottomNavigationBarParser());
    register(CustomScrollViewParser());
    register(SliverListParser());
    register(SliverGridParser());
    register(SliverToBoxAdapterParser());
    register(SliverAppBarParser());
    register(SliverPersistentHeaderParser());
    register(TabBarParser());
    register(TabBarViewParser());
    register(DefaultTabControllerParser());
    register(TabParser());
    register(KeepAliveParser());
    register(AnimatedContainerParser());
    register(AnimatedOpacityParser());
    register(AlertDialogParser());
    register(AnimatedAlignParser());
    register(AnimatedPositionedParser());
    register(AnimatedPaddingParser());
    register(AnimatedRotationParser());
    register(AnimatedScaleParser());
    register(AnimatedSlideParser());
    register(RotationTransitionParser());
    register(ScaleTransitionParser());
    register(SlideTransitionParser());
    register(ConstrainedBoxParser());
    register(FittedBoxParser());
    register(IntrinsicHeightParser());
    register(IntrinsicWidthParser());
    register(VisibilityDetectorParser());
    register(VideoPlayerParser());
    register(WrapParser());
    register(CardParser());
    register(CheckboxParser());
    register(TransformParser());
    register(ClipRRectParser());
    register(RepaintBoundaryParser());
    register(RefreshIndicatorParser());
    register(RichTextParser());
    register(SliderParser());
    register(LinearProgressIndicatorParser());
    register(RadioParser());
    register(AspectRatioParser());
    register(FractionallySizedBoxParser());
    register(DrawerParser());
    register(BackdropFilterParser());
    register(ImageFilteredParser());
    register(RotatedBoxParser());
    register(AnimatedSwitcherParser());
    register(AnimatedCrossFadeParser());
    register(NestedScrollViewParser());
    register(DecoratedBoxOutlineParser());
    register(ClipPathParser());
    register(ColorFilteredParser());
  }

  void register(WidgetParser parser) {
    _parsers[parser.type] = parser;
  }

  bool hasWidget(String type) {
    return _parsers.containsKey(type);
  }

  Widget build(BuildContext context, dynamic dslOrNode) {
    if (dslOrNode is FuickNode) {
      return buildFromNode(context, dslOrNode);
    }
    if (dslOrNode is String) {
      return Text(dslOrNode);
    }
    if (dslOrNode is! Map) {
      return const SizedBox.shrink();
    }
    final dsl = dslOrNode;
    final typeValue = dsl['type'];
    if (typeValue is! String) {
      logger.e('[WidgetFactory] Error: invalid dsl type: $typeValue');
      return const SizedBox.shrink();
    }
    final String type = typeValue;
    final props = (dsl['props'] as Map?)?.cast<String, dynamic>() ?? const {};
    final children = dsl['children'] ?? [];
    return buildInternal(context, type, props, children);
  }

  Widget buildFromNode(
    BuildContext context,
    FuickNode node, {
    bool forceWrap = false,
  }) {
    if (forceWrap || node.isBoundary) {
      return _FuickNodeWidget(node: node, factory: this);
    }

    return buildInternal(
      context,
      node.type,
      node.props,
      node.children,
    );
  }

  Widget buildInternal(
    BuildContext context,
    String type,
    Map<String, dynamic> props,
    dynamic children,
  ) {
    final parser = _parsers[type];
    if (parser != null) {
      return parser.parse(context, props, children, this);
    }
    throw Exception('Unknown widget type: $type');
  }

  List<Widget> buildChildren(BuildContext context, dynamic children) {
    if (children is List<FuickNode>) {
      final Set<int> seenIds = {};
      final List<Widget> widgets = [];
      for (final node in children) {
        if (seenIds.contains(node.id)) continue;
        widgets.add(buildFromNode(context, node));
        seenIds.add(node.id);
      }
      return widgets;
    } else if (children is List) {
      return children
          .map((e) => e != null ? build(context, e) : null)
          .whereType<Widget>()
          .toList();
    }
    return const [];
  }

  Widget buildFirstChild(BuildContext context, dynamic children,
      [String? parentType]) {
    if (children is List) {
      if (children.length > 1) {
        logger.w(
            '[WidgetFactory] Warning: buildFirstChild called with ${children.length} children. '
            'Automatically wrapping in Column (MainAxisSize.min). '
            'Parent Widget: ${parentType ?? "Unknown"}');
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: buildChildren(context, children),
        );
      }
    }

    if (children is List<FuickNode>) {
      return children.isEmpty
          ? const SizedBox.shrink()
          : buildFromNode(context, children.first);
    } else if (children is List) {
      return children.isEmpty
          ? const SizedBox.shrink()
          : build(context, children.first);
    }
    return const SizedBox.shrink();
  }
}

class _FuickNodeWidget extends StatefulWidget {
  final FuickNode node;
  final WidgetFactory factory;

  _FuickNodeWidget({required this.node, required this.factory})
      : super(key: ValueKey(node.id));

  @override
  State<_FuickNodeWidget> createState() => _FuickNodeWidgetState();
}

class _FuickNodeWidgetState extends State<_FuickNodeWidget> {
  FuickNodeManager? _manager;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newManager = FuickNodeManagerProvider.of(context);
    if (_manager != newManager) {
      _manager?.removeListener(widget.node.id, _update);
      _manager = newManager;
      _manager?.addListener(widget.node.id, _update);
    }
  }

  @override
  void dispose() {
    _manager?.removeListener(widget.node.id, _update);
    super.dispose();
  }

  void _update(FuickNode node) {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.factory.buildInternal(
      context,
      widget.node.type,
      widget.node.props,
      widget.node.children,
    );
  }
}

class FuickNodeManagerProvider extends InheritedWidget {
  final FuickNodeManager manager;

  const FuickNodeManagerProvider({
    super.key,
    required this.manager,
    required super.child,
  });

  static FuickNodeManager? maybeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<FuickNodeManagerProvider>()
        ?.manager;
  }

  static FuickNodeManager of(BuildContext context) {
    final manager = maybeOf(context);
    if (manager == null) {
      throw FlutterError(
        'FuickNodeManagerProvider.of() called with a context that does not contain a FuickNodeManagerProvider.\n'
        'No FuickNodeManagerProvider ancestor could be found starting from the context that was passed to FuickNodeManagerProvider.of().',
      );
    }
    return manager;
  }

  @override
  bool updateShouldNotify(FuickNodeManagerProvider oldWidget) =>
      manager != oldWidget.manager;
}
