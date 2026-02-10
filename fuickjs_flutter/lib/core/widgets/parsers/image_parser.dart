import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class ImageParser extends WidgetParser {
  @override
  String get type => 'Image';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final String url = (props['url'] ?? '') as String;
    final dynamic widthProp = props['width'];
    final dynamic heightProp = props['height'];
    final String? fitStr = props['fit'] as String?;
    final dynamic borderRadiusProp = props['borderRadius'];

    final width = WidgetUtils.sizeNum(widthProp);
    final height = WidgetUtils.sizeNum(heightProp);
    final fit = WidgetUtils.boxFit(fitStr);
    final borderRadius = WidgetUtils.getBorderRadius(borderRadiusProp);

    Widget image;
    if (url.startsWith('http')) {
      image = CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: Colors.grey[100],
        ),
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: const Icon(Icons.error_outline),
        ),
      );
    } else if (url.startsWith('data:image')) {
      final base64Str = url.split(',').last;
      image = Image.memory(
        base64Decode(base64Str),
        width: width,
        height: height,
        fit: fit,
      );
    } else {
      image = Image.asset(
        url,
        width: width,
        height: height,
        fit: fit,
      );
    }

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius, child: image);
    }
    return WidgetUtils.wrapPadding(props, image);
  }
}
