import 'package:flutter/material.dart';

import '../../utils/extensions.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class CustomPaintParser extends WidgetParser {
  @override
  String get type => 'CustomPaint';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final refId = props['refId']?.toString();

    final painterCommands = props['painter'] as List?;
    final foregroundPainterCommands = props['foregroundPainter'] as List?;

    final sizeMap = props['size'];
    final size = sizeMap != null
        ? Size(asDouble(sizeMap['width']), asDouble(sizeMap['height']))
        : Size.zero;

    return FuickCustomPaint(
      refId: refId,
      painterCommands: painterCommands,
      foregroundPainterCommands: foregroundPainterCommands,
      size: size,
      isComplex: props['isComplex'] == true,
      willChange: props['willChange'] == true,
      child: factory.buildFirstChild(context, children, type),
    );
  }
}

class FuickCustomPaint extends StatelessWidget {
  final String? refId;
  final List? painterCommands;
  final List? foregroundPainterCommands;
  final Size size;
  final bool isComplex;
  final bool willChange;
  final Widget? child;

  const FuickCustomPaint({
    super.key,
    this.refId,
    this.painterCommands,
    this.foregroundPainterCommands,
    this.size = Size.zero,
    this.isComplex = false,
    this.willChange = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: (painterCommands != null && painterCommands!.isNotEmpty)
            ? FuickCustomPainter(painterCommands!)
            : null,
        foregroundPainter: (foregroundPainterCommands != null &&
                foregroundPainterCommands!.isNotEmpty)
            ? FuickCustomPainter(foregroundPainterCommands!)
            : null,
        size: size,
        isComplex: isComplex,
        willChange: willChange,
        child: child,
      ),
    );
  }
}

class FuickCustomPainter extends CustomPainter {
  final List commands;
  // 缓存 paint 配置 → Paint 实例。Map.identity 比较：DSL 反序列化每次产出
  // 新对象，identity 命中率有限，但同一帧内多次绘制（save/restore 嵌套）能复用。
  final Map<dynamic, Paint> _paintCache = {};

  FuickCustomPainter(this.commands);

  @override
  void paint(Canvas canvas, Size size) {
    for (final cmd in commands) {
      if (cmd is! Map) continue;
      final type = cmd['type'];
      switch (type) {
        case 'save':
          canvas.save();
          break;
        case 'restore':
          canvas.restore();
          break;
        case 'translate':
          canvas.translate(asDouble(cmd['dx']), asDouble(cmd['dy']));
          break;
        case 'scale':
          canvas.scale(asDouble(cmd['sx']), asDouble(cmd['sy']));
          break;
        case 'rotate':
          canvas.rotate(asDouble(cmd['radians']));
          break;
        case 'drawLine':
          final p1 = _parseOffset(cmd['p1']);
          final p2 = _parseOffset(cmd['p2']);
          final paint = _parsePaint(cmd['paint']);
          if (p1 != null && p2 != null) {
            canvas.drawLine(p1, p2, paint);
          }
          break;
        case 'drawRect':
          final rect = _parseRect(cmd['rect']);
          final paint = _parsePaint(cmd['paint']);
          if (rect != null) {
            canvas.drawRect(rect, paint);
          }
          break;
        case 'drawCircle':
          final center = _parseOffset(cmd['center']);
          final radius = asDouble(cmd['radius']);
          final paint = _parsePaint(cmd['paint']);
          if (center != null) {
            canvas.drawCircle(center, radius, paint);
          }
          break;
        case 'drawOval':
          final rect = _parseRect(cmd['rect']);
          final paint = _parsePaint(cmd['paint']);
          if (rect != null) {
            canvas.drawOval(rect, paint);
          }
          break;
        case 'drawArc':
          final rect = _parseRect(cmd['rect']);
          final startAngle = asDouble(cmd['startAngle']);
          final sweepAngle = asDouble(cmd['sweepAngle']);
          final useCenter = cmd['useCenter'] == true;
          final paint = _parsePaint(cmd['paint']);
          if (rect != null) {
            canvas.drawArc(rect, startAngle, sweepAngle, useCenter, paint);
          }
          break;
        case 'drawRRect':
          final rrect = _parseRRect(cmd['rrect']);
          final paint = _parsePaint(cmd['paint']);
          if (rrect != null) {
            canvas.drawRRect(rrect, paint);
          }
          break;
        case 'drawPath':
          final path = _parsePath(cmd['path']);
          final paint = _parsePaint(cmd['paint']);
          if (path != null) {
            canvas.drawPath(path, paint);
          }
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant FuickCustomPainter oldDelegate) {
    // commands List 由 DSL 反序列化产生：内容不变时 identity 不一定相同。
    // 用引用相等可避免无变化时的重绘；新 painter 实例是从 props 变化而来，
    // 这种情况下 oldDelegate.commands != commands，会触发重绘。
    return !identical(oldDelegate.commands, commands);
  }

  Offset? _parseOffset(dynamic data) {
    if (data is Map) {
      return Offset(asDouble(data['dx']), asDouble(data['dy']));
    }
    return null;
  }

  Rect? _parseRect(dynamic data) {
    if (data is Map) {
      if (data.containsKey('left')) {
        return Rect.fromLTWH(
          asDouble(data['left']),
          asDouble(data['top']),
          asDouble(data['width']),
          asDouble(data['height']),
        );
      }
    }
    return null;
  }

  RRect? _parseRRect(dynamic data) {
    if (data is Map) {
      return RRect.fromRectAndRadius(
        Rect.fromLTWH(
          asDouble(data['left']),
          asDouble(data['top']),
          asDouble(data['width']),
          asDouble(data['height']),
        ),
        Radius.circular(asDouble(data['radius'])),
      );
    }
    return null;
  }

  Path? _parsePath(dynamic data) {
    if (data is! Map) return null;
    final path = Path();
    final operations = data['operations'] as List?;
    if (operations == null) return null;

    for (final op in operations) {
      if (op is! Map) continue;
      final opType = op['type'];
      switch (opType) {
        case 'moveTo':
          path.moveTo(asDouble(op['x']), asDouble(op['y']));
          break;
        case 'lineTo':
          path.lineTo(asDouble(op['x']), asDouble(op['y']));
          break;
        case 'quadraticBezierTo':
          path.quadraticBezierTo(
            asDouble(op['x1']), asDouble(op['y1']),
            asDouble(op['x2']), asDouble(op['y2']),
          );
          break;
        case 'cubicTo':
          path.cubicTo(
            asDouble(op['x1']), asDouble(op['y1']),
            asDouble(op['x2']), asDouble(op['y2']),
            asDouble(op['x3']), asDouble(op['y3']),
          );
          break;
        case 'arcTo':
          final rect = _parseRect(op['rect']);
          final startAngle = asDouble(op['startAngle']);
          final sweepAngle = asDouble(op['sweepAngle']);
          final forceMoveTo = op['forceMoveTo'] == true;
          if (rect != null) {
            path.arcTo(rect, startAngle, sweepAngle, forceMoveTo);
          }
          break;
        case 'addRect':
          final rect = _parseRect(op['rect']);
          if (rect != null) {
            path.addRect(rect);
          }
          break;
        case 'addOval':
          final rect = _parseRect(op['rect']);
          if (rect != null) {
            path.addOval(rect);
          }
          break;
        case 'addRRect':
          final rrect = _parseRRect(op['rrect']);
          if (rrect != null) {
            path.addRRect(rrect);
          }
          break;
        case 'close':
          path.close();
          break;
      }
    }
    return path;
  }

  Paint _parsePaint(dynamic data) {
    if (data == null) return _paintCache[null] ??= Paint();
    final cached = _paintCache[data];
    if (cached != null) return cached;
    final paint = Paint();
    if (data is Map) {
      if (data['color'] != null) {
        final c = WidgetUtils.colorFromHex(data['color']);
        if (c != null) {
          paint.color = c;
        }
      }
      if (data['style'] == 'stroke') {
        paint.style = PaintingStyle.stroke;
      } else {
        paint.style = PaintingStyle.fill;
      }
      if (data['strokeWidth'] != null) {
        paint.strokeWidth = asDouble(data['strokeWidth']);
      }
      if (data['strokeCap'] == 'round') {
        paint.strokeCap = StrokeCap.round;
      } else if (data['strokeCap'] == 'square') {
        paint.strokeCap = StrokeCap.square;
      }
    }
    _paintCache[data] = paint;
    return paint;
  }
}
