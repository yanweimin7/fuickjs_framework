import 'package:flutter/material.dart';
import '../../utils/extensions.dart';
import '../fuick_animation.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class TransformParser extends WidgetParser {
  @override
  String get type => 'Transform';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final child = factory.buildFirstChild(context, children, type);
    final alignment = WidgetUtils.alignment(props['alignment'] as String?);
    final originMap = props['origin'];
    final origin = originMap is Map
        ? Offset(asDouble(originMap['dx']), asDouble(originMap['dy']))
        : null;

    final dynamic rotateProp = props['rotate'];
    if (FuickAnim.isRef(rotateProp)) {
      // 旋转动画引用：`anim.transform.rotate()`
      final animated = FuickAnim.wrapIfRef(
        context,
        rotateProp,
        builder: (context, animation) => Transform.rotate(
          angle: animation.value,
          alignment: alignment,
          origin: origin,
          child: child,
        ),
      );
      if (animated != null) return animated;
    } else if (props.containsKey('rotate')) {
      return Transform.rotate(
        angle: asDouble(props['rotate']),
        alignment: alignment,
        origin: origin,
        child: child,
      );
    }

    final dynamic scaleProp = props['scale'];
    if (FuickAnim.isRef(scaleProp)) {
      // 缩放动画引用：`anim.transform.scale() / scaleX() / scaleY()`
      final prop = FuickAnim.propOf(scaleProp as Map);
      final animated = FuickAnim.wrapIfRef(
        context,
        scaleProp,
        builder: (context, animation) {
          final double v = animation.value;
          return Transform.scale(
            scaleX: prop == 'scaleY' ? 1.0 : v,
            scaleY: prop == 'scaleX' ? 1.0 : v,
            alignment: alignment,
            origin: origin,
            child: child,
          );
        },
      );
      if (animated != null) return animated;
    } else if (props.containsKey('scale')) {
      final scale = props['scale'];
      double scaleX = 1.0;
      double scaleY = 1.0;
      if (scale is num) {
        scaleX = scaleY = asDouble(scale);
      } else if (scale is Map) {
        scaleX = asDouble(scale['x'] ?? 1.0);
        scaleY = asDouble(scale['y'] ?? 1.0);
      }
      return Transform.scale(
        scaleX: scaleX,
        scaleY: scaleY,
        alignment: alignment,
        origin: origin,
        child: child,
      );
    }

    final dynamic translateProp = props['translate'];
    if (FuickAnim.isRef(translateProp)) {
      // 平移动画引用：`anim.transform.translateX() / translateY()`
      final prop = FuickAnim.propOf(translateProp as Map);
      final animated = FuickAnim.wrapIfRef(
        context,
        translateProp,
        builder: (context, animation) {
          final double v = animation.value;
          return Transform.translate(
            offset: Offset(prop == 'translateY' ? 0 : v, prop == 'translateX' ? 0 : v),
            child: child,
          );
        },
      );
      if (animated != null) return animated;
    } else if (props.containsKey('translate')) {
      final translate = props['translate'];
      double x = 0.0;
      double y = 0.0;
      if (translate is Map) {
        x = asDouble(translate['x']);
        y = asDouble(translate['y']);
      }
      return Transform.translate(
        offset: Offset(x, y),
        child: child,
      );
    }

    // CSS transform 字符串，例如 "translate(10px, 20px) rotate(45deg) scale(1.5)"
    if (props.containsKey('_transform') && props['_transform'] is String) {
      final matrix = WidgetUtils.parseTransformString(props['_transform'] as String);
      if (matrix != null) {
        return Transform(
          transform: matrix,
          origin: origin,
          alignment: alignment ?? Alignment.center,
          child: child,
        );
      }
    }

    Matrix4 transform = Matrix4.identity();
    if (props['transform'] is List) {
      final list =
          (props['transform'] as List).map((e) => asDouble(e)).toList();
      if (list.length == 16) {
        transform = Matrix4.fromList(list);
      }
    }

    return Transform(
      transform: transform,
      origin: origin,
      alignment: alignment,
      child: child,
    );
  }
}
