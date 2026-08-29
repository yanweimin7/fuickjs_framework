import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'safe_center_slice_image.dart';

/// native 端本地文件图片分支：`file://`/绝对路径 → `File`/`FileImage`/`Image.file`。
/// 文件不存在时返回 null，由 ImageParser 走 errorSrc / 占位降级。
Widget? buildLocalFileImage({
  required String filePath,
  required double? width,
  required double? height,
  required BoxFit? fit,
  required ColorFilter? colorFilter,
  required bool gaplessPlayback,
  required Color? tintColor,
  required Rect? centerSlice,
  required Widget Function() errorWidget,
  required void Function(BuildContext context, Object error, StackTrace? stackTrace)
      fireError,
}) {
  final file = File(filePath);
  if (!file.existsSync()) return null;

  if (filePath.endsWith('.svg')) {
    return SvgPicture.file(
      file,
      width: width,
      height: height,
      fit: fit ?? BoxFit.contain,
      colorFilter: colorFilter,
    );
  }

  Widget fileErrorBuilder(
      BuildContext ctx, Object error, StackTrace? stack) {
    fireError(ctx, error, stack);
    return errorWidget();
  }

  if (centerSlice != null) {
    return SafeCenterSliceImage(
      imageProvider: FileImage(file),
      width: width,
      height: height,
      fit: fit ?? BoxFit.fill,
      color: tintColor,
      colorBlendMode: tintColor != null ? BlendMode.srcIn : null,
      centerSlice: centerSlice,
      gaplessPlayback: gaplessPlayback,
      errorBuilder: fileErrorBuilder,
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
    errorBuilder: fileErrorBuilder,
  );
}
