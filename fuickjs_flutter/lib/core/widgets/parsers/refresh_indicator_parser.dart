import 'dart:async';
import 'package:flutter/material.dart';
import '../../container/fuick_action.dart';
import '../fuick_command_listener_mixin.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class RefreshIndicatorParser extends WidgetParser {
  @override
  String get type => 'RefreshIndicator';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    return FuickRefreshIndicator(
      refId: props['refId'],
      onRefresh: props['onRefresh'],
      color: WidgetUtils.colorFromHex(props['color'] as String?),
      backgroundColor:
          WidgetUtils.colorFromHex(props['backgroundColor'] as String?),
      child: factory.buildFirstChild(context, children, type),
    );
  }
}

class FuickRefreshIndicator extends StatefulWidget implements FuickWidget {
  @override
  final String? refId;
  final dynamic onRefresh;
  final Color? color;
  final Color? backgroundColor;
  final Widget child;

  const FuickRefreshIndicator({
    super.key,
    this.refId,
    this.onRefresh,
    this.color,
    this.backgroundColor,
    required this.child,
  });

  @override
  State<FuickRefreshIndicator> createState() => FuickRefreshIndicatorState();
}

class FuickRefreshIndicatorState extends State<FuickRefreshIndicator>
    with FuickCommandListenerMixin<FuickRefreshIndicator> {
  Completer<void>? _refreshCompleter;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  String? get refId => widget.refId;

  @override
  void onCommand(String method, dynamic args) {
    if (method == 'complete') {
      if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
        _refreshCompleter!.complete();
        _refreshCompleter = null;
      }
    } else if (method == 'show') {
      _refreshIndicatorKey.currentState?.show();
    }
  }

  Future<void> _handleRefresh() async {
    if (widget.onRefresh != null) {
      FuickAction.event(context, widget.onRefresh);
      _refreshCompleter = Completer<void>();
      return _refreshCompleter!.future;
    }
    return Future.value();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      key: _refreshIndicatorKey,
      onRefresh: _handleRefresh,
      color: widget.color,
      backgroundColor: widget.backgroundColor,
      child: widget.child,
    );
  }
}
