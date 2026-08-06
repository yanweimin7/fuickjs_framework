import 'package:flutter/material.dart';
import '../fuick_animation.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class SizedBoxParser extends WidgetParser {
  @override
  String get type => 'SizedBox';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final dynamic widthProp = props['width'];
    final dynamic heightProp = props['height'];
    final bool animWidth = FuickAnim.isRef(widthProp);
    final bool animHeight = FuickAnim.isRef(heightProp);

    // 尺寸动画引用：`<SizedBox width={anim.value} height={anim.value} />`。
    // 同一驱动 Widget 同时消费 width/height 动画值。
    if (animWidth || animHeight) {
      final ref = animWidth ? widthProp : heightProp;
      final animated = FuickAnim.wrapIfRef(
        context,
        ref,
        builder: (context, animation) => SizedBox(
          width: animWidth ? animation.value : WidgetUtils.sizeNum(widthProp),
          height: animHeight ? animation.value : WidgetUtils.sizeNum(heightProp),
          child: factory.buildFirstChild(context, children, type),
        ),
      );
      return animated!;
    }

    final width = WidgetUtils.sizeNum(widthProp);
    final height = WidgetUtils.sizeNum(heightProp);

    return SizedBox(
      width: width,
      height: height,
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
