import 'fwidget.dart';

class Scaffold extends FWidget {
  @override
  String get widgetType => 'Scaffold';

  Scaffold({
    FWidget? appBar,
    FWidget? body,
    FWidget? floatingActionButton,
    FWidget? drawer,
    FWidget? bottomNavigationBar,
    String? backgroundColor,
  }) {
    setProp('appBar', appBar);
    setProp('body', body);
    setProp('floatingActionButton', floatingActionButton);
    setProp('drawer', drawer);
    setProp('bottomNavigationBar', bottomNavigationBar);
    setProp('backgroundColor', backgroundColor);
  }
}

class AppBar extends FWidget {
  @override
  String get widgetType => 'AppBar';

  AppBar({
    FWidget? title,
    FWidget? leading,
    List<FWidget>? actions,
    String? backgroundColor,
    String? foregroundColor,
    bool? centerTitle,
    double? elevation,
  }) {
    setProp('title', title);
    setProp('leading', leading);
    if (actions != null && actions.isNotEmpty) {
      setProp('actions', actions.map((a) => a.toJson()).toList());
    }
    setProp('backgroundColor', backgroundColor);
    setProp('foregroundColor', foregroundColor);
    setProp('centerTitle', centerTitle);
    setProp('elevation', elevation);
  }
}
