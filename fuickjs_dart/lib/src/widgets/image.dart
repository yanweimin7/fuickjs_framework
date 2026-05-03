import 'fwidget.dart';

class Image extends FWidget {
  @override
  String get widgetType => 'Image';

  Image({
    required String src,
    double? width,
    double? height,
    String? fit, // 'cover' | 'contain' | 'fill' | 'fitWidth' | 'fitHeight' | 'none'
    dynamic borderRadius,
    String? color, // tint color
  }) {
    setProp('src', src);
    setProp('width', width);
    setProp('height', height);
    setProp('fit', fit);
    setProp('borderRadius', borderRadius);
    setProp('color', color);
  }
}
