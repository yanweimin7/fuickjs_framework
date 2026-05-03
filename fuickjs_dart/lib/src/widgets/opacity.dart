import 'fwidget.dart';

class Opacity extends FWidget {
  @override
  String get widgetType => 'Opacity';

  Opacity({required double opacity, required FWidget child}) {
    setProp('opacity', opacity);
    addChild(child);
  }
}
