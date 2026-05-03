import 'fwidget.dart';

class Expanded extends FWidget {
  @override
  String get widgetType => 'Expanded';

  Expanded({int flex = 1, required FWidget child}) {
    setProp('flex', flex);
    addChild(child);
  }
}

class Flexible extends FWidget {
  @override
  String get widgetType => 'Flexible';

  Flexible({int flex = 1, required FWidget child}) {
    setProp('flex', flex);
    addChild(child);
  }
}
