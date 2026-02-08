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
    Key? key,
    this.refId,
    this.painterCommands,
    this.foregroundPainterCommands,
    this.size = Size.zero,
    this.isComplex = false,
    this.willChange = false,
    this.child,
  }) : super(key: key);

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
          // TODO: Implement drawPath
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant FuickCustomPainter oldDelegate) {
    return true; // Always repaint when commands change
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

  Paint _parsePaint(dynamic data) {
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
    return paint;
  }
}
