import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../container/fuick_action.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class ImageParser extends WidgetParser {
  @override
  String get type => 'Image';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    // src 和 url 都支持，src 优先（更语义化）
    final String src =
        ((props['src'] ?? props['url'] ?? '') as Object).toString();

    final width = WidgetUtils.sizeNum(props['width']);
    final height = WidgetUtils.sizeNum(props['height']);
    final fit = WidgetUtils.boxFit(props['fit'] as String?);
    final borderRadius = WidgetUtils.getBorderRadius(props['borderRadius']);
    final bool gaplessPlayback = props['gaplessPlayback'] == true;

    // tintColor 和 color 都支持，tintColor 优先
    final tintColorStr =
        (props['tintColor'] ?? props['color']) as String?;
    final tintColor =
        tintColorStr != null ? WidgetUtils.colorFromHex(tintColorStr) : null;

    // 占位背景色（加载中）
    final placeholderColorStr = props['placeholderColor'] as String?;
    final placeholderColor = placeholderColorStr != null
        ? WidgetUtils.colorFromHex(placeholderColorStr)
        : Colors.grey[100];

    // 加载失败备用图
    final String? errorSrc =
        (props['errorSrc'] ?? props['errorUrl']) as String?;

    final onLoad = props['onLoad'];
    final onError = props['onError'];

    Widget image = _buildImage(
      context: context,
      src: src,
      width: width,
      height: height,
      fit: fit,
      tintColor: tintColor,
      gaplessPlayback: gaplessPlayback,
      placeholderColor: placeholderColor,
      errorSrc: errorSrc,
      onLoad: onLoad,
      onError: onError,
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius, child: image);
    }

    return WidgetUtils.wrapPadding(props, image);
  }

  Widget _buildImage({
    required BuildContext context,
    required String src,
    double? width,
    double? height,
    BoxFit? fit,
    Color? tintColor,
    required bool gaplessPlayback,
    Color? placeholderColor,
    String? errorSrc,
    dynamic onLoad,
    dynamic onError,
  }) {
    final ColorFilter? colorFilter =
        tintColor != null ? ColorFilter.mode(tintColor, BlendMode.srcIn) : null;

    // ── 网络图片 ──
    if (src.startsWith('http://') || src.startsWith('https://')) {
      if (_isSvgUrl(src)) {
        return SvgPicture.network(
          src,
          width: width,
          height: height,
          fit: fit ?? BoxFit.contain,
          colorFilter: colorFilter,
        );
      }
      return CachedNetworkImage(
        imageUrl: src,
        width: width,
        height: height,
        fit: fit,
        color: tintColor,
        useOldImageOnUrlChange: gaplessPlayback,
        imageBuilder: onLoad != null
            ? (ctx, imageProvider) {
                FuickAction.event(ctx, onLoad);
                return Image(
                  image: imageProvider,
                  fit: fit,
                  color: tintColor,
                  colorBlendMode:
                      tintColor != null ? BlendMode.srcIn : null,
                );
              }
            : null,
        placeholder: (ctx, url) => _placeholder(width, height, placeholderColor),
        errorWidget: (ctx, url, error) {
          if (onError != null) FuickAction.event(ctx, onError);
          if (errorSrc != null && errorSrc.isNotEmpty) {
            return _buildImage(
              context: ctx,
              src: errorSrc,
              width: width,
              height: height,
              fit: fit,
              tintColor: tintColor,
              gaplessPlayback: false,
              placeholderColor: placeholderColor,
            );
          }
          return _errorWidget(width, height);
        },
      );
    }

    // ── base64 SVG ──
    if (src.startsWith('data:image/svg')) {
      final base64Str = src.split(',').last;
      final svgString = utf8.decode(base64Decode(base64Str));
      return SvgPicture.string(
        svgString,
        width: width,
        height: height,
        fit: fit ?? BoxFit.contain,
        colorFilter: colorFilter,
      );
    }

    // ── base64 栅格图 ──
    if (src.startsWith('data:image')) {
      final base64Str = src.split(',').last;
      return Image.memory(
        base64Decode(base64Str),
        width: width,
        height: height,
        gaplessPlayback: gaplessPlayback,
        fit: fit,
        color: tintColor,
        colorBlendMode: tintColor != null ? BlendMode.srcIn : null,
      );
    }

    // ── 本地文件：file:// 协议 或绝对路径 ──
    if (src.startsWith('file://') || _isAbsolutePath(src)) {
      final filePath =
          src.startsWith('file://') ? src.replaceFirst('file://', '') : src;
      final file = File(filePath);
      if (file.existsSync()) {
        if (filePath.endsWith('.svg')) {
          return SvgPicture.file(
            file,
            width: width,
            height: height,
            fit: fit ?? BoxFit.contain,
            colorFilter: colorFilter,
          );
        }
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: gaplessPlayback,
          color: tintColor,
          colorBlendMode: tintColor != null ? BlendMode.srcIn : null,
          errorBuilder: (ctx, error, stack) {
            if (onError != null) FuickAction.event(ctx, onError);
            return _errorWidget(width, height);
          },
        );
      }
      // 文件不存在，降级到 errorSrc 或占位
      if (errorSrc != null && errorSrc.isNotEmpty) {
        return _buildImage(
          context: context,
          src: errorSrc,
          width: width,
          height: height,
          fit: fit,
          tintColor: tintColor,
          gaplessPlayback: false,
          placeholderColor: placeholderColor,
        );
      }
      return _errorWidget(width, height);
    }

    // ── Asset SVG ──
    if (src.endsWith('.svg')) {
      return SvgPicture.asset(
        src,
        width: width,
        height: height,
        fit: fit ?? BoxFit.contain,
        colorFilter: colorFilter,
      );
    }

    // ── Asset 栅格图（默认 fallback）──
    return Image.asset(
      src,
      width: width,
      height: height,
      gaplessPlayback: gaplessPlayback,
      fit: fit,
      color: tintColor,
      colorBlendMode: tintColor != null ? BlendMode.srcIn : null,
      errorBuilder: (ctx, error, stack) {
        if (onError != null) FuickAction.event(ctx, onError);
        if (errorSrc != null && errorSrc.isNotEmpty) {
          return _buildImage(
            context: ctx,
            src: errorSrc,
            width: width,
            height: height,
            fit: fit,
            tintColor: tintColor,
            gaplessPlayback: false,
            placeholderColor: placeholderColor,
          );
        }
        return _errorWidget(width, height);
      },
    );
  }

  bool _isSvgUrl(String url) {
    final path = url.split('?').first.toLowerCase();
    return path.endsWith('.svg');
  }

  /// 判断是否为设备绝对路径（/开头，非 asset 路径格式）
  bool _isAbsolutePath(String src) {
    if (!src.startsWith('/')) return false;
    // asset 路径通常是相对路径如 "assets/img.png"，不以 / 开头
    // 以 / 开头且包含多级路径段，认为是文件系统绝对路径
    return src.contains('/') && !src.startsWith('//');
  }

  Widget _placeholder(double? width, double? height, Color? color) {
    return Container(
      width: width,
      height: height,
      color: color ?? Colors.grey[100],
    );
  }

  Widget _errorWidget(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
    );
  }
}
