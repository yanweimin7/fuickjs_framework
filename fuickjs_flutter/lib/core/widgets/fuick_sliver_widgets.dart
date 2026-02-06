import 'package:flutter/material.dart';

import 'fuick_command_listener_mixin.dart';
import 'fuick_dsl_cache_mixin.dart';

class FuickSliverList extends StatefulWidget implements FuickDslWidget {
  @override
  final String? refId;
  @override
  final int? itemCount;
  @override
  final dynamic cacheKey;
  final Widget Function(BuildContext context, int index) itemBuilder;

  const FuickSliverList({
    super.key,
    this.refId,
    this.itemCount,
    this.cacheKey,
    required this.itemBuilder,
  });

  @override
  State<FuickSliverList> createState() => FuickSliverListState();

  static FuickSliverListState? of(BuildContext context) {
    return context.findAncestorStateOfType<FuickSliverListState>();
  }
}

class FuickSliverListState extends State<FuickSliverList>
    with
        AutomaticKeepAliveClientMixin,
        FuickCommandListenerMixin<FuickSliverList>,
        FuickDslCacheMixin<FuickSliverList> {
  @override
  bool get wantKeepAlive => true;

  @override
  String? get refId => widget.refId;
  @override
  dynamic get cacheKey => widget.cacheKey;
  @override
  int? get itemCount => widget.itemCount;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        widget.itemBuilder,
        childCount: widget.itemCount,
      ),
    );
  }
}

class FuickSliverGrid extends StatefulWidget implements FuickDslWidget {
  @override
  final String? refId;
  @override
  final int? itemCount;
  @override
  final dynamic cacheKey;
  final SliverGridDelegate gridDelegate;
  final Widget Function(BuildContext context, int index) itemBuilder;

  const FuickSliverGrid({
    super.key,
    this.refId,
    this.itemCount,
    this.cacheKey,
    required this.gridDelegate,
    required this.itemBuilder,
  });

  @override
  State<FuickSliverGrid> createState() => FuickSliverGridState();

  static FuickSliverGridState? of(BuildContext context) {
    return context.findAncestorStateOfType<FuickSliverGridState>();
  }
}

class FuickSliverGridState extends State<FuickSliverGrid>
    with
        AutomaticKeepAliveClientMixin,
        FuickCommandListenerMixin<FuickSliverGrid>,
        FuickDslCacheMixin<FuickSliverGrid> {
  @override
  bool get wantKeepAlive => true;

  @override
  String? get refId => widget.refId;
  @override
  dynamic get cacheKey => widget.cacheKey;
  @override
  int? get itemCount => widget.itemCount;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SliverGrid(
      gridDelegate: widget.gridDelegate,
      delegate: SliverChildBuilderDelegate(
        widget.itemBuilder,
        childCount: widget.itemCount,
      ),
    );
  }
}
