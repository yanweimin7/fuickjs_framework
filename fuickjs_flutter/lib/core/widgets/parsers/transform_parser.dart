import 'package:flutter/material.dart';
import '../../utils/extensions.dart';
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

    if (props.containsKey('rotate')) {
      return Transform.rotate(
        angle: asDouble(props['rotate']),
        alignment: alignment,
        origin: origin,
        child: child,
      );
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
