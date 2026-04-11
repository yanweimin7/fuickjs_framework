import 'package:flutter/material.dart';

import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class NestedScrollViewParser extends WidgetParser {
  @override
  String get type => 'NestedScrollView';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final headerDsl = props['headerSliverBuilder'];
    final bodyDsl = props['body'];

    return NestedScrollView(
      scrollDirection: WidgetUtils.axis(
        props['scrollDirection'] as String?,
        defaultAxis: Axis.vertical,
      ),
      reverse: asBool(props['reverse']),
      physics: WidgetUtils.scrollPhysics(props['physics'] as String?),
      headerSliverBuilder: (BuildContext innerContext, bool innerBoxIsScrolled) {
        if (headerDsl == null) return const [];
        if (headerDsl is List) {
          return factory.buildChildren(innerContext, headerDsl);
        }
        return [factory.build(innerContext, headerDsl)];
      },
      body: bodyDsl != null
          ? factory.build(context, bodyDsl)
          : const SizedBox.shrink(),
    );
  }
}
