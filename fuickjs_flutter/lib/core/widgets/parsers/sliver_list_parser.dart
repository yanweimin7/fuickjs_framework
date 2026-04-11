import 'package:flutter/material.dart';
import '../../container/fuick_app_controller.dart';
import '../../container/fuick_page_view.dart';
import '../../utils/extensions.dart';
import '../fuick_sliver_widgets.dart';
import '../fuick_state_widgets.dart';
import '../widget_factory.dart';
import 'widget_parser.dart';

class SliverListParser extends WidgetParser {
  @override
  String get type => 'SliverList';

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
    final bool hasBuilder = props['hasBuilder'] ?? false;
    final int? itemCount = asIntOrNull(props['itemCount']);
    final dynamic cacheKey = props['cacheKey'];

    if (hasBuilder && refId != null) {
      return FuickSliverList(
        refId: refId,
        itemCount: itemCount,
        cacheKey: cacheKey,
        itemBuilder: (context, index) {
          final appScope = FuickAppScope.of(context);
          final pageScope = FuickPageScope.of(context);
          if (appScope == null || pageScope == null) return Container();

          // Check local cache first
          final state = FuickSliverList.of(context);
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
              return factory.build(context, dsl);
            },
          );
        },
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate(
        factory.buildChildren(context, children),
      ),
    );
  }
}
