import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
    final bool? gaplessPlayback = props['gaplessPlayback'] as bool?;

    Widget image;
    if (url.startsWith('http')) {
      if (url.contains('.svg') || url.startsWith('data:image/svg')) {
        image = SvgPicture.network(
          url,
          width: width,
          height: height,
          fit: fit ?? BoxFit.contain,
        );
      } else {
        image = CachedNetworkImage(
          imageUrl: url,
          width: width,
          height: height,
          fit: fit,
          useOldImageOnUrlChange: gaplessPlayback ?? false,
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
      }
    } else if (url.startsWith('data:image/svg')) {
      final base64Str = url.split(',').last;
      final svgString = utf8.decode(base64Decode(base64Str));
      image = SvgPicture.string(
        svgString,
        width: width,
        height: height,
        fit: fit ?? BoxFit.contain,
      );
    } else if (url.startsWith('data:image')) {
      final base64Str = url.split(',').last;
      image = Image.memory(
        base64Decode(base64Str),
        width: width,
        height: height,
        gaplessPlayback: gaplessPlayback ?? true,
        fit: fit,
      );
    } else if (url.endsWith('.svg')) {
      image = SvgPicture.asset(
        url,
        width: width,
        height: height,
        fit: fit ?? BoxFit.contain,
      );
    } else {
      image = Image.asset(
        url,
        width: width,
        height: height,
        gaplessPlayback: gaplessPlayback ?? false,
        fit: fit,
      );
    }

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius, child: image);
    }
    return WidgetUtils.wrapPadding(props, image);
  }
}
