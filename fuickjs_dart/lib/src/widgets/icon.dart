import 'fwidget.dart';

/// Icon widget — uses Material icon code points.
/// Common code points: search=0xe8b6, home=0xe88a, person=0xe7fd,
/// settings=0xe8b8, arrow_back=0xe5c4, close=0xe5cd, check=0xe876,
/// add=0xe145, star=0xe838, favorite=0xe87d, share=0xe80d
class Icon extends FWidget {
  @override
  String get widgetType => 'Icon';

  Icon({
    required int codePoint,
    double? size,
    String? color,
  }) {
    setProp('codePoint', codePoint);
    setProp('size', size);
    setProp('color', color);
  }
}
