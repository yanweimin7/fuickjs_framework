import 'fwidget.dart';
import 'types.dart';

class Container extends FWidget {
  @override
  String get widgetType => 'Container';

  Container({
    double? width,
    double? height,
    String? color,
    EdgeInsets? padding,
    EdgeInsets? margin,
    BoxDecoration? decoration,
    BoxConstraints? constraints,
    String? alignment,
    void Function()? onTap,
    void Function()? onLongPress,
    FWidget? child,
    List<FWidget>? children,
  }) {
    setProp('width', width);
    setProp('height', height);
    setProp('color', color);
    setProp('padding', padding?.toJson());
    setProp('margin', margin?.toJson());
    setProp('decoration', decoration?.toJson());
    setProp('constraints', constraints?.toJson());
    setProp('alignment', alignment);
    if (onTap != null) setEvent('onTap', onTap);
    if (onLongPress != null) setEvent('onLongPress', onLongPress);
    addChild(child);
    addChildren(children);
  }
}
