import 'package:flutter/material.dart';
import 'package:fuickjs_flutter/core/container/fuick_action.dart';

import '../../utils/extensions.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class TabBarParser extends WidgetParser {
  @override
  String get type => 'TabBar';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final tabsProp = props['tabs'];
    List<dynamic> tabsDsl = [];
    if (tabsProp is List) {
      tabsDsl = tabsProp;
    } else if (tabsProp != null) {
      tabsDsl = [tabsProp];
    }

    return TabBar(
      tabs: tabsDsl.map((dsl) => factory.build(context, dsl)).toList(),
      isScrollable: props['isScrollable'] ?? false,
      indicatorColor: WidgetUtils.colorFromHex(props['indicatorColor']),
      indicatorWeight: WidgetUtils.sizeNum(props['indicatorWeight']) ?? 2.0,
      labelColor: WidgetUtils.colorFromHex(props['labelColor']),
      unselectedLabelColor: WidgetUtils.colorFromHex(
        props['unselectedLabelColor'],
      ),
      onTap: (index) {
        FuickAction.event(context, props['onTap'], value: index);
      },
    );
  }
}

class TabBarViewParser extends WidgetParser {
  @override
  String get type => 'TabBarView';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    return TabBarView(children: factory.buildChildren(context, children));
  }
}

class DefaultTabControllerParser extends WidgetParser {
  @override
  String get type => 'DefaultTabController';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    return DefaultTabController(
      length: asInt(props['length']),
      initialIndex: asInt(props['initialIndex']),
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
