/// EdgeInsets — mirrors Flutter / FuickJS EdgeInsets format.
class EdgeInsets {
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;
  final double? all;
  final double? vertical;
  final double? horizontal;

  const EdgeInsets({
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.all,
    this.vertical,
    this.horizontal,
  });

  const EdgeInsets.all(double value)
      : all = value,
        left = null,
        top = null,
        right = null,
        bottom = null,
        vertical = null,
        horizontal = null;

  const EdgeInsets.symmetric({double? vertical, double? horizontal})
      : vertical = vertical,
        horizontal = horizontal,
        left = null,
        top = null,
        right = null,
        bottom = null,
        all = null;

  const EdgeInsets.only({
    this.left,
    this.top,
    this.right,
    this.bottom,
  })  : all = null,
        vertical = null,
        horizontal = null;

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (all != null) m['all'] = all;
    if (vertical != null) m['vertical'] = vertical;
    if (horizontal != null) m['horizontal'] = horizontal;
    if (left != null) m['left'] = left;
    if (top != null) m['top'] = top;
    if (right != null) m['right'] = right;
    if (bottom != null) m['bottom'] = bottom;
    return m;
  }
}

/// Border definition.
class Border {
  final String? color;
  final double? width;

  const Border({this.color, this.width});

  Map<String, dynamic> toJson() => {
        if (color != null) 'color': color,
        if (width != null) 'width': width,
      };
}

/// BoxShadow definition.
class BoxShadow {
  final String? color;
  final double? blurRadius;
  final double? spreadRadius;
  final double? dx;
  final double? dy;

  const BoxShadow({
    this.color,
    this.blurRadius,
    this.spreadRadius,
    this.dx,
    this.dy,
  });

  Map<String, dynamic> toJson() => {
        if (color != null) 'color': color,
        if (blurRadius != null) 'blurRadius': blurRadius,
        if (spreadRadius != null) 'spreadRadius': spreadRadius,
        if (dx != null || dy != null)
          'offset': {
            if (dx != null) 'dx': dx,
            if (dy != null) 'dy': dy,
          },
      };
}

/// BorderRadius — uniform or per-corner.
class BorderRadius {
  final double? all;
  final double? topLeft;
  final double? topRight;
  final double? bottomLeft;
  final double? bottomRight;

  const BorderRadius.all(double radius)
      : all = radius,
        topLeft = null,
        topRight = null,
        bottomLeft = null,
        bottomRight = null;

  const BorderRadius.only({
    this.topLeft,
    this.topRight,
    this.bottomLeft,
    this.bottomRight,
  }) : all = null;

  dynamic toJson() {
    if (all != null) return all;
    return {
      if (topLeft != null) 'topLeft': topLeft,
      if (topRight != null) 'topRight': topRight,
      if (bottomLeft != null) 'bottomLeft': bottomLeft,
      if (bottomRight != null) 'bottomRight': bottomRight,
    };
  }
}

/// BoxDecoration.
class BoxDecoration {
  final String? color;
  final BorderRadius? borderRadius;
  final Border? border;
  final BoxShadow? boxShadow;
  final String? gradient; // raw string, e.g. "linear-gradient(...)"

  const BoxDecoration({
    this.color,
    this.borderRadius,
    this.border,
    this.boxShadow,
    this.gradient,
  });

  Map<String, dynamic> toJson() => {
        if (color != null) 'color': color,
        if (borderRadius != null) 'borderRadius': borderRadius!.toJson(),
        if (border != null) 'border': border!.toJson(),
        if (boxShadow != null) 'boxShadow': boxShadow!.toJson(),
        if (gradient != null) 'gradient': gradient,
      };
}

/// BoxConstraints.
class BoxConstraints {
  final double? minWidth;
  final double? maxWidth;
  final double? minHeight;
  final double? maxHeight;

  const BoxConstraints({
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
  });

  Map<String, dynamic> toJson() => {
        if (minWidth != null) 'minWidth': minWidth,
        if (maxWidth != null) 'maxWidth': maxWidth,
        if (minHeight != null) 'minHeight': minHeight,
        if (maxHeight != null) 'maxHeight': maxHeight,
      };
}
