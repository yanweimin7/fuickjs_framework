import 'dart:ui';

import 'package:flutter/material.dart';

import '../widget_factory.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class BackdropFilterParser extends WidgetParser {
  @override
  String get type => 'BackdropFilter';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final sigmaX = asDoubleOrNull(props['sigmaX']) ?? 0.0;
    final sigmaY = asDoubleOrNull(props['sigmaY']) ?? 0.0;
    final blendMode = _parseBlendMode(props['blendMode'] as String?);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
      blendMode: blendMode,
      child: factory.buildFirstChild(context, children, type),
    );
  }

  BlendMode _parseBlendMode(String? v) {
    switch (v) {
      case 'src':
        return BlendMode.src;
      case 'srcOver':
        return BlendMode.srcOver;
      case 'srcIn':
        return BlendMode.srcIn;
      case 'srcATop':
        return BlendMode.srcATop;
      case 'dstOver':
        return BlendMode.dstOver;
      case 'dstIn':
        return BlendMode.dstIn;
      case 'dstATop':
        return BlendMode.dstATop;
      case 'xor':
        return BlendMode.xor;
      case 'multiply':
        return BlendMode.multiply;
      case 'screen':
        return BlendMode.screen;
      case 'overlay':
        return BlendMode.overlay;
      default:
        return BlendMode.srcOver;
    }
  }
}
