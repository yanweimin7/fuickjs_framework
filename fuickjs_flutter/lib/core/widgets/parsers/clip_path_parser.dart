import 'package:flutter/material.dart';

import '../widget_factory.dart';
import 'widget_parser.dart';

/// CSS `clip-path` 支持。
/// 解析 `path` prop（CSS clip-path 值字符串），生成 Flutter `ClipPath`。
///
/// 支持形式：
///   - `circle(50%)`  / `circle(50% at center center)`
///   - `inset(10px)`  / `inset(10px 20px 10px 20px round 8px)`
///   - `ellipse(50% 40%)`
///   - `polygon(50% 0%, 100% 100%, 0% 100%)`
///   - 不支持 `url()` / `path()`
class ClipPathParser extends WidgetParser {
  @override
  String get type => 'ClipPath';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final pathStr = props['path'] as String?;
    final child = factory.buildFirstChild(context, children, type);

    if (pathStr == null || pathStr.isEmpty) return child;

    // circle(...)
    if (pathStr.startsWith('circle')) {
      return ClipOval(child: child);
    }

    // ellipse(...)
    if (pathStr.startsWith('ellipse')) {
      return ClipOval(child: child);
    }

    // inset(10px) / inset(10px 20px) / inset(10px 20px 10px 20px round 8px)
    final insetMatch = RegExp(r'inset\(([^)]+)\)').firstMatch(pathStr);
    if (insetMatch != null) {
      final inner = insetMatch.group(1)!;
      final roundMatch = RegExp(r'round\s+([\d.]+)').firstMatch(inner);
      final borderRadius = roundMatch != null ? double.tryParse(roundMatch.group(1)!) ?? 0.0 : 0.0;
      if (borderRadius > 0) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: child,
        );
      }
      return ClipRect(child: child);
    }

    // polygon(50% 0%, 100% 100%, 0% 100%) → ClipPath with custom clipper
    final polyMatch = RegExp(r'polygon\(([^)]+)\)').firstMatch(pathStr);
    if (polyMatch != null) {
      final pointsStr = polyMatch.group(1)!;
      final points = <Offset>[];
      for (final pair in pointsStr.split(',')) {
        final parts = pair.trim().split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          final x = _parsePercent(parts[0]);
          final y = _parsePercent(parts[1]);
          if (x != null && y != null) {
            points.add(Offset(x, y));
          }
        }
      }
      if (points.isNotEmpty) {
        return ClipPath(
          clipper: _PolygonClipper(points),
          child: child,
        );
      }
    }

    // Unsupported clip-path value — pass through without clipping
    return child;
  }

  static double? _parsePercent(String s) {
    s = s.trim();
    if (s.endsWith('%')) {
      return (double.tryParse(s.replaceAll('%', '')) ?? 0) / 100.0;
    }
    // px value — will be used as fraction of size in clipper
    if (s.endsWith('px')) {
      return double.tryParse(s.replaceAll('px', ''));
    }
    return double.tryParse(s);
  }
}

/// Custom clipper for CSS polygon()
class _PolygonClipper extends CustomClipper<Path> {
  final List<Offset> points;

  _PolygonClipper(this.points);

  @override
  Path getClip(Size size) {
    final path = Path();
    if (points.isEmpty) return path;
    // Points are in 0..1 (percentage) range
    path.moveTo(points[0].dx * size.width, points[0].dy * size.height);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx * size.width, points[i].dy * size.height);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _PolygonClipper oldClipper) {
    return oldClipper.points.length != points.length ||
        !_listsEqual(oldClipper.points, points);
  }

  static bool _listsEqual(List<Offset> a, List<Offset> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
