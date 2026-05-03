import 'fwidget.dart';
import 'types.dart';

class Stack extends FWidget {
  @override
  String get widgetType => 'Stack';

  Stack({
    String? alignment,
    String? fit,
    EdgeInsets? padding,
    EdgeInsets? margin,
    List<FWidget>? children,
  }) {
    setProp('alignment', alignment);
    setProp('fit', fit);
    setProp('padding', padding?.toJson());
    setProp('margin', margin?.toJson());
    addChildren(children);
  }
}

class Positioned extends FWidget {
  @override
  String get widgetType => 'Positioned';

  Positioned({
    double? top,
    double? left,
    double? right,
    double? bottom,
    double? width,
    double? height,
    required FWidget child,
  }) {
    setProp('top', top);
    setProp('left', left);
    setProp('right', right);
    setProp('bottom', bottom);
    setProp('width', width);
    setProp('height', height);
    addChild(child);
  }
}
