import 'dart:async';

import 'package:flutter/material.dart';

import '../../container/fuick_action.dart';
import '../../container/fuick_app_controller.dart';
import '../../service/fuick_command_bus.dart';
import '../../utils/extensions.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class PageViewParser extends WidgetParser {
  @override
  String get type => 'PageView';

  @override
  void onCommand(String refId, String method, dynamic args) {
    _commandBus?.dispatch(refId, method, args);
  }

  FuickCommandBus? _commandBus;

  FuickCommandBus? get commandBus => _commandBus;

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    _commandBus = FuickAppScope.of(context)?.commandBus;

    final int? initialPage = asIntOrNull(props['initialPage']);
    final String? refId = props['refId']?.toString();
    final ScrollPhysics? physics = WidgetUtils.physics(props['physics']);
    final bool autoplay = props['autoplay'] == true;
    final int autoplayInterval = asInt(props['autoplayInterval'] ?? 5000);
    final bool circular = props['circular'] == true;
    final bool indicatorDots = props['indicatorDots'] == true;
    final String? indicatorColor = props['indicatorColor'] as String?;
    final String? indicatorActiveColor =
        props['indicatorActiveColor'] as String?;

    final childWidgets = factory.buildChildren(context, children);

    return WidgetUtils.wrapPadding(
      props,
      _FuickPageViewWithAutoplay(
        key: refId != null ? ValueKey(refId) : null,
        refId: refId,
        commandBus: _commandBus,
        initialPage: initialPage ?? 0,
        scrollDirection: props['scrollDirection'] == 'vertical'
            ? Axis.vertical
            : Axis.horizontal,
        physics: physics,
        autoplay: autoplay,
        autoplayInterval: autoplayInterval,
        circular: circular,
        indicatorDots: indicatorDots,
        indicatorColor: WidgetUtils.colorFromHex(indicatorColor) ??
            Colors.black.withValues(alpha: 0.3),
        indicatorActiveColor:
            WidgetUtils.colorFromHex(indicatorActiveColor) ?? Colors.black,
        onPageChanged: (index) {
          if (props['onPageChanged'] != null) {
            FuickAction.event(context, props['onPageChanged'], value: index);
          }
        },
        children: childWidgets,
      ),
    );
  }

  @override
  void dispose(int nodeId) {}
}

class _FuickPageViewWithAutoplay extends StatefulWidget {
  final String? refId;
  final FuickCommandBus? commandBus;
  final int initialPage;
  final Axis scrollDirection;
  final ScrollPhysics? physics;
  final bool autoplay;
  final int autoplayInterval;
  final bool circular;
  final bool indicatorDots;
  final Color indicatorColor;
  final Color indicatorActiveColor;
  final ValueChanged<int> onPageChanged;
  final List<Widget> children;

  const _FuickPageViewWithAutoplay({
    super.key,
    this.refId,
    this.commandBus,
    required this.initialPage,
    required this.scrollDirection,
    this.physics,
    required this.autoplay,
    required this.autoplayInterval,
    required this.circular,
    required this.indicatorDots,
    required this.indicatorColor,
    required this.indicatorActiveColor,
    required this.onPageChanged,
    required this.children,
  });

  @override
  State<_FuickPageViewWithAutoplay> createState() =>
      _FuickPageViewWithAutoplayState();
}

class _FuickPageViewWithAutoplayState
    extends State<_FuickPageViewWithAutoplay> {
  late PageController _controller;
  Timer? _autoplayTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _controller = PageController(initialPage: widget.initialPage);
    _registerCommandListener();
    _startAutoplay();
  }

  void _registerCommandListener() {
    if (widget.refId != null && widget.commandBus != null) {
      widget.commandBus!.addListener(widget.refId!, _onCommand);
    }
  }

  void _onCommand(String method, dynamic args) {
    if (!_controller.hasClients) return;

    if (method == 'animateToPage') {
      final page = asInt(args['page']);
      final duration = asIntOrNull(args['duration']) ?? 300;
      _controller.animateToPage(
        page,
        duration: Duration(milliseconds: duration),
        curve: Curves.easeInOut,
      );
    } else if (method == 'jumpToPage' || method == 'setPageIndex') {
      final page = asInt(args['page'] ?? args['index']);
      _controller.jumpToPage(page);
    }
  }

  @override
  void didUpdateWidget(_FuickPageViewWithAutoplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoplay != oldWidget.autoplay ||
        widget.autoplayInterval != oldWidget.autoplayInterval) {
      _stopAutoplay();
      _startAutoplay();
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
  void dispose() {
    _stopAutoplay();
    if (widget.refId != null && widget.commandBus != null) {
      widget.commandBus!.removeListener(widget.refId!, _onCommand);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget pageView = PageView(
      controller: _controller,
      scrollDirection: widget.scrollDirection,
      physics: widget.physics,
      onPageChanged: (index) {
        setState(() => _currentPage = index);
        widget.onPageChanged(index);
      },
      children: widget.children,
    );

    if (widget.indicatorDots && widget.children.length > 1) {
      final isVertical = widget.scrollDirection == Axis.vertical;
      pageView = Stack(
        alignment: isVertical ? Alignment.centerRight : Alignment.bottomCenter,
        children: [
          pageView,
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: isVertical
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _buildDots(),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _buildDots(),
                  ),
          ),
        ],
      );
    }

    return pageView;
  }

  List<Widget> _buildDots() {
    return List.generate(widget.children.length, (i) {
      return Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: i == _currentPage
              ? widget.indicatorActiveColor
              : widget.indicatorColor,
        ),
      );
    });
  }
}
