import 'fwidget.dart';
import 'types.dart';

class Row extends FWidget {
  @override
  String get widgetType => 'Row';

  Row({
    String? mainAxisAlignment,
    String? crossAxisAlignment,
    String? mainAxisSize,
    double? spacing,
    EdgeInsets? padding,
    EdgeInsets? margin,
    List<FWidget>? children,
  }) {
    setProp('mainAxisAlignment', mainAxisAlignment);
    setProp('crossAxisAlignment', crossAxisAlignment);
    setProp('mainAxisSize', mainAxisSize);
    setProp('spacing', spacing);
    setProp('padding', padding?.toJson());
    setProp('margin', margin?.toJson());
    addChildren(children);
  }
}
