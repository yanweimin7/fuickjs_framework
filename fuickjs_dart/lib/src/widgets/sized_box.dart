import 'fwidget.dart';

class SizedBox extends FWidget {
  @override
  String get widgetType => 'SizedBox';

  SizedBox({double? width, double? height, FWidget? child}) {
    setProp('width', width);
    setProp('height', height);
    addChild(child);
  }

  SizedBox.shrink() : this(width: 0, height: 0);
}
