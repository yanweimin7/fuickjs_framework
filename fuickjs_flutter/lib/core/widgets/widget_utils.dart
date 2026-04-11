import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../logger.dart';
import '../utils/extensions.dart';

class WidgetUtils {
  static final Map<String, Color> _colorCache = {};

  static Color? colorFromHex(String? hexString) {
    if (hexString == null || hexString.isEmpty) return null;
    final cached = _colorCache[hexString];
    if (cached != null) return cached;

    if (hexString == 'white') return Colors.white;
    if (hexString == 'black') return Colors.black;
    if (hexString == 'transparent') return Colors.transparent;
    if (hexString == 'grey') return Colors.grey;
    if (hexString == 'red') return Colors.red;
    if (hexString == 'blue') return Colors.blue;
    if (hexString == 'green') return Colors.green;
    if (hexString == 'yellow') return Colors.yellow;
    if (hexString == 'orange') return Colors.orange;

    // rgba(r, g, b, a) 格式
    final rgbaMatch = RegExp(
            r'rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)')
        .firstMatch(hexString);
    if (rgbaMatch != null) {
      final r = int.parse(rgbaMatch.group(1)!);
      final g = int.parse(rgbaMatch.group(2)!);
      final b = int.parse(rgbaMatch.group(3)!);
      final a = rgbaMatch.group(4) != null
          ? (double.parse(rgbaMatch.group(4)!) * 255).round()
          : 255;
      final color = Color.fromARGB(a, r, g, b);
      _colorCache[hexString] = color;
      return color;
    }

    try {
      final buffer = StringBuffer();
      String hex = hexString.replaceFirst('#', '');
      if (hex.length == 3) {
        hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
      }
      if (hex.length == 6) buffer.write('ff');
      buffer.write(hex);
      final color = Color(int.parse(buffer.toString(), radix: 16));
      _colorCache[hexString] = color;
      return color;
    } catch (e) {
      logger.w('[WidgetUtils] Error parsing color: $hexString');
      return null;
    }
  }

  static double? asDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static double asDouble(dynamic v, [double defaultValue = 0.0]) {
    return asDoubleOrNull(v) ?? defaultValue;
  }

  static double? sizeNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      if (v.endsWith('%')) return null; // Percentage not supported here
      return double.tryParse(v);
    }
    return null;
  }

  static EdgeInsets? edgeInsets(dynamic v) {
    if (v == null) return null;
    if (v is num) return EdgeInsets.all(v.toDouble());
    if (v is List) {
      if (v.isEmpty) return EdgeInsets.zero;
      if (v.length == 1) return EdgeInsets.all(asDouble(v[0]));
      if (v.length == 2) {
        return EdgeInsets.symmetric(
          vertical: asDouble(v[0]),
          horizontal: asDouble(v[1]),
        );
      }
      if (v.length == 4) {
        return EdgeInsets.fromLTRB(
          asDouble(v[0]),
          asDouble(v[1]),
          asDouble(v[2]),
          asDouble(v[3]),
        );
      }
    }
    if (v is Map) {
      if (v.isEmpty) return EdgeInsets.zero;
      final m = asMap(v);
      if (m.containsKey('all')) {
        return EdgeInsets.all(asDouble(m['all']));
      }
      final left = asDoubleOrNull(m['left']);
      final top = asDoubleOrNull(m['top']);
      final right = asDoubleOrNull(m['right']);
      final bottom = asDoubleOrNull(m['bottom']);
      final horizontal = asDoubleOrNull(m['horizontal']);
      final vertical = asDoubleOrNull(m['vertical']);

      // 当 horizontal/vertical 与 top/bottom/left/right 混合时（3-value shorthand），
      // 展开 horizontal/vertical 为具体方向后用 fromLTRB
      if (left != null ||
          top != null ||
          right != null ||
          bottom != null ||
          horizontal != null ||
          vertical != null) {
        return EdgeInsets.fromLTRB(
          left ?? horizontal ?? 0.0,
          top ?? vertical ?? 0.0,
          right ?? horizontal ?? 0.0,
          bottom ?? vertical ?? 0.0,
        );
      }
    }
    return null;
  }

  static Widget wrapPadding(Map<String, dynamic> props, Widget child) {
    final p = props['padding'];
    if (p == null) return child;
    final ei = edgeInsets(p);
    if (ei != null && ei != EdgeInsets.zero) {
      return Padding(padding: ei, child: child);
    }
    return child;
  }

  static Widget wrapMarginAndPadding(Map<String, dynamic> props, Widget child) {
    final margin = edgeInsets(props['margin']);
    final padding = edgeInsets(props['padding']);
    Widget c = child;
    if (padding != null && padding != EdgeInsets.zero) {
      c = Padding(padding: padding, child: c);
    }
    if (margin != null && margin != EdgeInsets.zero) {
      c = Padding(padding: margin, child: c);
    }
    return c;
  }

  static MainAxisAlignment mainAxis(String? v) {
    switch (v) {
      case 'start':
        return MainAxisAlignment.start;
      case 'end':
        return MainAxisAlignment.end;
      case 'spaceBetween':
        return MainAxisAlignment.spaceBetween;
      case 'spaceAround':
        return MainAxisAlignment.spaceAround;
      case 'spaceEvenly':
        return MainAxisAlignment.spaceEvenly;
      case 'center':
        return MainAxisAlignment.center;
      default:
        return MainAxisAlignment.start;
    }
  }

  static CrossAxisAlignment crossAxis(String? v) {
    switch (v) {
      case 'start':
        return CrossAxisAlignment.start;
      case 'end':
        return CrossAxisAlignment.end;
      case 'stretch':
        return CrossAxisAlignment.stretch;
      case 'center':
        return CrossAxisAlignment.center;
      case 'baseline':
        return CrossAxisAlignment.baseline;
      default:
        return CrossAxisAlignment.start;
    }
  }

  static MainAxisSize mainAxisSize(String? v) {
    switch (v) {
      case 'min':
        return MainAxisSize.min;
      case 'max':
      default:
        return MainAxisSize.max;
    }
  }

  static Alignment? alignment(String? v) {
    switch (v) {
      case 'center':
        return Alignment.center;
      case 'topLeft':
        return Alignment.topLeft;
      case 'topRight':
        return Alignment.topRight;
      case 'bottomLeft':
        return Alignment.bottomLeft;
      case 'bottomRight':
        return Alignment.bottomRight;
      case 'topCenter':
        return Alignment.topCenter;
      case 'bottomCenter':
        return Alignment.bottomCenter;
      case 'centerLeft':
        return Alignment.centerLeft;
      case 'centerRight':
        return Alignment.centerRight;
      default:
        return null;
    }
  }

  static Axis axis(String? v, {Axis defaultAxis = Axis.vertical}) {
    switch (v) {
      case 'horizontal':
      case 'row':
        return Axis.horizontal;
      case 'vertical':
      case 'column':
        return Axis.vertical;
      default:
        return defaultAxis;
    }
  }

  static BoxFit? boxFit(String? v) {
    switch (v) {
      case 'cover':
        return BoxFit.cover;
      case 'contain':
        return BoxFit.contain;
      case 'fill':
        return BoxFit.fill;
      case 'fitWidth':
        return BoxFit.fitWidth;
      case 'fitHeight':
        return BoxFit.fitHeight;
      case 'none':
        return BoxFit.none;
      case 'scaleDown':
        return BoxFit.scaleDown;
      default:
        return null;
    }
  }

  static BoxConstraints? boxConstraints(dynamic v) {
    if (v is Map) {
      final m = asMap(v);
      return BoxConstraints(
        minWidth: sizeNum(m['minWidth']) ?? 0.0,
        maxWidth: sizeNum(m['maxWidth']) ?? double.infinity,
        minHeight: sizeNum(m['minHeight']) ?? 0.0,
        maxHeight: sizeNum(m['maxHeight']) ?? double.infinity,
      );
    }
    return null;
  }

  static Clip? clipBehavior(String? v) {
    switch (v) {
      case 'none':
        return Clip.none;
      case 'hardEdge':
        return Clip.hardEdge;
      case 'antiAlias':
        return Clip.antiAlias;
      case 'antiAliasWithSaveLayer':
        return Clip.antiAliasWithSaveLayer;
      default:
        return null;
    }
  }

  static Alignment stackAlignment(String? v) {
    return alignment(v) ?? Alignment.center;
  }

  static ScrollPhysics? physics(String? v) {
    switch (v) {
      case 'never':
        return const NeverScrollableScrollPhysics();
      case 'bouncing':
        return const BouncingScrollPhysics();
      case 'clamping':
        return const ClampingScrollPhysics();
      case 'always':
        return const AlwaysScrollableScrollPhysics();
      default:
        return null;
    }
  }

  static Curve parseCurve(String? name) {
    switch (name) {
      case 'ease':
        return Curves.ease;
      case 'easeIn':
        return Curves.easeIn;
      case 'easeOut':
        return Curves.easeOut;
      case 'easeInOut':
        return Curves.easeInOut;
      case 'linear':
        return Curves.linear;
      case 'decelerate':
        return Curves.decelerate;
      case 'fastOutSlowIn':
        return Curves.fastOutSlowIn;
      case 'bounceIn':
        return Curves.bounceIn;
      case 'bounceOut':
        return Curves.bounceOut;
      case 'bounceInOut':
        return Curves.bounceInOut;
      case 'elasticIn':
        return Curves.elasticIn;
      case 'elasticOut':
        return Curves.elasticOut;
      case 'elasticInOut':
        return Curves.elasticInOut;
      default:
        return Curves.linear;
    }
  }

  static Gradient? getGradient(dynamic v) {
    if (v is! Map) return null;
    final m = asMap(v);
    final String? type = m['type']?.toString();
    final colorsList = m['colors'];
    if (colorsList is! List || colorsList.isEmpty) return null;
    final colors = colorsList
        .map((c) => colorFromHex(c.toString()))
        .whereType<Color>()
        .toList();
    if (colors.isEmpty) return null;

    List<double>? stops;
    if (m['stops'] is List) {
      stops = (m['stops'] as List)
          .map((s) => asDoubleOrNull(s))
          .whereType<double>()
          .toList();
      if (stops.length != colors.length) stops = null;
    }

    if (type == 'radial') {
      return RadialGradient(colors: colors, stops: stops);
    }

    // linear (default)
    final begin = alignment(m['begin']?.toString()) ?? Alignment.topCenter;
    final end = alignment(m['end']?.toString()) ?? Alignment.bottomCenter;
    return LinearGradient(
      colors: colors,
      stops: stops,
      begin: begin,
      end: end,
    );
  }

  static BoxDecoration? boxDecorationFromProps(Map<String, dynamic> props) {
    final decorationProp = props['decoration'];
    final Map<String, dynamic>? dec =
        decorationProp is Map ? asMap(decorationProp) : null;

    final colorStr = (dec != null ? dec['color'] : props['color']) as String?;
    final borderRadiusProp =
        dec != null ? dec['borderRadius'] : props['borderRadius'];
    final borderProp = dec != null ? dec['border'] : props['border'];
    final boxShadowProp = dec != null ? dec['boxShadow'] : props['boxShadow'];
    final gradientProp = dec != null ? dec['gradient'] : props['gradient'];
    final imageProp = dec != null ? dec['image'] : null;

    final color = colorFromHex(colorStr);
    final borderRadius = getBorderRadius(borderRadiusProp);
    final border = getBorder(borderProp);
    final boxShadow = getBoxShadow(boxShadowProp);
    final gradient = getGradient(gradientProp);
    final image = getDecorationImage(imageProp);

    if (color == null &&
        borderRadius == null &&
        border == null &&
        boxShadow == null &&
        gradient == null &&
        image == null) {
      return null;
    }

    return BoxDecoration(
      // gradient 优先于纯色，二者互斥
      color: gradient != null ? null : color,
      gradient: gradient,
      borderRadius: borderRadius,
      border: border,
      boxShadow: boxShadow,
      image: image,
    );
  }

  static List<BoxShadow>? getBoxShadow(dynamic v) {
    if (v == null) return null;
    if (v is Map) {
      final m = asMap(v);
      final color = colorFromHex(m['color'] as String?) ?? Colors.black26;
      final blurRadius = sizeNum(m['blurRadius']) ?? 0.0;
      final spreadRadius = sizeNum(m['spreadRadius']) ?? 0.0;
      final offsetMap = m['offset'] as Map?;
      final offset = Offset(
        sizeNum(offsetMap?['dx']) ?? 0.0,
        sizeNum(offsetMap?['dy']) ?? 0.0,
      );
      return [
        BoxShadow(
          color: color,
          blurRadius: blurRadius,
          spreadRadius: spreadRadius,
          offset: offset,
        )
      ];
    } else if (v is List) {
      if (v.isEmpty) return null;
      return v
          .map((e) => getBoxShadow(e))
          .whereType<List<BoxShadow>>()
          .expand((e) => e)
          .toList();
    }
    return null;
  }

  static DecorationImage? getDecorationImage(dynamic v) {
    if (v == null) return null;
    if (v is! Map) return null;
    final m = asMap(v);
    final url = m['url'] as String?;
    if (url == null || url.isEmpty) return null;

    final fitStr = m['fit'] as String?;
    final BoxFit fit;
    switch (fitStr) {
      case 'cover':
        fit = BoxFit.cover;
        break;
      case 'contain':
        fit = BoxFit.contain;
        break;
      case 'fill':
        fit = BoxFit.fill;
        break;
      case 'none':
        fit = BoxFit.none;
        break;
      case 'scaleDown':
        fit = BoxFit.scaleDown;
        break;
      default:
        fit = BoxFit.cover;
    }

    final alignment =
        WidgetUtils.alignment(m['alignment'] as String?) ?? Alignment.center;

    final repeatStr = m['repeat'] as String?;
    final ImageRepeat repeat;
    switch (repeatStr) {
      case 'repeat':
        repeat = ImageRepeat.repeat;
        break;
      case 'repeatX':
        repeat = ImageRepeat.repeatX;
        break;
      case 'repeatY':
        repeat = ImageRepeat.repeatY;
        break;
      default:
        repeat = ImageRepeat.noRepeat;
    }

    final ImageProvider provider = url.startsWith('http')
        ? NetworkImage(url)
        : AssetImage(url) as ImageProvider;

    return DecorationImage(
      image: provider,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
    );
  }

  static BorderStyle _borderStyle(String? v) {
    switch (v) {
      case 'dashed':
      case 'dotted':
      case 'solid':
        return BorderStyle
            .solid; // Flutter only supports solid; dashed/dotted need CustomPainter
      case 'none':
        return BorderStyle.none;
      default:
        return BorderStyle.solid;
    }
  }

  static BorderSide _borderSide(Map<String, dynamic> m,
      {BorderSide fallback = BorderSide.none}) {
    final color = colorFromHex(m['color'] as String?);
    final width = sizeNum(m['width']);
    final style = _borderStyle(m['style'] as String?);
    if (color == null && width == null) return fallback;
    return BorderSide(
      color: color ?? Colors.black,
      width: width ?? 1.0,
      style: style,
    );
  }

  static Border? getBorder(dynamic v) {
    if (v is Map) {
      final m = asMap(v);
      // 如果有单边 key，走单边模式
      final hasDirectional = m.containsKey('top') ||
          m.containsKey('right') ||
          m.containsKey('bottom') ||
          m.containsKey('left');
      if (hasDirectional) {
        final globalColor = colorFromHex(m['color'] as String?);
        final globalWidth = sizeNum(m['width']);
        final globalStyle = _borderStyle(m['style'] as String?);
        final fallback = (globalColor != null || globalWidth != null)
            ? BorderSide(
                color: globalColor ?? Colors.black,
                width: globalWidth ?? 1.0,
                style: globalStyle,
              )
            : BorderSide.none;
        return Border(
          top: m.containsKey('top')
              ? _borderSide(asMap(m['top']), fallback: fallback)
              : fallback,
          right: m.containsKey('right')
              ? _borderSide(asMap(m['right']), fallback: fallback)
              : fallback,
          bottom: m.containsKey('bottom')
              ? _borderSide(asMap(m['bottom']), fallback: fallback)
              : fallback,
          left: m.containsKey('left')
              ? _borderSide(asMap(m['left']), fallback: fallback)
              : fallback,
        );
      }
      final color = colorFromHex(m['color'] as String?) ?? Colors.black;
      final width = sizeNum(m['width']) ?? 1.0;
      final style = _borderStyle(m['style'] as String?);
      return Border.all(color: color, width: width, style: style);
    }
    return null;
  }

  static BorderRadius? getBorderRadius(dynamic br) {
    if (br == null) return null;
    if (br is num) {
      return BorderRadius.circular(br.toDouble());
    } else if (br is Map) {
      final m = asMap(br);
      return BorderRadius.only(
        topLeft: Radius.circular(sizeNum(m['topLeft']) ?? 0),
        topRight: Radius.circular(sizeNum(m['topRight']) ?? 0),
        bottomLeft: Radius.circular(sizeNum(m['bottomLeft']) ?? 0),
        bottomRight: Radius.circular(sizeNum(m['bottomRight']) ?? 0),
      );
    }
    return null;
  }

  static List<Shadow>? getTextShadow(dynamic v) {
    if (v == null) return null;
    if (v is Map) {
      final m = asMap(v);
      final color = colorFromHex(m['color'] as String?) ?? Colors.black54;
      final blurRadius = sizeNum(m['blurRadius']) ?? 0.0;
      final offsetMap = m['offset'] as Map?;
      final offset = Offset(
        sizeNum(offsetMap?['dx']) ?? 0.0,
        sizeNum(offsetMap?['dy']) ?? 0.0,
      );
      return [Shadow(color: color, blurRadius: blurRadius, offset: offset)];
    }
    if (v is List) {
      return v
          .map((e) => getTextShadow(e))
          .whereType<List<Shadow>>()
          .expand((e) => e)
          .toList();
    }
    return null;
  }

  static TextDecoration? textDecoration(String? v) {
    if (v == null) return null;
    // 支持组合值：'underline lineThrough' 等空格分隔
    final parts = v.trim().split(' ');
    final decorations = <TextDecoration>[];
    for (final part in parts) {
      switch (part) {
        case 'underline':
          decorations.add(TextDecoration.underline);
          break;
        case 'lineThrough':
          decorations.add(TextDecoration.lineThrough);
          break;
        case 'overline':
          decorations.add(TextDecoration.overline);
          break;
        case 'none':
          return TextDecoration.none;
      }
    }
    if (decorations.isEmpty) return null;
    if (decorations.length == 1) return decorations.first;
    return TextDecoration.combine(decorations);
  }

  static FontWeight fontWeight(String? v) {
    switch (v) {
      case 'w100':
        return FontWeight.w100;
      case 'w200':
        return FontWeight.w200;
      case 'w300':
        return FontWeight.w300;
      case 'normal':
        return FontWeight.normal;
      case 'w500':
        return FontWeight.w500;
      case 'w600':
        return FontWeight.w600;
      case 'bold':
        return FontWeight.bold;
      case 'w800':
        return FontWeight.w800;
      case 'w900':
        return FontWeight.w900;
      default:
        return FontWeight.normal;
    }
  }

  static ScrollPhysics? scrollPhysics(String? v) {
    return physics(v);
  }

  static Curve curve(String? v) {
    return parseCurve(v);
  }

  static SliverGridDelegate gridDelegate(dynamic v) {
    if (v is Map) {
      final m = asMap(v);
      final String? type = m['type']?.toString();
      if (type == 'fixedCrossAxisCount' || m['crossAxisCount'] != null) {
        return SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: asIntOrNull(m['crossAxisCount']) ?? 2,
          mainAxisSpacing: asDouble(m['mainAxisSpacing']),
          crossAxisSpacing: asDouble(m['crossAxisSpacing']),
          mainAxisExtent: asDoubleOrNull(m['mainAxisExtent']),
          childAspectRatio: asDoubleOrNull(m['childAspectRatio']) ?? 1.0,
        );
      } else if (type == 'maxCrossAxisExtent' ||
          m['maxCrossAxisExtent'] != null) {
        return SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: asDoubleOrNull(m['maxCrossAxisExtent']) ?? 200.0,
          mainAxisSpacing: asDouble(m['mainAxisSpacing']),
          crossAxisSpacing: asDouble(m['crossAxisSpacing']),
          mainAxisExtent: asDoubleOrNull(m['mainAxisExtent']),
          childAspectRatio: asDoubleOrNull(m['childAspectRatio']) ?? 1.0,
        );
      }
    }
    return const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2);
  }

  /// 解析 CSS transform 字符串为 Matrix4
  /// 支持: translate(x,y) translateX(x) translateY(y) rotate(angle) scale(x,y) skew(x,y)
  static Matrix4? parseTransformString(String? v) {
    if (v == null || v.isEmpty || v == 'none') return null;
    final matrix = Matrix4.identity();
    final regex = RegExp(r'(\w+)\(([^)]+)\)');
    for (final match in regex.allMatches(v)) {
      final fn = match.group(1)!;
      final args = match.group(2)!.split(',').map((s) {
        s = s.trim();
        if (s.endsWith('px') || s.endsWith('rpx')) {
          final n = double.tryParse(s.replaceAll(RegExp(r'[a-z]+$'), '')) ?? 0;
          return s.endsWith('rpx') ? n / 2 : n;
        }
        if (s.endsWith('deg')) {
          return (double.tryParse(s.replaceAll('deg', '')) ?? 0) *
              3.14159265358979 /
              180;
        }
        if (s.endsWith('rad')) {
          return double.tryParse(s.replaceAll('rad', '')) ?? 0;
        }
        if (s.endsWith('turn')) {
          return (double.tryParse(s.replaceAll('turn', '')) ?? 0) *
              2 *
              3.14159265358979;
        }
        return double.tryParse(s) ?? 0;
      }).toList();

      switch (fn) {
        case 'translate':
          matrix.translate(Vector3(args.isNotEmpty ? args[0] : 0.0,
              args.length > 1 ? args[1] : 0.0, 0.0));
          break;
        case 'translateX':
          matrix.translate(Vector3(args.isNotEmpty ? args[0] : 0.0, 0.0, 0.0));
          break;
        case 'translateY':
          matrix.translate(Vector3(0.0, args.isNotEmpty ? args[0] : 0.0, 0.0));
          break;
        case 'translate3d':
          matrix.translate(Vector3(
            args.isNotEmpty ? args[0] : 0.0,
            args.length > 1 ? args[1] : 0.0,
            args.length > 2 ? args[2] : 0.0,
          ));
          break;
        case 'rotate':
        case 'rotateZ':
          if (args.isNotEmpty) matrix.rotateZ(args[0]);
          break;
        case 'rotateX':
          if (args.isNotEmpty) matrix.rotateX(args[0]);
          break;
        case 'rotateY':
          if (args.isNotEmpty) matrix.rotateY(args[0]);
          break;
        case 'scale':
          final sx = args.isNotEmpty ? args[0] : 1.0;
          final sy = args.length > 1 ? args[1] : sx;
          matrix.multiply(Matrix4.diagonal3Values(sx, sy, 1.0));
          break;
        case 'scaleX':
          final sx1 = args.isNotEmpty ? args[0] : 1.0;
          matrix.multiply(Matrix4.diagonal3Values(sx1, 1.0, 1.0));
          break;
        case 'scaleY':
          final sy1 = args.isNotEmpty ? args[0] : 1.0;
          matrix.multiply(Matrix4.diagonal3Values(1.0, sy1, 1.0));
          break;
        case 'skew':
          // skew 通过矩阵实现
          final ax = args.isNotEmpty ? args[0] : 0.0;
          final ay = args.length > 1 ? args[1] : 0.0;
          final skewMatrix = Matrix4.identity();
          skewMatrix.setEntry(0, 1, _tan(ax));
          skewMatrix.setEntry(1, 0, _tan(ay));
          matrix.multiply(skewMatrix);
          break;
        case 'skewX':
          final skewXMatrix = Matrix4.identity();
          skewXMatrix.setEntry(0, 1, _tan(args.isNotEmpty ? args[0] : 0.0));
          matrix.multiply(skewXMatrix);
          break;
        case 'skewY':
          final skewYMatrix = Matrix4.identity();
          skewYMatrix.setEntry(1, 0, _tan(args.isNotEmpty ? args[0] : 0.0));
          matrix.multiply(skewYMatrix);
          break;
      }
    }
    return matrix == Matrix4.identity() ? null : matrix;
  }

  static double _tan(double radians) => math.tan(radians);

  static IconData iconData(String? name) {
    switch (name) {
      case 'notifications':
        return Icons.notifications;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      case 'swap_horiz':
        return Icons.swap_horiz;
      case 'payments':
        return Icons.payments;
      case 'qr_code_scanner':
        return Icons.qr_code_scanner;
      case 'history':
        return Icons.history;
      case 'pie_chart':
        return Icons.pie_chart;
      case 'show_chart':
        return Icons.show_chart;
      case 'assessment':
        return Icons.assessment;
      case 'psychology':
        return Icons.psychology;
      case 'info':
        return Icons.info;
      case 'bar_chart':
        return Icons.bar_chart;
      case 'add':
        return Icons.add;
      case 'trending_up':
        return Icons.trending_up;
      case 'trending_down':
        return Icons.trending_down;
      case 'arrow_back':
        return Icons.arrow_back;
      case 'search':
        return Icons.search;
      case 'more_vert':
        return Icons.more_vert;
      case 'star':
        return Icons.star;
      case 'settings':
        return Icons.settings;
      case 'person':
        return Icons.person;
      case 'home':
        return Icons.home;
      case 'favorite':
        return Icons.favorite;
      case 'share':
        return Icons.share;
      case 'error_outline':
        return Icons.error_outline;
      default:
        return Icons.circle;
    }
  }
}
