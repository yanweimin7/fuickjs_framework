import 'package:flutter/material.dart';

import '../widget_factory.dart';
import 'widget_parser.dart';

/// CSS `mix-blend-mode` 实现。
/// Flutter 没有直接的 blend mode widget，用 `ColorFiltered` + `BlendMode` 近似模拟。
/// 注意：Flutter 的 ColorFilter.mode 需要一个颜色参数，但 CSS mix-blend-mode 是
/// 与背景的混合。这里用透明色 + 对应 BlendMode 实现部分效果。
///
/// Props:
///   blendMode : String — 混合模式名称（映射自 css-to-props.ts）
class ColorFilteredParser extends WidgetParser {
  @override
  String get type => 'ColorFiltered';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final blendModeStr = props['blendMode'] as String?;
    final blendMode = _parseBlendMode(blendModeStr);
    final child = factory.buildFirstChild(context, children, type);

    // srcOver (normal) → no need to wrap
    if (blendMode == BlendMode.srcOver) return child;

    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          colors: [Colors.white, Colors.white],
        ).createShader(bounds);
      },
      blendMode: blendMode,
      child: child,
    );
  }

  BlendMode _parseBlendMode(String? v) {
    switch (v) {
      case 'multiply': return BlendMode.multiply;
      case 'screen': return BlendMode.screen;
      case 'overlay': return BlendMode.overlay;
      case 'darken': return BlendMode.darken;
      case 'lighten': return BlendMode.lighten;
      case 'colorDodge': return BlendMode.colorDodge;
      case 'colorBurn': return BlendMode.colorBurn;
      case 'hardLight': return BlendMode.hardLight;
      case 'softLight': return BlendMode.softLight;
      case 'difference': return BlendMode.difference;
      case 'exclusion': return BlendMode.exclusion;
      case 'hue': return BlendMode.hue;
      case 'saturation': return BlendMode.saturation;
      case 'color': return BlendMode.color;
      case 'luminosity': return BlendMode.luminosity;
      case 'srcOver': return BlendMode.srcOver;
      default: return BlendMode.srcOver;
    }
  }
}
