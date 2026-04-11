import 'dart:ui';
import 'package:flutter/material.dart';
import '../../utils/extensions.dart';
import '../widget_factory.dart';
import 'widget_parser.dart';

/// filter: blur(Npx) → ImageFiltered
class ImageFilteredParser extends WidgetParser {
  @override
  String get type => 'ImageFiltered';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final sigmaX = asDoubleOrNull(props['sigmaX']) ?? 0.0;
    final sigmaY = asDoubleOrNull(props['sigmaY']) ?? 0.0;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
      child: factory.buildFirstChild(context, children, type),
    );
  }
}
