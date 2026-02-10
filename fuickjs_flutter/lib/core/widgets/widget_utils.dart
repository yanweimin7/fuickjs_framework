import 'package:flutter/material.dart';
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

    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      final color = Color(int.parse(buffer.toString(), radix: 16));
      _colorCache[hexString] = color;
      return color;
    } catch (e) {
      debugPrint('[WidgetUtils] Error parsing color: $hexString');
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

      if (horizontal != null || vertical != null) {
        return EdgeInsets.symmetric(
          horizontal: horizontal ?? 0.0,
          vertical: vertical ?? 0.0,
        );
      }
      if (left != null || top != null || right != null || bottom != null) {
        return EdgeInsets.fromLTRB(
          left ?? 0.0,
          top ?? 0.0,
          right ?? 0.0,
          bottom ?? 0.0,
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
      default:
        return MainAxisAlignment.center;
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
      default:
        return CrossAxisAlignment.center;
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

  static Axis axis(String? v) {
    switch (v) {
      case 'horizontal':
        return Axis.horizontal;
      case 'vertical':
      default:
        return Axis.vertical;
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

  static BoxDecoration? boxDecorationFromProps(Map<String, dynamic> props) {
    final decorationProp = props['decoration'];
    final Map<String, dynamic>? dec =
        decorationProp is Map ? asMap(decorationProp) : null;

    final colorStr = (dec != null ? dec['color'] : props['color']) as String?;
    final borderRadiusProp =
        dec != null ? dec['borderRadius'] : props['borderRadius'];
    final borderProp = dec != null ? dec['border'] : props['border'];
    final boxShadowProp = dec != null ? dec['boxShadow'] : props['boxShadow'];

    final color = colorFromHex(colorStr);
    final borderRadius = getBorderRadius(borderRadiusProp);
    final border = getBorder(borderProp);
    final boxShadow = getBoxShadow(boxShadowProp);

    if (color == null &&
        borderRadius == null &&
        border == null &&
        boxShadow == null) {
      return null;
    }

    return BoxDecoration(
      color: color,
      borderRadius: borderRadius,
      border: border,
      boxShadow: boxShadow,
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

  static Border? getBorder(dynamic v) {
    if (v is Map) {
      final m = asMap(v);
      final color = colorFromHex(m['color'] as String?) ?? Colors.black;
      final width = sizeNum(m['width']) ?? 1.0;
      return Border.all(color: color, width: width);
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
          childAspectRatio: asDoubleOrNull(m['childAspectRatio']) ?? 1.0,
        );
      } else if (type == 'maxCrossAxisExtent' ||
          m['maxCrossAxisExtent'] != null) {
        return SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: asDoubleOrNull(m['maxCrossAxisExtent']) ?? 200.0,
          mainAxisSpacing: asDouble(m['mainAxisSpacing']),
          crossAxisSpacing: asDouble(m['crossAxisSpacing']),
          childAspectRatio: asDoubleOrNull(m['childAspectRatio']) ?? 1.0,
        );
      }
    }
    return const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2);
  }

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
