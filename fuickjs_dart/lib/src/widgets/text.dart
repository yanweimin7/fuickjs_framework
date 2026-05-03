import 'fwidget.dart';
import 'types.dart';

class Text extends FWidget {
  @override
  String get widgetType => 'Text';

  Text(
    String data, {
    double? fontSize,
    String? color,
    String? fontWeight,
    String? textAlign,
    int? maxLines,
    String? overflow,
    EdgeInsets? padding,
    EdgeInsets? margin,
  }) {
    setProp('text', data);
    setProp('fontSize', fontSize);
    setProp('color', color);
    setProp('fontWeight', fontWeight);
    setProp('textAlign', textAlign);
    setProp('maxLines', maxLines);
    setProp('overflow', overflow);
    setProp('padding', padding?.toJson());
    setProp('margin', margin?.toJson());
  }
}
