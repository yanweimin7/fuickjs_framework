import 'fwidget.dart';

class Divider extends FWidget {
  @override
  String get widgetType => 'Divider';

  Divider({
    double? height,
    double? thickness,
    String? color,
    double? indent,
    double? endIndent,
  }) {
    setProp('height', height);
    setProp('thickness', thickness);
    setProp('color', color);
    setProp('indent', indent);
    setProp('endIndent', endIndent);
  }
}
