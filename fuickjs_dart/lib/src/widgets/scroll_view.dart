import 'fwidget.dart';
import 'types.dart';

class SingleChildScrollView extends FWidget {
  @override
  String get widgetType => 'SingleChildScrollView';

  SingleChildScrollView({
    String? scrollDirection, // 'vertical' | 'horizontal'
    EdgeInsets? padding,
    String? physics, // 'bouncing' | 'clamping' | 'never'
    FWidget? child,
  }) {
    setProp('scrollDirection', scrollDirection);
    setProp('padding', padding?.toJson());
    setProp('physics', physics);
    addChild(child);
  }
}
